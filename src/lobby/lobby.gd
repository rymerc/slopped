class_name Lobby
extends WorldBase
## The Slop Lounge. Between-game hub: customise, gamble, drink, flex.
## Score rank changes your body here: leader = big, fast, crowned, can smite.
## Loser = tiny, slow, feeble.

const RANK_FX := {
	"leader": {"size": 1.35, "speed": 1.25, "jump": 1.2},
	"mid": {"size": 1.0, "speed": 1.0, "jump": 1.0},
	"loser": {"size": 0.62, "speed": 0.7, "jump": 0.75},
}
const DRINKS := ["giant", "tiny", "zoom", "floaty", "drunk", "burp"]
const SMITE_COOLDOWN := 6.0

var casino: Casino
var casino_ui: CasinoUI
var wheel: BigWheel
var _refs: Dictionary = {}
var _drink: Dictionary = {}  # id -> {kind, until}
var _hud_info: Label
var _smite_cd := 0.0
var _starting := false
var _bot_goals: Dictionary = {}


func build_world() -> void:
	make_environment(Color("#2b1d3a"), Color("#ff9ecf"), 0.7, 1.0)
	_refs = LobbyBuilder.build(self)
	wheel = BigWheel.new()
	wheel.position = Vector3(0, 0, -4)
	add_child(wheel)
	wheel.spin_finished.connect(_on_wheel_done)

	casino = Casino.new()
	casino.name = "Casino"
	add_child(casino)
	casino_ui = CasinoUI.new()
	casino_ui.casino = casino
	hud.add_child(casino_ui)
	casino_ui.closed.connect(close_ui)

	_hud_info = Ui.label("", 20)
	_hud_info.position = Vector2(16, 12)
	hud.add_child(_hud_info)
	var help := Ui.label("WASD move  SHIFT sprint  SPACE jump  E interact  G smite (leader)  ESC menu", 16)
	Ui.anchor(help, Control.PRESET_BOTTOM_LEFT, 12)
	hud.add_child(help)
	_wire_stations()


func world_started() -> void:
	banner("THE SLOP LOUNGE\nhit the big red button to spin", 4.0)


func _wire_stations() -> void:
	add_interact(LobbyBuilder.START_BTN, 3.0, "SPIN THE WHEEL (start game)", _press_start, _can_start)
	add_interact(LobbyBuilder.BAR, 4.0, "Order a Mystery Slop (free, probably fine)", _server_call.bind("req_drink", []))
	add_interact(LobbyBuilder.THRONE, 2.5, "Sit on the throne", banner.bind("You are the main character.", 2.0))
	add_interact(LobbyBuilder.PAINT, 2.5, "Dunk yourself in paint", _cycle.bind("color"))
	add_interact(LobbyBuilder.HATS, 2.5, "Grab a different hat", _cycle.bind("hat"))
	add_interact(LobbyBuilder.BODY, 2.5, "Swap your body", _cycle.bind("body"))
	add_interact(LobbyBuilder.SLOTS, 2.5, "Play SLOTS", _open_casino.bind("slots"))
	add_interact(LobbyBuilder.CRASH, 2.5, "Play CRASH", _open_casino.bind("crash"))
	add_interact(LobbyBuilder.MINIWHEEL, 2.5, "Spin LIL' WHEEL", _open_casino.bind("wheel"))
	add_interact(LobbyBuilder.DUCKS, 2.5, "Bet on DUCKS", _open_casino.bind("ducks"))
	add_interact(LobbyBuilder.SHOP, 3.5, "Browse the PERK SHOP", _open_casino.bind("shop"))
	add_interact(LobbyBuilder.KENNEL + Vector3(-1.2, 0, -1), 2.2, "Adopt a bot (host)", _server_call.bind("req_bot", [true]))
	add_interact(LobbyBuilder.KENNEL + Vector3(1.2, 0, -1), 2.2, "Release a bot (host)", _server_call.bind("req_bot", [false]))
	add_interact(LobbyBuilder.TOILET, 2.2, "Flush yourself", _server_call.bind("req_flush", []))


func _server_call(method: String, call_args: Array) -> void:
	Net.to_server(self, method, call_args)


func _press_start() -> void:
	Net.to_server(self, "req_start")


func _can_start() -> bool:
	return not wheel.spinning and not _starting


func _open_casino(kind: String) -> void:
	open_ui()
	casino_ui.open(kind)


func close_ui() -> void:
	casino_ui.visible = false
	super.close_ui()


