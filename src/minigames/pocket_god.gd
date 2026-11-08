class_name PocketGod
extends OverlordGame
## POCKET GOD. The lobby leader becomes a god. The masses win by finishing the
## rocket (carry scrap to the launch pad) or by praying at shrines until the god
## is dethroned. The god wins if the clock runs out.
## Betrayal: the god may anoint one prophet, who can't be smitten and scores
## double if the god wins. Nobody else is told who it is.

const SEA_Y := -1.0
const FLOOD_Y := 2.4
const FLOOD_SECS := 8.0
const PAD_Y := 4.0
const PAD_R := 6.5
const SHRINE_R := 4.0
const SHRINES := [Vector3(38, 5, 0), Vector3(-19, 5, 33), Vector3(-19, 5, -33)]
const SCRAP_KINDS := ["scrap_fin", "scrap_bin", "scrap_nose"]
const STAGES := 8
const MUTINY_SECS := 70.0  # time for a third of the team to dethrone the god
const CAMP := Vector3(0, 0, 34)  # the castaways' workshop, facing the pad

var need := 8
var rocket := 0
var mutiny := 0.0
var flood_t := 0.0
var prophet := 0
var flood_y := SEA_Y
var _sea: MeshInstance3D
var _stages: Dictionary = {}
var _scrap: Array = []
var _brain: Dictionary = {}


static func height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var h := 1.0 + sin(x * 0.17) * cos(z * 0.13) * 0.35
	h = lerpf(h, PAD_Y, 1.0 - smoothstep(14.0, 24.0, r))
	for s: Vector3 in SHRINES:
		var d := Vector2(x - s.x, z - s.z).length()
		h = lerpf(h, s.y, 1.0 - smoothstep(6.0, 16.0, d))
	return lerpf(h, -7.0, smoothstep(58.0, 74.0, r))


static func color(_x: float, _z: float, h: float, n: Vector3) -> Color:
	if n.y < 0.8:
		return Art.P_ROCK
	if h < 0.3:
		return Art.P_SAND
	return Art.P_GRASS if h < 3.0 else Art.P_GRASS_LIGHT


func powers() -> Array:
	return [
		{"id": "bolt", "act": "primary", "cd": 3.0, "label": "lightning"},
		{"id": "meteor", "act": "secondary", "cd": 12.0, "label": "meteor"},
		{"id": "flood", "act": "ability_1", "cd": 35.0, "label": "flood"},
		{"id": "dance", "act": "ability_2", "cd": 22.0, "label": "make them dance"},
		{"id": "hand", "act": "interact", "cd": 9.0, "label": "giant hand"},
		{"id": "anoint", "act": "god", "cd": 9999.0, "label": "anoint prophet"},
	]


