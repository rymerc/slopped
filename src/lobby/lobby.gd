class_name Lobby
extends WorldBase
## Slopsville. Between-game hub: customise, gamble, drink, flex, fall off things.
## Score rank changes your body here: leader = big, fast, crowned, can smite.
## Loser = tiny, slow, feeble.

const RANK_FX := {
	"leader": {"size": 1.35, "speed": 1.25, "jump": 1.2},
	"mid": {"size": 1.0, "speed": 1.0, "jump": 1.0},
	"loser": {"size": 0.62, "speed": 0.7, "jump": 0.75},
}
const DRINKS := ["giant", "tiny", "zoom", "floaty", "drunk", "burp"]
const SMITE_COOLDOWN := 6.0
const FUSE_SECS := 2.2
const FLUSH_SECS := 1.5
## name, landing point, upward launch speed. Long shots land fast: you skid. That is the joke.
const CANNON_TARGETS := [["THE CARNIVAL (safe-ish)", Playground.LANDING, 21.0],
	["SLOP COVE", Vector3(-92, 0.5, 92), 28.0],
	["SLIDE HILL SUMMIT", Playground.SUMMIT, 34.0],
	["THE SALOON ROOF", Vector3(-21, 12.3, -33), 31.0],
	["THE RANDOM OCEAN", Vector3(190, -4, -60), 30.0]]
const FLUSH_OUTLETS := [[Vector3(-17, 2.2, 6), "the town fountain"], [Vector3(-40, 17, -2), "the water tower"],
	[Vector3(-31.6, 2.6, -34), "the saloon piano"], [Vector3(44, 3.5, -16), "a slot machine"],
	[Vector3(112, 3.0, -6), "the Chaos Yard port-a-potty"], [Vector3(-82, 1.5, 80), "the Bilge Bar taps"],
	[Vector3(3.5, 38, -100), "the giant duck"], [Playground.CAVE + Vector3(-7, 1.2, 0), "the Spooky Cave"]]
const FLUSH_LINES := ["10/10 would flush", "the pipes remember you", "again?", "a regular", "plumbing is a journey",
	"you have a problem", "they named a wrench after you", "please stop", "it knows your name"]
const GAMES := {"giant": "GIANT HUNT", "pocket": "POCKET GOD", "soup": "LAVA SOUP", "cursed": "CURSED CASINO NIGHT"}
static var _last_game := ""
const CANNON_VEL := Vector3(-5.8, 21.0, -24.0)
const CANNON_MOUTH := Vector3(0, 6.0, -3.8)

var casino: Casino
var casino_ui: CasinoUI
var tables: CasinoTables
var wheel: BigWheel
var _refs: Dictionary = {}
var _drink: Dictionary = {}  # id -> {kind, until}
var _hud_info: Label
var _smite_cd := 0.0
var _starting := false
var _bot_goals: Dictionary = {}
var _play: Dictionary = {}
var clock := 0.0  # shared hazard clock (host re-syncs it)
var _clock_t := 0.0
var _hz_cd: Dictionary = {}
var vault_open := 0.0
var _vault_vis := false
var _gauntlet_start := -1.0
var _slide_from_top := false
var _session_done: Dictionary = {}
var _door_a := 0.0
var _in_cannon := false
var _fuse_lit := false
var _cannon_aim := 0
var _cannon_label: Label
var _ride_lap_end := -1.0
var _flushing: Dictionary = {}
var _flush_count: Dictionary = {}
var _dive_top := 0.0
var floor_fx: CasinoFloorFx


## Golden hour: low sun from the south-west rakes long shadows down Main Street
## and across the casino front, the sky turns warm at the horizon, and shadows
## stay cool and readable. Low enough for neon to glow, bright enough to play.
static func apply_lighting(w: WorldBase) -> void:
	w.make_environment(Color("#4a86dc"), Color("#ffd9b5"), 0.6, 0.9, 150.0, 620.0,
		Vector3(-30, -52, 0), Color("#fff0dc"), Color("#d9b08e"))


