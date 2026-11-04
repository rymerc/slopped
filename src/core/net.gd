extends Node
## Autoload "Net": peer management + server-authoritative player registry.
## The host (peer 1) owns all game state. Clients only send requests.

signal players_changed
signal world_requested(world: String, args: Dictionary)
signal status(msg: String)
signal announced(msg: String)
signal peer_left(id: int)

const PORT := 24680
const MAX_CLIENTS := 15
const BOT_BASE := 1_000_000
const START_COINS := 100
const BOT_NAMES := ["Gorp", "Mildred", "Chungus", "Beebo", "Sir Wobble", "Tater", "Dweeb", "Slorp"]

var players: Dictionary = {}  # peer id -> profile Dictionary
var world := "menu"
var world_args: Dictionary = {}
var _pending_profile: Dictionary = {}
var _bot_seq := 0


func _ready() -> void:
	InputSetup.ensure()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


# --- session ---------------------------------------------------------------

func host(profile: Dictionary, bots: int) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	players[1] = make_profile(profile, false)
	for i in bots:
		add_bot(false)
	broadcast()
	request_world("lobby", {})
	return OK


func join(ip: String, profile: Dictionary) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_pending_profile = profile
	status.emit("Connecting to %s ..." % ip)
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	world = "menu"
	world_requested.emit("menu", {})


func _on_connected() -> void:
	_register.rpc_id(1, _pending_profile)


func _on_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	status.emit("Connection failed. Is the host running and port %d open?" % PORT)


func _on_server_gone() -> void:
	leave()
	status.emit("Host left the game.")


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.erase(id):
		announce("%s left" % pname_from_cache(id))
		broadcast()
	peer_left.emit(id)


var _name_cache: Dictionary = {}

func pname_from_cache(id: int) -> String:
	return _name_cache.get(id, "Someone")


@rpc("any_peer", "reliable")
func _register(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = make_profile(profile, false)
	broadcast()
	announce("%s joined the slop" % players[id].name)
	_load_world.rpc_id(id, world, world_args)


# --- profiles --------------------------------------------------------------

func make_profile(raw: Dictionary, bot: bool) -> Dictionary:
	var n := str(raw.get("name", "Slopper")).strip_edges().left(16)
	if n.is_empty():
		n = "Slopper"
	var c: Variant = raw.get("color", Color.ORANGE)
	if typeof(c) != TYPE_COLOR:
		c = Color.ORANGE
	var hat := str(raw.get("hat", "none"))
	if not Art.HATS.has(hat):
		hat = "none"
	var body := str(raw.get("body", "bean"))
	if not Art.BODIES.has(body):
		body = "bean"
	return {
		"name": n, "color": c, "hat": hat, "body": body, "bot": bot,
		"coins": START_COINS, "score": 0, "perks": [], "giant_count": 0,
	}


func add_bot(sync := true) -> void:
	if not multiplayer.is_server():
		return
	_bot_seq += 1
	var id := BOT_BASE + _bot_seq
	players[id] = make_profile({
		"name": "%s (bot)" % BOT_NAMES[_bot_seq % BOT_NAMES.size()],
		"color": Color.from_hsv(randf(), 0.65, 0.95),
		"hat": Art.HATS.pick_random(),
		"body": Art.BODIES.pick_random(),
	}, true)
	if sync:
		broadcast()


func remove_bot() -> bool:
	if not multiplayer.is_server():
		return false
	for id: int in players.keys():
		if is_bot(id):
			players.erase(id)
			broadcast()
			return true
	return false


## Client -> server: change cosmetic fields. Validated server side.
@rpc("any_peer", "call_local", "reliable")
func request_look(changes: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := sender()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if changes.has("color") and typeof(changes.color) == TYPE_COLOR:
		p.color = changes.color
	if changes.has("hat") and Art.HATS.has(str(changes.hat)):
		p.hat = str(changes.hat)
	if changes.has("body") and Art.BODIES.has(str(changes.body)):
		p.body = str(changes.body)
	broadcast()


func broadcast() -> void:
	if multiplayer.is_server():
		_sync_players.rpc(players)


@rpc("authority", "call_local", "reliable")
func _sync_players(data: Dictionary) -> void:
	players = data
	for id: int in players:
		_name_cache[id] = players[id].name
	players_changed.emit()


# --- worlds ----------------------------------------------------------------

func request_world(w: String, args: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_load_world.rpc(w, args)


@rpc("authority", "call_local", "reliable")
func _load_world(w: String, args: Dictionary) -> void:
	world = w
	world_args = args
	world_requested.emit(w, args)


func announce(msg: String) -> void:
	if multiplayer.is_server():
		_announce.rpc(msg)


@rpc("authority", "call_local", "reliable")
func _announce(msg: String) -> void:
	announced.emit(msg)


# --- helpers ---------------------------------------------------------------

func me() -> int:
	return multiplayer.get_unique_id()


## Peer id of the caller of the current RPC (our own id when called directly).
func sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


func is_bot(id: int) -> bool:
	return id >= BOT_BASE


func profile(id: int) -> Dictionary:
	return players.get(id, {})


func pname(id: int) -> String:
	return str(profile(id).get("name", "???"))


func perks_of(id: int) -> Array:
	return profile(id).get("perks", [])


## Invoke `method` on `node` at `peer`. Works when `peer` is ourselves (host).
func call_peer(peer: int, node: Node, method: StringName, args: Array = []) -> void:
	if is_bot(peer):
		return
	if peer == multiplayer.get_unique_id():
		node.callv(method, args)
	else:
		node.callv("rpc_id", [peer, method] + args)


func to_server(node: Node, method: StringName, args: Array = []) -> void:
	call_peer(1, node, method, args)


## "leader" / "loser" / "mid" based on score. Drives lobby swagger.
func rank_of(id: int) -> String:
	if players.size() < 2 or not players.has(id):
		return "mid"
	var hi := -INF
	var lo := INF
	for k: int in players:
		var s := float(players[k].score)
		hi = maxf(hi, s)
		lo = minf(lo, s)
	if is_equal_approx(hi, lo):
		return "mid"
	var mine := float(players[id].score)
	if is_equal_approx(mine, hi):
		return "leader"
	if is_equal_approx(mine, lo):
		return "loser"
	return "mid"


func give_coins(id: int, n: int) -> void:
	if players.has(id):
		players[id].coins = maxi(0, int(players[id].coins) + n)


func give_perk(id: int, perk: String) -> void:
	if players.has(id):
		players[id].perks.append(perk)