func _cycle(field: String) -> void:
	var p := Net.profile(Net.me())
	var val: Variant
	match field:
		"color":
			var i := Art.SWATCHES.find(p.get("color"))
			val = Art.SWATCHES[(i + 1) % Art.SWATCHES.size()]
		"hat":
			val = Art.HATS[(Art.HATS.find(p.get("hat")) + 1) % Art.HATS.size()]
		"body":
			val = Art.BODIES[(Art.BODIES.find(p.get("body")) + 1) % Art.BODIES.size()]
	Net.to_server(Net, "request_look", [{field: val}])


# --- avatars -----------------------------------------------------------------

func spawn_for(_av: Avatar, index: int) -> Vector3:
	var a := index * 0.9
	return Vector3(cos(a) * 4.0, 0.5, 9.0 + sin(a) * 2.0)


func configure_avatar(av: Avatar) -> void:
	var fx: Dictionary = RANK_FX[Net.rank_of(av.pid)]
	var s := float(fx.size)
	av.speed_mult = float(fx.speed) * PerkDB.speed_mult(Net.perks_of(av.pid))
	av.jump_vel = 8.5 * float(fx.jump)
	av.gravity_mult = 1.0
	if _drink.has(av.pid):
		match str(_drink[av.pid].kind):
			"giant": s *= 1.8
			"tiny": s *= 0.45
			"zoom": av.speed_mult *= 1.8
			"floaty": av.gravity_mult = 0.25
	av.set_size(s)
	av.set_glow(Net.perks_of(av.pid).has("glow_stick"))


# --- server requests -----------------------------------------------------------

@rpc("any_peer", "reliable")
func req_start() -> void:
	if not multiplayer.is_server() or wheel.spinning or _starting:
		return
	if Net.players.size() < 2:
		Net.announce("Need 2+ players. Adopt a bot at the kennel!")
		return
	_starting = true
	_spin.rpc(randi() % PerkDB.MODIFIERS.size(), Net.pname(Net.sender()))


@rpc("authority", "call_local", "reliable")
func _spin(index: int, who: String) -> void:
	_starting = true
	banner("%s spun the wheel!" % who, 2.5)
	wheel.spin_to(index)


func _on_wheel_done(index: int) -> void:
	var mod: Dictionary = PerkDB.MODIFIERS[index]
	banner("%s\nstarting GIANT HUNT..." % mod.name, 3.5)
	if multiplayer.is_server():
		get_tree().create_timer(3.0).timeout.connect(_launch.bind(str(mod.id)))


func _launch(mod_id: String) -> void:
	# Giant = whoever has been giant the fewest times (ties random).
	var ids: Array = Net.players.keys()
	ids.shuffle()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(Net.players[a].giant_count) < int(Net.players[b].giant_count))
	var giant: int = ids[0]
	Net.players[giant].giant_count = int(Net.players[giant].giant_count) + 1
	Net.broadcast()
	var littles: Array = ids.slice(1)
	Net.request_world("giant", {"giant": giant, "littles": littles, "modifier": mod_id, "seed": randi()})


@rpc("any_peer", "reliable")
func req_drink() -> void:
	if not multiplayer.is_server():
		return
	_drink_fx.rpc(Net.sender(), DRINKS.pick_random())


@rpc("authority", "call_local", "reliable")
func _drink_fx(id: int, kind: String) -> void:
	var av: Avatar = avatars.get(id)
	if av == null:
		return
	_drink[id] = {"kind": kind, "until": Time.get_ticks_msec() + 20000}
	configure_avatar(av)
	var lines := {"giant": "is HUGE now", "tiny": "shrank", "zoom": "has the zoomies",
		"floaty": "is floating", "drunk": "is seeing double", "burp": "BURPED"}
	toast("%s %s" % [Net.pname(id), lines[kind]])
	if kind == "drunk" and av.is_local():
		cam.wobble = 20.0
	if kind == "burp" and multiplayer.is_server():
		for other: Avatar in avatars.values():
			var d := other.global_position - av.global_position
			if other != av and d.length() < 6.0:
				other.push.rpc(d.normalized() * 14.0 + Vector3.UP * 6.0)


@rpc("any_peer", "reliable")
func req_flush() -> void:
	if not multiplayer.is_server():
		return
	var av: Avatar = avatars.get(Net.sender())
	if av:
		var p := Vector3(randf_range(-25, 25), 6.0, randf_range(-25, 25))
		av.teleport.rpc(p)
		Net.announce("%s went down the drain" % Net.pname(av.pid))