func build_world() -> void:
	apply_lighting(self)
	var batch := Batch.new()
	_refs = LobbyBuilder.build(self, batch, props)
	_play = Playground.build(self, props, batch)
	water_y = Playground.KILL_Y
	allow_shove = true
	for i in 3:
		props.spawn("duck", Vector3(-12 - i * 0.8, 0.5, 9.0))
	for i in 3:
		props.spawn("ball", Vector3(-8 + i * 8.0, 1.0, 12))
	wheel = BigWheel.new()
	wheel.position = Vector3(0, 0.1, -4)
	add_child(wheel)
	Kit.landmark(self, batch, "wheel_stand", wheel.position)
	wheel.spin_finished.connect(_on_wheel_done)
	# Everything static merges into a few chunked meshes; the keep-list stays live
	# because Lobby animates it.
	var keep: Array = [wheel]
	for d: Dictionary in [_refs, _play]:
		for v: Variant in d.values():
			if v is Node:
				keep.append(v)
		for h: Dictionary in d.get("hazards", []):
			for k: Variant in h.values():
				if k is Node:
					keep.append(k)
		for pad: Dictionary in d.get("pads", []):
			keep.append(pad.node)
	keep.append_array(_play.get("plates", []))
	for v: Variant in (_refs.slots as Array) + (_refs.roulette as Array) + [_refs.ducks, _refs.saloon_doors]:
		keep.append_array((v as Dictionary).values())
	for v: Variant in (_play.ferris as Dictionary).values():
		keep.append(v)
	batch.absorb(self, keep)
	batch.commit(self)
	Playground.batch = null  # committed: nothing more may be added
	Ambience.build_island(self)

	floor_fx = CasinoFloorFx.new()
	floor_fx.refs = _refs
	add_child(floor_fx)
	casino = Casino.new()
	casino.name = "Casino"
	add_child(casino)
	casino_ui = CasinoUI.new()
	casino_ui.casino = casino
	hud.add_child(casino_ui)
	casino_ui.closed.connect(close_ui)
	tables = CasinoTables.new()
	tables.name = "Tables"
	tables.game = self
	tables.casino = casino
	tables.floor_fx = floor_fx
	add_child(tables)
	LobbyBuilder.populate(_refs.npcs)
	_cannon_label = Ui.label("", 26, Ui.YELLOW)
	_cannon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cannon_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_cannon_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cannon_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cannon_label.offset_bottom = -70
	_cannon_label.visible = false
	hud.add_child(_cannon_label)

	_hud_info = Ui.label("", 20)
	_hud_info.position = Vector2(16, 12)
	hud.add_child(_hud_info)
	var k := func(a: String) -> String: return InputSetup.label(a)
	var help := Ui.label("%s%s%s%s move   %s sprint   %s jump   %s dive/slide   %s grab/use   %s shove/throw   %s smite (leader)   %s dirty trick   %s menu" % [
		k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right"), k.call("sprint"), k.call("jump"),
		k.call("dive"), k.call("interact"), k.call("primary"), k.call("god"), k.call("trick"), k.call("menu")], 16)
	Ui.anchor(help, Control.PRESET_BOTTOM_LEFT, 12)
	hud.add_child(help)
	_wire_stations()


func world_started() -> void:
	banner("WELCOME TO SLOPSVILLE\nhit the big red button to spin", 4.0)
	if multiplayer.is_server():
		_roll_next_game()


## Picks the next minigame at random, never the same one twice running.
func _roll_next_game() -> void:
	var options: Array = GAMES.keys()
	options.erase(_last_game)
	Net.set_next_game.rpc(options.pick_random())


func _next_text() -> String:
	return "Next game: %s (host: change)" % GAMES.get(Net.next_game, "?")


func _cycle_game() -> void:
	_server_call("req_next_game", [])


@rpc("any_peer", "reliable")
func req_next_game() -> void:
	if not multiplayer.is_server() or Net.sender() != 1 or _starting:
		return
	var keys: Array = GAMES.keys()
	Net.set_next_game.rpc(keys[(keys.find(Net.next_game) + 1) % keys.size()])


