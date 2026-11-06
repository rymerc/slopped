class_name MiniGame
extends WorldBase
## Shared match frame: roster, clock, scoreboard sync, payout, return to lobby.
## Subclasses build their arena and implement the game_* hooks. The host runs the
## rules; clients render state from _ev_state and the subclass _ev_* events.
##
## args: {"boss": id, "players": [ids], "modifier": id, "seed": int}

const SYNC_DT := 0.1
const LOBBY_DELAY := 7.0

var boss_id := 0
var roster: Array = []
var modifier := "none"
var time_left := 300.0
var over := false
var active := false
var scores: Dictionary = {}  # id -> number shown on the scoreboard
var extra: Dictionary = {}   # per-game replicated state

var _sync_t := 0.0
var _timer: Label
var _board: Label
var _info: Label
var _cross: Label


func build_world() -> void:
	boss_id = int(args.get("boss", 1))
	roster = args.get("players", [])
	modifier = str(args.get("modifier", "none"))
	seed(int(args.get("seed", 0)))
	build_arena()
	randomize()
	_build_hud()
	if multiplayer.is_server():
		Net.peer_left.connect(_on_left)


func world_started() -> void:
	active = true
	game_begin()


# --- subclass hooks ----------------------------------------------------------

func build_arena() -> void:
	pass


func game_begin() -> void:
	pass


## Host only, every physics tick while the match runs.
func game_tick(_delta: float) -> void:
	pass


## Every peer, every frame.
func game_visuals(_delta: float) -> void:
	pass


func info_text() -> String:
	return ""


func board_lines() -> PackedStringArray:
	var ids: Array = roster.filter(func(i: int) -> bool: return Net.players.has(i))
	ids.sort_custom(func(a: int, b: int) -> bool: return float(scores.get(a, 0)) > float(scores.get(b, 0)))
	var out: PackedStringArray = []
	for id: int in ids:
		out.append("%s  %d" % [Net.pname(id), int(scores.get(id, 0))])
	return out


func mortals() -> Array:
	return roster.filter(func(i: int) -> bool: return i != boss_id and Net.players.has(i))


func on_time_up() -> void:
	pass


func on_player_left(_id: int) -> void:
	pass


# --- shared rules --------------------------------------------------------------

func base_config(av: Avatar) -> void:
	var perks := Net.perks_of(av.pid)
	av.speed_mult = PerkDB.speed_mult(perks) * (1.3 if modifier == "zoomies" else 1.0)
	av.jump_vel *= PerkDB.jump_mult(perks)
	av.gravity_mult = 0.45 if modifier == "low_gravity" else 1.0
	PerkDB.apply(av, perks)
	av.set_head_scale(2.0 if modifier == "big_heads" else 1.0)
	av.set_glow(perks.has("glow_stick"))
	av.slippery = modifier == "slippery"


func world_physics(delta: float) -> void:
	if not multiplayer.is_server() or not active or over:
		return
	time_left -= delta
	game_tick(delta)
	if over:
		return
	if time_left <= 0.0:
		on_time_up()
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = SYNC_DT
		_ev_state.rpc(time_left, scores, extra)


func world_process(delta: float) -> void:
	game_visuals(delta)
	if not multiplayer.is_server():
		time_left -= delta
	_timer.text = "%d:%02d" % [maxi(0, int(time_left)) / 60, maxi(0, int(time_left)) % 60]
	_board.text = "\n".join(board_lines())
	_info.text = info_text()


@rpc("authority", "call_local", "unreliable_ordered")
func _ev_state(t: float, s: Dictionary, e: Dictionary) -> void:
	time_left = t
	scores = s
	extra = e


## Host: ends the match. payouts: id -> [score, coins, xp]
func finish(msg: String, winners: Array, payouts: Dictionary, challenge := "") -> void:
	if over:
		return
	over = true
	_ev_state.rpc(0.0, scores, extra)
	_ev_over.rpc(msg, winners)
	var rows: Array = []
	for id: int in roster:
		if not Net.players.has(id):
			continue
		var p: Dictionary = Net.players[id]
		var pay: Array = payouts.get(id, [0, 15, 40])
		p.score = int(p.score) + int(pay[0])
		Net.reward(id, int(pay[1]))
		rows.append({"name": Net.pname(id), "a": "+%d" % int(pay[0]), "b": "+%dc" % int(pay[1]), "win": winners.has(id)})
		Net.award(id, int(pay[2]), "Won!" if winners.has(id) else "Good effort", challenge if winners.has(id) else "")
		p.perks = []
	Net.broadcast()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.win) > int(b.win))
	Net.publish_results(msg.get_slice("\n", 0), rows)
	await get_tree().create_timer(LOBBY_DELAY).timeout
	Net.request_world("lobby", {})


@rpc("authority", "call_local", "reliable")
func _ev_over(msg: String, winners: Array) -> void:
	over = true
	banner("%s\n%s" % [msg, "YOU WIN" if winners.has(Net.me()) else "you lose lol"], 7.0)
	Fx.confetti(self, cam.global_position + cam.aim_dir() * 8.0, 50)
	Sfx.ui(self, "ding", 0.0)


func _on_left(id: int) -> void:
	on_player_left(id)


# --- HUD ------------------------------------------------------------------------

func _build_hud() -> void:
	_timer = Ui.label("5:00", 40, Ui.YELLOW)
	_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer.offset_top = 8
	hud.add_child(_timer)
	_board = Ui.label("", 20)
	_board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_board.offset_left = 16
	_board.offset_top = 12
	hud.add_child(_board)
	_info = Ui.label("", 20)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_info.offset_top = -56
	_info.offset_bottom = -44
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(_info)
	_cross = Ui.label("+", 32)
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cross.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cross.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cross.visible = false
	hud.add_child(_cross)