@rpc("any_peer", "reliable")
func req_bot(add: bool) -> void:
	if not multiplayer.is_server() or Net.sender() != 1:
		return
	if add:
		Net.add_bot()
	else:
		Net.remove_bot()


@rpc("any_peer", "reliable")
func req_smite(pos: Vector3) -> void:
	if not multiplayer.is_server() or Net.rank_of(Net.sender()) != "leader":
		return
	_smite_fx.rpc(pos)
	for av: Avatar in avatars.values():
		var d := av.global_position - pos
		if d.length() < 4.5 and av.pid != Net.sender():
			av.push.rpc(Vector3(d.x, 0, d.z).normalized() * 12.0 + Vector3.UP * 12.0)


@rpc("authority", "call_local", "reliable")
func _smite_fx(pos: Vector3) -> void:
	var bolt := Node3D.new()
	add_child(bolt)
	bolt.position = pos
	Art.part(bolt, Art.cyl(0.25, 0.5, 30, 6), Color("#fff6a0"), Vector3(0, 15, 0), Vector3.ONE, Vector3.ZERO, false, 3.0)
	Art.part(bolt, Art.cyl(3.5, 3.5, 0.1, 16), Color("#fff6a0"), Vector3(0, 0.1, 0), Vector3.ONE, Vector3.ZERO, false, 2.0)
	get_tree().create_timer(0.35).timeout.connect(bolt.queue_free)
	if local_avatar() and local_avatar().global_position.distance_to(pos) < 25.0:
		cam.shake(0.8)


# --- per-frame -------------------------------------------------------------------

func world_input(event: InputEvent) -> void:
	if event.is_action_pressed("god") and Net.rank_of(Net.me()) == "leader" and _smite_cd <= 0.0:
		_smite_cd = SMITE_COOLDOWN
		var me := local_avatar()
		var skip: Array[RID] = []
		if me:
			skip.append(me.get_rid())
		Net.to_server(self, "req_smite", [cam.aim_point(skip, 60.0)])


func world_process(delta: float) -> void:
	_smite_cd -= delta
	var disco: Node3D = _refs.disco
	disco.rotate_y(delta * 0.6)
	var now := Time.get_ticks_msec()
	for id: int in _drink.keys():
		if now > int(_drink[id].until):
			_drink.erase(id)
			if avatars.has(id):
				configure_avatar(avatars[id])
	var me := Net.me()
	var rank := Net.rank_of(me)
	(_refs.vip_gate as CollisionShape3D).disabled = rank == "leader"
	var p := Net.profile(me)
	var line := "%s   coins: %d   score: %d   rank: %s" % [p.get("name", "?"), int(p.get("coins", 0)), int(p.get("score", 0)), rank.to_upper()]
	if rank == "leader":
		line += " (press G to smite peasants)"
	elif rank == "loser":
		line += " (feeble)"
	_hud_info.text = line + "\nperks next match: " + PerkDB.summary(p.get("perks", []))
	_update_fame()


func _update_fame() -> void:
	var ids: Array = Net.players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(Net.players[a].score) > int(Net.players[b].score))
	var lines: PackedStringArray = []
	for id: int in ids:
		lines.append("%-18s %3d pts  %4dc" % [Net.pname(id), int(Net.players[id].score), int(Net.players[id].coins)])
	(_refs.fame as Label3D).text = "\n".join(lines)


func world_physics(delta: float) -> void:
	for av: Avatar in avatars.values():
		if not av.controls():
			continue
		var t := av.global_position - LobbyBuilder.TRAMPOLINE
		if Vector2(t.x, t.z).length() < 2.0 and t.y < 1.0 and av.velocity.y <= 0.0:
			av.velocity.y = 19.0
	if multiplayer.is_server():
		_drive_bots(delta)


func _drive_bots(_delta: float) -> void:
	for av: Avatar in avatars.values():
		if not av.is_bot:
			continue
		var goal: Vector3 = _bot_goals.get(av.pid, av.global_position)
		var to := goal - av.global_position
		to.y = 0.0
		if to.length() < 1.5 or randf() < 0.002:
			_bot_goals[av.pid] = Vector3(randf_range(-26, 26), 0, randf_range(-20, 26))
			av.bot_move = Vector3.ZERO
		else:
			av.bot_move = to.normalized() * (0.4 if randf() < 0.5 else 0.6)
		av.bot_jump = randf() < 0.004