func _wire_stations() -> void:
	add_interact(LobbyBuilder.START_BTN, 3.0, "SPIN THE WHEEL (start game)", _press_start, _can_start)
	add_interact(LobbyBuilder.BAR, 4.5, "Order a Mystery Slop (free, probably fine)", _server_call.bind("req_drink", []))
	add_interact(Playground.BAR2 + Vector3(0, 0, 0), 6.0, "Order a Mystery Slop (now with sand)", _server_call.bind("req_drink", []))
	add_interact(LobbyBuilder.THRONE, 2.8, "Sit on the throne", banner.bind("You are the main character.", 2.0))
	add_interact(LobbyBuilder.PAINT, 2.2, "Dunk yourself in paint", _cycle.bind("color"))
	add_interact(LobbyBuilder.HATS, 2.0, "Grab a different hat", _cycle.bind("hat"))
	add_interact(LobbyBuilder.BODY, 2.2, "Swap your body", _cycle.bind("body"))
	LobbyBuilder.wire_casino(self, tables.sit)
	add_interact(LobbyBuilder.DEEDS, 3.2, "Browse DIRTY DEEDS DEPT.", _open_casino.bind("deeds"))
	add_interact(LobbyBuilder.START_BTN + Vector3(0, 0, 2.6), 1.6, _next_text, _cycle_game)
	add_interact(LobbyBuilder.SHOP, 3.5, "Browse the PERK SHOP", _open_casino.bind("shop"))
	add_interact(LobbyBuilder.KENNEL + Vector3(-3, 0, -0.9), 2.4, "Adopt a bot (host)", _server_call.bind("req_bot", [true]))
	add_interact(LobbyBuilder.KENNEL + Vector3(5, 0, -0.9), 2.4, "Release a bot (host)", _server_call.bind("req_bot", [false]))
	add_interact(LobbyBuilder.TOILET, 2.4, "Sit down and flush", _server_call.bind("req_flush", []))
	add_interact(Playground.TROPHY + Vector3(0, 1, 0), 2.8, _trophy_text, _claim_trophy)
	add_interact(Playground.SUMMIT + Vector3(-4, 0, 3), 3.0, "Plant your flag on the summit", _server_call.bind("req_spot", ["summit"]))
	add_interact(Playground.VAULT + Vector3(0, 0, 1.5), 2.5, "Loot the Vault", _server_call.bind("req_spot", ["vault"]),
		func() -> bool: return vault_open > 0.0)
	add_interact(Playground.LEDGE + Vector3(0, 3.0, 0), 2.2, "Open the Friend Ledge chest", _server_call.bind("req_spot", ["ledge"]))
	add_interact(Playground.CAVE_CHEST, 3.2, "Open the cave chest", _server_call.bind("req_spot", ["cave"]))
	add_interact(Playground.CANNON + Vector3(0, 0.4, 5.6), 3.2, "Climb into the HUMAN CANNON", _enter_cannon)
	add_interact(Playground.CARNIVAL + Vector3(-7, 2.9, 40), 9.0, "Board THE SLOPPER", _ride_coaster, _not_riding)
	add_interact(Playground.FERRIS, 8.0, "Get on the Ferris wheel", _ride_ferris, _not_riding)
	add_interact(Playground.CAROUSEL + Vector3(0, 0.45, 0), 7.5, "Ride a duck", _ride_carousel, _not_riding)


func _not_riding() -> bool:
	var me := local_avatar()
	return me != null and not me.ride.is_valid()


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
	tables.leave()
	if _in_cannon and not _fuse_lit:  # climb back out
		_in_cannon = false
		_cannon_label.visible = false
		var me := local_avatar()
		if me:
			me.end_ride()
			me.place(Playground.CANNON + Vector3(0, 1.2, 7.0))
			_ev_cannon_body.rpc(me.pid, false)
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
			var lvl := Progress.level
			var i := Art.BODIES.find(p.get("body"))
			for k in Art.BODIES.size():
				i = (i + 1) % Art.BODIES.size()
				if Chars.unlocked(Art.BODIES[i], lvl):
					break
				toast("%s unlocks at LV %d" % [Chars.LABELS[Art.BODIES[i]], Chars.UNLOCK[Art.BODIES[i]]])
			val = Art.BODIES[i]
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
	PerkDB.apply(av, Net.perks_of(av.pid))
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
	banner("%s\nstarting %s..." % [mod.name, GAMES.get(Net.next_game, "?")], 3.5)
	if multiplayer.is_server():
		get_tree().create_timer(3.0).timeout.connect(_launch.bind(str(mod.id)))


func _launch(mod_id: String) -> void:
	var g := Net.next_game
	_last_game = g
	# Boss = whoever has been boss the fewest times (ties random). Pocket God's
	# god is the lobby leader, when there is one.
	var ids: Array = Net.players.keys()
	ids.shuffle()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(Net.players[a].giant_count) < int(Net.players[b].giant_count))
	var boss: int = ids[0]
	if g == "pocket":
		for id: int in ids:
			if Net.rank_of(id) == "leader":
				boss = id
	Net.players[boss].giant_count = int(Net.players[boss].giant_count) + 1
	Net.broadcast()
	ids.erase(boss)
	if g == "giant":
		Net.request_world("giant", {"giant": boss, "littles": ids, "modifier": mod_id, "seed": randi()})
	else:
		Net.request_world(g, {"boss": boss, "players": [boss] + ids, "modifier": mod_id, "seed": randi()})


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
	clock += delta
	_update_hazard_visuals(delta)
	_local_goals()
	_update_town(delta)
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
	var bag: int = (p.get("bag", []) as Array).size()
	_hud_info.text = line + "\nnext game: %s   perks: %s" % [GAMES.get(Net.next_game, "?"), PerkDB.summary(p.get("perks", []))]
	if bag > 0:
		_hud_info.text += "\ndirty bag: %d  (press %s)" % [bag, InputSetup.label("trick")]
	_update_fame()


func _update_fame() -> void:
	var ids: Array = Net.players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(Net.players[a].score) > int(Net.players[b].score))
	var lines: PackedStringArray = []
	for id: int in ids:
		lines.append("LV%-3d %-16s %3d pts  %4dc" % [int(Net.players[id].get("level", 1)), Net.pname(id),
			int(Net.players[id].score), int(Net.players[id].coins)])
	(_refs.fame as Label3D).text = "\n".join(lines)