func build_arena() -> void:
	make_environment(Color("#3a5fc0"), Color("#ffd0a8"), 0.62, 0.95, 120.0, 460.0, Vector3(-38, 60, 0), Color("#fff0dc"))
	water_y = SEA_Y - 0.4
	Terrain.build(self, Callable(PocketGod, "height"), Callable(PocketGod, "color"), 84.0, 3.0)
	_sea = Terrain.water(self, SEA_Y, 700.0)
	var b := Batch.new()
	var pad := Kit.landmark(self, b, "rocket", Vector3(0, PAD_Y, 0))
	_stages = pad.dyn
	for k: String in _stages:
		(_stages[k] as Node3D).visible = false
	for s: Vector3 in SHRINES:
		Kit.landmark(self, b, "shrine", s, rad_to_deg(atan2(-s.x, -s.z)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 34:
		var a := rng.randf() * TAU
		var d := rng.randf_range(24.0, 60.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = height(p.x, p.z)
		if p.y > 0.5 and Vector2(p.x - CAMP.x, p.z - CAMP.z).length() > 10.0:
			var t: Array = OverlordArt.TREES[i % OverlordArt.TREES.size()]
			Dress.tree(self, b, t[0], p, rng.randf() * 360.0, float(t[1]) * rng.randf_range(0.9, 1.4), 0.3)
	for i in 26:
		var a := float(i) * 2.4
		var d := 22.0 + float(i % 9) * 4.5
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = height(p.x, p.z) + 1.0
		_scrap.append(props.spawn(SCRAP_KINDS[i % SCRAP_KINDS.size()], p, float(i) * 40.0))
	Art.label(self, "BUILD THE ROCKET\n(bring scrap)", Vector3(0, PAD_Y + 6.5, 9.0), 0.016, Ui.YELLOW)
	for s: Vector3 in SHRINES:
		Art.label(self, "PRAY HERE\n(stand in the circle)", s + Vector3(0, 4.4, 0), 0.012, Art.GOLD)
	# a beach camp + wrecked first attempt: this is not their first rocket
	Dress.put(self, b, "pirate_ship_wreck", Vector3(-58, -1.0, 38), 30.0, 1.4)
	Dress.put(self, b, "nature_tent_detailedOpen", Vector3(30, height(30, 30), 30), 200.0, 4.2, Dress.COL_BOX)
	Dress.put(self, b, "watercraft_cargo_container_a", Vector3(26, height(26, -26), -26), 40.0, 2.0, Dress.COL_BOX)
	Dress.put(self, b, "retrourban_truck_flat", Vector3(-34, height(-34, -6), -6), 70.0, 3.2, Dress.COL_BOX)
	Kit.landmark(self, b, "pg_camp", Vector3(CAMP.x, height(CAMP.x, CAMP.z), CAMP.z), 180.0)
	Dress.put(self, b, "nature_statue_head" if Kit.has("nature_statue_head") else "nature_rock_largeA", Vector3(0, height(0, -52), -52), 0.0, 5.0, Dress.COL_BOX)
	b.absorb(self, [_sea] + _stages.values())
	b.commit(self)


func mortal_spawn(index: int) -> Vector3:
	var a := index * 1.3
	return Vector3(cos(a) * 11.0, PAD_Y + 1.0, sin(a) * 11.0)


func game_begin() -> void:
	var me := Net.me()
	if me == boss_id:
		banner("YOU ARE GOD\nstop them leaving. fly with your move keys", 5.0)
	else:
		banner("A GOD IS WATCHING\nbuild the rocket or pray them off the throne", 5.0)
	if not multiplayer.is_server():
		return
	var n := mortals().size()
	need = 6 + n * 2
	time_left = clampf(150.0 + 30.0 * n, 200.0, 420.0)
	extra = {"rocket": 0, "need": need, "mutiny": 0.0, "flood": 0.0}


func game_tick(delta: float) -> void:
	tick_powers(delta)
	if flood_t > 0.0:
		flood_t -= delta
	_scrap_tick()
	_pray_tick(delta)
	_bots(delta)
	extra.rocket = rocket
	extra.need = need
	extra.mutiny = mutiny
	extra.flood = flood_t
	if rocket >= need:
		_mortals_win("THE ROCKET LEAVES. GOD IS LEFT WITH NOBODY")
	elif mutiny >= 100.0:
		_mortals_win("THE GOD HAS BEEN DETHRONED")


func on_time_up() -> void:
	var pays := {boss_id: [3, 80, 150]}
	var win: Array = [boss_id]
	if prophet != 0:
		pays[prophet] = [4, 100, 150]
		win.append(prophet)
	finish("TIME'S UP. GOD REMAINS." + ("\nThe prophet was %s" % Net.pname(prophet) if prophet != 0 else ""), win, pays)


func on_player_left(id: int) -> void:
	if id == boss_id:
		_mortals_win("GOD LOGGED OFF")


func _mortals_win(msg: String) -> void:
	var pays := {}
	var win := mortals()
	for id: int in win:
		pays[id] = [2, 60, 110]
	if prophet != 0:  # a prophet of a failed god gets nothing
		pays.erase(prophet)
		win.erase(prophet)
	finish(msg, win, pays)


func _scrap_tick() -> void:
	var pad := Vector3(0, PAD_Y, 0)
	for pr: Prop in _scrap:
		if pr.gone:
			continue
		if Vector2(pr.global_position.x, pr.global_position.z).length() > PAD_R or absf(pr.global_position.y - pad.y) > 3.0:
			continue
		if pr.holder != 0:
			props.do_release(pr.holder, false, Vector3.ZERO)
		props._ev_gone.rpc(pr.id, true)
		rocket += 1
		_ev_scrap.rpc(rocket, need)
		get_tree().create_timer(14.0).timeout.connect(func() -> void:
			if is_inside_tree() and not over:
				props._ev_gone.rpc(pr.id, false))


func _pray_tick(delta: float) -> void:
	var rate := 100.0 / MUTINY_SECS * 3.0 / maxf(1.0, mortals().size())
	var praying := 0
	for av: Avatar in alive_mortals():
		if av.ragdolled() or av.pid == prophet:
			continue
		for s: Vector3 in SHRINES:
			if Vector2(av.global_position.x - s.x, av.global_position.z - s.z).length() < SHRINE_R:
				praying += 1
				break
	mutiny = clampf(mutiny + (praying * rate - 0.6) * delta, 0.0, 100.0)


func cast(id: String, pos: Vector3) -> void:
	match id:
		"bolt":
			strike(pos, 3.5, 0.7, 24.0, prophet)
		"meteor":
			strike(pos, 8.0, 1.8, 34.0, prophet)
		"flood":
			flood_t = FLOOD_SECS
			Net.announce("THE WATERS RISE")
		"dance":
			for av: Avatar in alive_mortals():
				if av.pid != prophet and av.global_position.distance_to(pos) < 14.0:
					tricks.hex_on(av.pid, "dance", 3.0)
		"hand":
			var best: Avatar = _nearest_mortal(pos, 8.0)
			if best:
				_ev_hand.rpc(best.global_position)
				best.push.rpc(Vector3(randf_range(-14, 14), 26.0, randf_range(-14, 14)))
		"anoint":
			var a: Avatar = _nearest_mortal(pos, 12.0)
			if a == null:
				cds.erase("anoint")
				return
			prophet = a.pid
			Net.call_peer(a.pid, self, "_ev_prophet")
			Net.call_peer(boss_id, self, "_ev_anointed", [Net.pname(a.pid)])


func _nearest_mortal(pos: Vector3, r: float) -> Avatar:
	var best: Avatar = null
	for av: Avatar in alive_mortals():
		var d := av.global_position.distance_to(pos)
		if d < r and av.pid != prophet:
			r = d
			best = av
	return best


@rpc("authority", "call_local", "reliable")
func _ev_scrap(n: int, total: int) -> void:
	rocket = n
	toast("Rocket %d / %d" % [n, total])
	Sfx.at(self, "knock", Vector3(0, PAD_Y, 0), 2.0, 0.2, 0.8)
	Fx.impact(self, Vector3(0, PAD_Y + 1.5, 0), 1.2)


@rpc("authority", "reliable")
func _ev_prophet() -> void:
	banner("GOD HAS CHOSEN YOU\nyou can't be smitten. if god wins, you win double.\ntell nobody.", 5.0)


@rpc("authority", "reliable")
func _ev_anointed(who: String) -> void:
	toast("%s is your prophet" % who)


@rpc("authority", "call_local", "reliable")
func _ev_hand(pos: Vector3) -> void:
	var h := Node3D.new()
	add_child(h)
	h.position = pos + Vector3.UP * 26.0
	var hand := MeshInstance3D.new()
	hand.mesh = Kit.part_mesh("game_bits", "hand")
	hand.material_override = Art.vcol_mat()
	h.add_child(hand)
	var tw := h.create_tween()
	tw.tween_property(h, "position", pos + Vector3.UP * 1.5, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(h, "position", pos + Vector3.UP * 30.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(h.queue_free)
	Sfx.at(self, "slap", pos, 6.0, 0.1, 0.7)


func game_visuals(delta: float) -> void:
	var want := FLOOD_Y if float(extra.get("flood", 0.0)) > 0.0 else SEA_Y
	flood_y = move_toward(flood_y, want, delta * 1.2)
	_sea.position.y = flood_y
	water_y = flood_y - 0.4
	var built := float(extra.get("rocket", rocket)) / maxf(1.0, float(extra.get("need", need)))
	for i in STAGES:
		var n: Node3D = _stages.get("s%d" % i)
		if n:
			n.visible = built * STAGES > i


func respawn_for(_av: Avatar) -> Vector3:
	return mortal_spawn(randi() % 8)


func info_text() -> String:
	var line := "ROCKET %d/%d    MUTINY %d%%" % [int(extra.get("rocket", 0)), int(extra.get("need", 0)), int(extra.get("mutiny", 0.0))]
	if Net.me() == boss_id:
		return boss_info() + "\n" + line
	return line + "    grab scrap with %s, or stand in a shrine circle" % InputSetup.label("interact")


func board_lines() -> PackedStringArray:
	return PackedStringArray(["GOD: %s" % Net.pname(boss_id)])


func _bots(delta: float) -> void:
	for av: Avatar in alive_mortals():
		if not av.is_bot:
			continue
		var b: Dictionary = _brain.get(av.pid, {"pray": randf() < 0.35, "t": 0.0, "spot": SHRINES.pick_random()})
		_brain[av.pid] = b
		b.t = float(b.t) - delta
		var goal: Vector3 = b.spot
		if not bool(b.pray):
			if av.holding:
				goal = Vector3.ZERO
			else:
				var pr := _closest_scrap(av.global_position)
				if pr == null:
					continue
				goal = pr.global_position
				if av.global_position.distance_to(goal) < 2.6 and float(b.t) <= 0.0:
					b.t = 1.0
					props.do_grab(av.pid, pr.id)
		var to := goal - av.global_position
		to.y = 0.0
		av.bot_move = to.normalized() if to.length() > 1.0 else Vector3.ZERO
		av.bot_sprint = true
		av.bot_jump = randf() < 0.01


func _closest_scrap(p: Vector3) -> Prop:
	var best: Prop = null
	var bd := INF
	for pr: Prop in _scrap:
		if pr.gone or pr.holder != 0:
			continue
		var d := pr.global_position.distance_to(p)
		if d < bd and Vector2(pr.global_position.x, pr.global_position.z).length() > PAD_R:
			bd = d
			best = pr
	return best
