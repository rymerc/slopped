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
var _play: Dictionary = {}
var clock := 0.0  # shared hazard clock (host re-syncs it)
var _clock_t := 0.0
var _hz_cd: Dictionary = {}
var vault_open := 0.0
var _vault_vis := false
var _gauntlet_start := -1.0
var _slide_from_top := false
var _session_done: Dictionary = {}


func build_world() -> void:
	make_environment(Color("#3d8ef0"), Color("#bfe6ff"), 0.55, 0.78, 120.0, 520.0)
	_refs = LobbyBuilder.build(self)
	_play = Playground.build(self, props)
	water_y = Playground.KILL_Y
	allow_shove = true
	for i in 3:
		props.spawn("duck", LobbyBuilder.DUCKS + Vector3(-3.5 - i * 0.8, 0.5, 4.0))
	for i in 3:
		props.spawn("ball", Vector3(-8 + i * 8.0, 1.0, 12))
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
	var help := Ui.label("WASD move  SHIFT sprint  SPACE jump  C dive/slide  E grab/use  LMB shove/throw  G smite (leader)  ESC menu", 16)
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
	add_interact(Playground.TROPHY + Vector3(0, 1, 0), 2.8, _trophy_text, _claim_trophy)
	add_interact(Playground.SUMMIT + Vector3(-4, 0, 3), 3.0, "Plant your flag on the summit", _server_call.bind("req_spot", ["summit"]))
	add_interact(Playground.VAULT + Vector3(0, 0, 1.5), 2.5, "Loot the Vault", _server_call.bind("req_spot", ["vault"]),
		func() -> bool: return vault_open > 0.0)
	add_interact(Playground.LEDGE + Vector3(0, 3.0, 0), 2.2, "Open the Friend Ledge chest", _server_call.bind("req_spot", ["ledge"]))
	add_interact(Playground.CAVE + Vector3(6.2, 0, 0), 2.4, "Open the cave chest", _server_call.bind("req_spot", ["cave"]))


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
	clock += delta
	_update_hazard_visuals(delta)
	_local_goals()
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
			_bot_goals[av.pid] = Vector3(randf_range(-26, 26), 0, randf_range(-20, 26))
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
					Sfx.at(self, "bonk", mid, 6.0, 0.1, 0.6)
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
			coins = 25
		"ledge": ok = p.y > Playground.LEDGE.y + 2.6 and p.distance_to(Playground.LEDGE) < 4.0
		"cave": ok = p.distance_to(Playground.CAVE) < 9.0
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
	Fx.confetti(self, p + Vector3.UP * 1.5, 36)
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
	if me.state == Avatar.St.SLIDE and p.z < -75.0 and absf(p.x) < 4.0:
		_slide_from_top = true
	if _slide_from_top and me.state != Avatar.St.SLIDE:
		if p.z > -50.0 and not _session_done.has("slide_local"):
			_session_done["slide_local"] = true
			Progress.challenge("slide")
		_slide_from_top = false


func respawn_for(av: Avatar) -> Vector3:
	var p := av.global_position
	if p.x < -50.0 and absf(p.z) < 36.0:
		if av.is_local():
			_gauntlet_start = -1.0
		return Playground.GAUNTLET_START if p.z > 0.0 else Playground.BRIDGE_START
	return av._spawn