func world_physics(delta: float) -> void:
	if multiplayer.is_server():
		_clock_t -= delta
		if _clock_t <= 0.0:
			_clock_t = 3.0
			_sync_clock.rpc(clock)
		_vault_tick(delta)
	for av: Avatar in avatars.values():
		if not av.controls():
			continue
		_hazard_hits(av)
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
			_bot_goals[av.pid] = Vector3(randf_range(-20, 22), 0, randf_range(-17, 20))
			av.bot_move = Vector3.ZERO
		else:
			av.bot_move = to.normalized() * (0.4 if randf() < 0.5 else 0.6)
		av.bot_jump = randf() < 0.004


# --- playground ------------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_clock(t: float) -> void:
	if absf(t - clock) > 0.25:
		clock = t
	else:
		clock = lerpf(clock, t, 0.5)


func _pendulum(h: Dictionary, t: float) -> Array:
	var w := TAU / float(h.period)
	var ang := float(h.amp) * sin(w * t)
	var angv := float(h.amp) * w * cos(w * t)
	var axis: Vector3 = h.axis
	var l := float(h.len)
	var pos: Vector3 = (h.pivot as Vector3) + axis * sin(ang) * l + Vector3.DOWN * cos(ang) * l
	var vel := (axis * cos(ang) + Vector3.UP * sin(ang)) * angv * l
	return [pos, vel, ang]


func _update_hazard_visuals(delta: float) -> void:
	for h: Dictionary in _play.get("hazards", []):
		match str(h.type):
			"sweeper":
				(h.node as Node3D).rotation.y = clock * float(h.speed)
			"pendulum":
				var r := _pendulum(h, clock)
				(h.ball as Node3D).global_position = r[0]
				var cable := h.cable as Node3D
				var piv: Vector3 = h.pivot
				var d: Vector3 = (r[0] as Vector3) - piv
				var yv := -d.normalized()
				var xv := yv.cross(Vector3.FORWARD if absf(yv.z) < 0.9 else Vector3.RIGHT).normalized()
				var zv := xv.cross(yv)
				cable.global_transform = Transform3D(Basis(xv, yv * d.length(), zv), piv)
	if _play.has("jib"):
		(_play.jib as Node3D).rotation.y = clock * 0.12
	if _play.has("drum"):
		(_play.drum as Node3D).rotate_object_local(Vector3.UP, delta * 1.5)
	if _play.has("beam"):
		(_play.beam as Node3D).rotation.y = clock * 0.9
	if _play.has("flag"):
		(_play.flag as Node3D).rotation.y = sin(clock * 2.0) * 0.25
	if _play.has("trophy"):
		(_play.trophy as Node3D).rotation.y = clock * 1.2
	if _play.has("fire"):
		var f := _play.fire as Node3D
		f.scale = Vector3(1, 1.0 + sin(clock * 13.0) * 0.08 + sin(clock * 7.0) * 0.05, 1)
	var door := _play.get("vault_door") as Node3D
	if door:
		var target := Playground.VAULT.y + (6.2 if vault_open > 0.0 else 2.0)
		door.position.y = move_toward(door.position.y, target, delta * 4.0)
		(door.get_child(1) as CollisionShape3D).disabled = door.position.y > Playground.VAULT.y + 4.0
	var plates: Array = _play.get("plates", [])
	for i in plates.size():
		(plates[i] as MeshInstance3D).position.y = Playground.PLATE_A.y + (0.17 if _plate_pressed(i) else 0.25)


## Doors swing, rides turn, casino machines spin. Purely visual, driven by the
## shared clock so every peer sees the same rides in the same place.
func _update_town(delta: float) -> void:
	(_play.coaster as Coaster).animate(clock)
	var rider := local_avatar()
	if _ride_lap_end > 0.0 and clock > _ride_lap_end:  # the lap is over: everybody off
		_ride_lap_end = -1.0
		if rider and rider.ride.is_valid():
			rider.end_ride()
			rider.place(Playground.CARNIVAL + Vector3(-7, 3.4, 41.0))
			toast("Thank you for riding THE SLOPPER. Refunds are not a thing.")
	var doors: Dictionary = _refs.get("saloon_doors", {})
	var open := 0.0
	var door_pos := LobbyBuilder.SALOON + Vector3(0, 0, 9)
	for av: Avatar in avatars.values():
		var d := av.global_position - door_pos
		if absf(d.x) < 2.6 and absf(d.z) < 2.2:
			open = maxf(open, 1.0 if d.z > 0.0 else -1.0) if d.z > 0.0 else minf(open, -1.0)
	_door_a = lerpf(_door_a, open * 1.45, clampf(delta * 10.0, 0.0, 1.0))
	if doors.has("doorL"):
		(doors.doorL as Node3D).rotation.y = -_door_a
		(doors.doorR as Node3D).rotation.y = _door_a
	if _play.has("carousel"):
		(_play.carousel as Node3D).rotation.y = clock * 0.45
	var ferris: Dictionary = _play.get("ferris", {})
	if ferris.has("rotor"):
		var a := clock * 0.16
		(ferris.rotor as Node3D).rotation.z = a
		var hub: Vector3 = (ferris.rotor as Node3D).position
		for i in 12:
			var car: Node3D = ferris.get("car%d" % i)
			var ca := TAU * i / 12.0 + a
			car.position = hub + Vector3(cos(ca), sin(ca), 0) * 13.0


## Called on every peer when anyone plays a machine (see Casino._fx).
func casino_fx(kind: String, seat: int, data: Dictionary) -> void:
	floor_fx.fx(kind, seat, data)


## Owner-side hazard + bounce-pad checks (players and host-run bots).
func _hazard_hits(av: Avatar) -> void:
	if av.dead or av.ragdolled():
		return
	var now := Time.get_ticks_msec()
	var mid := av.global_position + Vector3.UP * 0.8 * av.size
	for h: Dictionary in _play.get("hazards", []):
		var key := "%d_%d" % [av.pid, h.hash()]
		if now - int(_hz_cd.get(key, 0)) < 900:
			continue
		match str(h.type):
			"sweeper":
				var c: Vector3 = h.center
				var rel := av.global_position - c
				var flat := Vector2(rel.x, rel.z)
				if flat.length() > float(h.r) + 0.3 or rel.y < -0.2 or rel.y > 1.25:
					continue
				var ang := float(h.speed) * clock
				var bar := Vector2(cos(ang), -sin(ang))
				var dist := absf(flat.x * bar.y - flat.y * bar.x)
				if dist < 0.55 + 0.36 * av.size:
					var tangent := Vector3(-flat.y, 0, flat.x).normalized() * signf(float(h.speed))
					_hz_cd[key] = now
					av.self_hit(tangent * 13.0 + Vector3.UP * 6.0)
			"pendulum":
				var r := _pendulum(h, clock)
				if mid.distance_to(r[0]) < float(h.r) + 0.45 * av.size:
					_hz_cd[key] = now
					var v: Vector3 = r[1]
					av.self_hit(v * 1.25 + (mid - (r[0] as Vector3)).normalized() * 5.0 + Vector3.UP * 5.0)
					Sfx.at(self, "bonk", mid, 2.0, 0.1, 0.6)
	for pad: Dictionary in _play.get("pads", []):
		var p: Vector3 = pad.pos
		var rel := av.global_position - p
		if Vector2(rel.x, rel.z).length() < float(pad.r) and rel.y > -0.2 and rel.y < 0.8 and av.velocity.y <= 0.5:
			av.velocity = pad.vel
			av.floor_vis = false
			Sfx.at(self, "boing", p, 2.0)
			var top := pad.node as Node3D
			var tw := top.create_tween()
			tw.tween_property(top, "scale", Vector3(1.3, 3.0, 1.3), 0.06)
			tw.tween_property(top, "scale", Vector3.ONE, 0.2)


func _plate_pressed(i: int) -> bool:
	var pp: Vector3 = [Playground.PLATE_A, Playground.PLATE_B][i]
	for av: Avatar in avatars.values():
		var d := av.global_position - pp
		if not av.dead and Vector2(d.x, d.z).length() < 1.7 and d.y > -0.5 and d.y < 1.5:
			return true
	for p: Prop in props.list:
		var d := p.global_position - pp
		if p.solid and p.mass >= 2.5 and p.holder == 0 and Vector2(d.x, d.z).length() < 1.7 and d.y < 1.6 and d.y > -0.5:
			return true
	return false


func _vault_tick(delta: float) -> void:
	var was := vault_open > 0.0
	if _plate_pressed(0) and _plate_pressed(1):
		vault_open = 12.0
	else:
		vault_open = maxf(0.0, vault_open - delta)
	if (vault_open > 0.0) != was:
		_ev_vault.rpc(vault_open)


@rpc("authority", "call_local", "reliable")
func _ev_vault(t: float) -> void:
	if not multiplayer.is_server():
		vault_open = t
	var on := t > 0.0
	if on == _vault_vis:
		return
	_vault_vis = on
	if on:
		banner("THE VAULT IS OPEN!", 2.0)
		Sfx.at(self, "ding", Playground.VAULT, 6.0)
	else:
		Sfx.at(self, "thud", Playground.VAULT, 4.0)


## Server: one-off reward spots around the island (once per player per lobby visit).
@rpc("any_peer", "reliable")
func req_spot(kind: String) -> void:
	if not multiplayer.is_server():
		return
	var id := Net.sender()
	var av: Avatar = avatars.get(id)
	if av == null or av.dead:
		return
	var key := "%s_%d" % [kind, id]
	if _session_done.has(key):
		Net.call_peer(id, self, "_spot_msg", ["Already looted. Come back after the next game!"])
		return
	var p := av.global_position
	var ok := false
	var coins := 10
	match kind:
		"summit": ok = p.y > 26.0
		"vault":
			ok = vault_open > 0.0 and p.distance_to(Playground.VAULT) < 8.0
			coins = 75
		"ledge": ok = p.y > Playground.LEDGE.y + 2.6 and p.distance_to(Playground.LEDGE) < 4.0
		"cave":
			ok = p.distance_to(Playground.CAVE_CHEST) < 6.0
			coins = 40
	if not ok:
		return
	_session_done[key] = true
	Net.give_coins(id, coins)
	Net.broadcast()
	var lines := {"summit": "planted a flag on SLIDE HILL", "vault": "cracked THE VAULT", "ledge": "reached FRIEND LEDGE",
		"cave": "found the cave treasure"}
	Net.announce("%s %s (+%dc)" % [Net.pname(id), lines[kind], coins])
	Net.award(id, 0, "", kind)
	_spot_fx.rpc(p)


@rpc("authority", "call_local", "reliable")
func _spot_fx(p: Vector3) -> void:
	Fx.confetti(self, p + Vector3.UP * 1.5, 70)
	Sfx.at(self, "coin", p, 2.0)


@rpc("authority", "call_local", "reliable")
func _spot_msg(msg: String) -> void:
	toast(msg)


func _trophy_text() -> String:
	if _gauntlet_start < 0.0:
		return "Grab the trophy (start at THE GAUNTLET gate to get timed)"
	return "GRAB THE TROPHY  (%.1fs)" % (clock - _gauntlet_start)


func _claim_trophy() -> void:
	if _gauntlet_start < 0.0:
		toast("Run THE GAUNTLET from the start gate first!")
		return
	var t := clock - _gauntlet_start
	_gauntlet_start = -1.0
	Net.to_server(self, "req_gauntlet", [t])


@rpc("any_peer", "reliable")
func req_gauntlet(t: float) -> void:
	if not multiplayer.is_server():
		return
	var id := Net.sender()
	var av: Avatar = avatars.get(id)
	if av == null or av.global_position.distance_to(Playground.TROPHY) > 5.0 or t < 6.0:
		return
	var best := float(_refs.get("best_gauntlet", 9999.0))
	var record := t < best
	if record:
		_refs.best_gauntlet = t
	var coins := 30 if not _session_done.has("g_%d" % id) else 5
	_session_done["g_%d" % id] = true
	Net.give_coins(id, coins)
	Net.broadcast()
	Net.announce("%s beat THE GAUNTLET in %.1fs%s (+%dc)" % [Net.pname(id), t, "  NEW RECORD!" if record else "", coins])
	Net.award(id, 0, "", "gauntlet")
	_spot_fx.rpc(av.global_position)


## Local-only goals: gauntlet timer start, slide-down challenge.
func _local_goals() -> void:
	var me := local_avatar()
	if me == null or me.dead:
		return
	var p := me.global_position
	if p.x < -51.0 and p.x > -53.0 and absf(p.z - Playground.GAUNTLET_Z) < 3.5 and p.y > -1.0 and _gauntlet_start < 0.0:
		_gauntlet_start = clock
		toast("GAUNTLET: GO GO GO! (grab the trophy at the end)")
		Sfx.ui(self, "click")
	if p.distance_to(Playground.DIVE) < 12.0:
		_dive_top = maxf(_dive_top, p.y)
	elif me.is_on_floor() and p.distance_to(Playground.DIVE) > 14.0:
		_dive_top = 0.0
	if me.state == Avatar.St.SLIDE and p.z < -75.0 and absf(p.x) < 4.0:
		_slide_from_top = true
	if _slide_from_top and me.state != Avatar.St.SLIDE:
		if p.z > -50.0 and not _session_done.has("slide_local"):
			_session_done["slide_local"] = true
			Progress.challenge("slide")
		_slide_from_top = false


# --- rides --------------------------------------------------------------------

func _ride_coaster() -> void:
	var me := local_avatar()
	var co: Coaster = _play.coaster
	if me == null:
		return
	if not co.boarding(clock):
		toast("Train leaves in a moment. Wait for it (%.0fs)" % co.lap_left(clock))
		return
	var seat := randi() % Coaster.CARS
	me.ride = func() -> Transform3D: return co.seat(seat, clock)
	_ride_lap_end = clock + co.lap_left(clock)
	toast("Hands inside. Jump to bail.")


func _ride_ferris() -> void:
	var me := local_avatar()
	var f: Dictionary = _play.ferris
	if me == null:
		return
	var best: Node3D = null
	var bd := 6.0
	for i in 12:
		var car: Node3D = f["car%d" % i]
		var d := car.global_position.distance_to(me.global_position + Vector3.UP * 2.0)
		if d < bd:
			bd = d
			best = car
	if best == null:
		toast("No gondola in reach. Wait for one to come down.")
		return
	me.ride = func() -> Transform3D: return Transform3D(Basis.IDENTITY, best.global_position + Vector3.DOWN * 1.35)
	toast("You're on. Jump to get off (mind the drop).")


func _ride_carousel() -> void:
	var me := local_avatar()
	if me == null:
		return
	var i := randi() % 8
	var at: Vector3 = Playground.CAROUSEL
	var top := _play.carousel as Node3D
	me.ride = func() -> Transform3D:
		var a := -top.rotation.y + i * TAU / 8.0
		return Transform3D(Basis(Vector3.UP, -a - PI * 0.5), at + Vector3(cos(a) * 5.0, 2.1, sin(a) * 5.0))
	toast("Yeehaw, or quack. Jump to get off.")


# --- the human cannon -----------------------------------------------------------

func _enter_cannon() -> void:
	var me := local_avatar()
	if me == null or _in_cannon:
		return
	_in_cannon = true
	ui_open = true
	me.ride = func() -> Transform3D: return Transform3D(Basis.IDENTITY, Playground.CANNON + Vector3(0, 2.3, 0))
	_ev_cannon_body.rpc(me.pid, true)
	_aim_cannon()
	cam.shake(0.2)
	Sfx.at(self, "pop", me.global_position, 0.0, 0.1, 0.6)


func _aim_cannon() -> void:
	var t: Array = CANNON_TARGETS[_cannon_aim]
	_cannon_label.text = "AIMING AT: %s\n[%s/%s] change target   [%s] LIGHT THE FUSE   [%s] climb out" % [t[0],
		InputSetup.label("ability_1"), InputSetup.label("ability_2"), InputSetup.label("interact"), InputSetup.label("menu")]
	_cannon_label.visible = true
	_point_barrel(_cannon_aim)


func _point_barrel(i: int) -> void:
	var barrel := _play.cannon as Node3D
	var to: Vector3 = CANNON_TARGETS[i][1] - Playground.CANNON
	var v := cannon_velocity(Playground.CANNON + CANNON_MOUTH, CANNON_TARGETS[i][1], float(CANNON_TARGETS[i][2]))
	var world_yaw := atan2(to.x, to.z)
	var tw := barrel.create_tween()
	# the landmark is turned 180 degrees, so barrel yaw is measured from its back
	tw.tween_property(barrel, "rotation:y", wrapf(world_yaw - PI, -PI, PI), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(barrel, "rotation:x", -clampf(atan2(v.y, Vector2(v.x, v.z).length()), 0.3, 1.3), 0.5)


func _input(event: InputEvent) -> void:
	if not _in_cannon or _fuse_lit:
		return
	var step := -1 if event.is_action_pressed("ability_1") else (1 if event.is_action_pressed("ability_2") else 0)
	if step != 0:
		_cannon_aim = posmod(_cannon_aim + step, CANNON_TARGETS.size())
		_aim_cannon()
		Sfx.ui(self, "click")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_light_fuse()


func _light_fuse() -> void:
	_fuse_lit = true
	_cannon_label.text = "FSSSSSSSS"
	Net.to_server(self, "req_fuse", [_cannon_aim])


@rpc("any_peer", "reliable")
func req_fuse(i: int) -> void:
	if multiplayer.is_server() and i >= 0 and i < CANNON_TARGETS.size():
		_ev_fuse.rpc(Net.sender(), i)


## Everyone watches the barrel swing and the fuse burn. The rider launches themself.
@rpc("authority", "call_local", "reliable")
func _ev_fuse(pid: int, i: int) -> void:
	_point_barrel(i)
	var at := Playground.CANNON + Vector3(0, 2.0, 3.6)
	Sfx.at(self, "hiss", at, 2.0, 0.0, 1.4)
	for k in 6:
		get_tree().create_timer(k * 0.35).timeout.connect(func() -> void:
			if is_inside_tree():
				Fx.impact(self, at + Vector3(0, 0.2, 0), 0.4))
	Net.announce("%s lit the fuse on the HUMAN CANNON" % Net.pname(pid))
	await get_tree().create_timer(FUSE_SECS).timeout
	if not is_inside_tree():
		return
	var mouth := Playground.CANNON + CANNON_MOUTH
	Fx.explosion(self, mouth, 2.5)
	Sfx.at(self, "boom", mouth, 4.0, 0.05, 1.3)
	var me := local_avatar()
	if me and me.global_position.distance_to(mouth) < 30.0:
		cam.shake(0.7)
	_ev_cannon_body(pid, false)
	if pid == Net.me():
		launch_cannon(i)


## Owner side: into the air, using the same velocity write as a bounce pad.
func launch_cannon(i: int) -> void:
	var me := local_avatar()
	_in_cannon = false
	_fuse_lit = false
	ui_open = false
	_cannon_label.visible = false
	if me == null:
		return
	me.end_ride()
	var t: Array = CANNON_TARGETS[i]
	me.global_position = Playground.CANNON + CANNON_MOUTH
	me.velocity = cannon_velocity(me.global_position, t[1], float(t[2]))
	me.floor_vis = false
	toast("WHEEEEEEEEE")


## Solves the arc for the avatar's real gravity (slower up, 1.55x down).
static func cannon_velocity(from: Vector3, to: Vector3, vy: float) -> Vector3:
	var g := Avatar.GRAVITY
	var rise := vy * vy / (2.0 * g)
	var drop := rise + from.y - to.y
	var t := vy / g + sqrt(2.0 * maxf(drop, 0.1) / (g * Avatar.FALL_MULT))
	var flat := Vector3(to.x - from.x, 0, to.z - from.z) / t
	return Vector3(flat.x, vy, flat.z)


@rpc("authority", "call_local", "reliable")
func _ev_cannon_body(pid: int, hide_body: bool) -> void:
	var av: Avatar = avatars.get(pid)
	if av and av.parts.has("root"):
		(av.parts.root as Node3D).visible = not hide_body


# --- the toilet ------------------------------------------------------------------

@rpc("any_peer", "reliable")
func req_flush() -> void:
	if not multiplayer.is_server():
		return
	var id := Net.sender()
	var av: Avatar = avatars.get(id)
	if av == null or av.dead or _flushing.has(id):
		return
	_flushing[id] = true
	var count := int(_flush_count.get(id, 0)) + 1
	_flush_count[id] = count
	var roll := randf()
	var kind := "clog" if roll < 0.14 else ("gold" if roll < 0.2 else "normal")
	var outlet := randi() % FLUSH_OUTLETS.size()
	if kind == "gold":
		Net.give_coins(id, 40)
		Net.broadcast()
	_ev_flush.rpc(id, outlet, kind, count)


@rpc("authority", "call_local", "reliable")
func _ev_flush(pid: int, outlet: int, kind: String, count: int) -> void:
	var av: Avatar = avatars.get(pid)
	if av == null:
		return
	var seat := LobbyBuilder.TOILET + Vector3(0, 1.0, 1.5)
	Sfx.at(self, "flush", seat, 4.0, 0.05)
	Fx.text(self, seat + Vector3.UP * 3.2, FLUSH_LINES[count % FLUSH_LINES.size()], Color("#9fe6ff"), 0.011, 1.0, 2.2)
	var body: Node3D = av.parts.root
	if av.is_local():
		av.ride = func() -> Transform3D: return Transform3D(Basis.IDENTITY, seat)
		cam.wobble = 2.0
	var tw := body.create_tween().set_parallel(true)
	tw.tween_property(body, "rotation:y", TAU * 5.0, FLUSH_SECS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "scale", Vector3(0.05, 0.05, 0.05), FLUSH_SECS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(FLUSH_SECS + 0.15).timeout
	if not is_inside_tree() or not is_instance_valid(av):
		return
	body.rotation.y = 0.0
	body.create_tween().tween_property(body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var at: Vector3 = FLUSH_OUTLETS[outlet][0]
	var up := 15.0
	var where := "%s came out of %s" % [Net.pname(pid), FLUSH_OUTLETS[outlet][1]]
	match kind:
		"clog":  # it comes straight back up
			at = seat + Vector3.UP * 0.5
			up = 34.0
			where = "THE TOILET REJECTED %s" % Net.pname(pid)
			Fx.explosion(self, seat, 3.0)
		"gold":
			where = "%s hit the GOLDEN FLUSH (+40c) and came out of %s" % [Net.pname(pid), FLUSH_OUTLETS[outlet][1]]
			Fx.confetti(self, at, 50)
	toast(where)
	Fx.splash(self, at)
	Sfx.at(self, "boing", at, 2.0, 0.1, 0.7)
	if av.is_local():
		av.end_ride()
		av.place(at)
		av.velocity = Vector3(randf_range(-3, 3), up, randf_range(-3, 3))
		av.floor_vis = false
		Net.to_server(self, "req_flushed", [])


@rpc("any_peer", "reliable")
func req_flushed() -> void:
	_flushing.erase(Net.sender())


func respawn_for(av: Avatar) -> Vector3:
	var p := av.global_position
	var r := Vector2(p.x, p.z).length()
	if Playground._cove(p.x, p.z, r) > 0.05 or p.distance_to(Playground.DIVE) < 40.0:
		if av.is_local() and _dive_top > 12.0:
			Progress.challenge("dive")
			toast("DIVE SCORE: %.0f m" % _dive_top)
		_dive_top = 0.0
		return Playground.PIER_START + Vector3(0, 0.6, 0)
	if p.x < -50.0 and absf(p.z) < 36.0:
		if av.is_local():
			_gauntlet_start = -1.0
		return Playground.GAUNTLET_START if p.z > 0.0 else Playground.BRIDGE_START
	return av._spawn
