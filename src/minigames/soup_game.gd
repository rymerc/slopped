class_name SoupGame
extends OverlordGame
## THE FLOOR IS LAVA SOUP. A chef slowly raises boiling soup in a giant pot while
## tiny vegetables climb the food. Touch the soup and you're out. Last veg standing
## wins. The chef stirs, salts, chops and tastes. Vegetables can shove each other
## into the soup, which is the real game.

const POT_R := 29.0
const SOUP_START := -2.5  # below the pot floor: the first seconds are a safe scramble
const GRACE := 12.0  # seconds before the soup starts to rise
const SOUP_RATE := 0.22
const SOUP_MAX := 40.0
const HEAT_MULT := 3.0
const HEAT_SECS := 6.0
const CLIMB_STEP := 1.45
const CLIMB_TOP := 36.0
const SOLO_SURVIVE := 110.0  # 1v1: outlast this and the veg beats the chef
const BOT_LEAP := 11.0
## [mesh, scale]: "bits:" meshes are modelled in art_src/blender/arenas.py (game_bits)
const FOODS := [["bits:cracker", 1.0], ["food_pizza", 7.0], ["bits:carrot", 1.0], ["food_burger", 8.0],
	["bits:mushroom", 1.0], ["food_donut_sprinkles", 9.0]]

var soup_y := SOUP_START
var heat_t := 0.0
var _grace := GRACE
var _soup: MeshInstance3D
var _floaters: MeshInstance3D
var _out_order: Array = []
var _brain: Dictionary = {}
var _climb: Array[Vector3] = []


func powers() -> Array:
	return [
		{"id": "chop", "act": "primary", "cd": 3.0, "label": "chop"},
		{"id": "taste", "act": "secondary", "cd": 11.0, "label": "taste"},
		{"id": "stir", "act": "ability_1", "cd": 15.0, "label": "stir"},
		{"id": "salt", "act": "ability_2", "cd": 13.0, "label": "salt"},
		{"id": "heat", "act": "interact", "cd": 26.0, "label": "turn up the heat"},
	]


func boss_start() -> Vector3:
	return Vector3(0, 48, 34)


func build_arena() -> void:
	make_environment(Color("#6a5a90"), Color("#ffc09a"), 0.66, 0.9, 140.0, 420.0, Vector3(-55, 30, 0), Color("#fff0e0"))
	var b := Batch.new()
	var floor_body := StaticBody3D.new()
	floor_body.collision_mask = 0
	add_child(floor_body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(200, 1, 200)
	cs.shape = sh
	cs.position.y = -2.5
	floor_body.add_child(cs)
	Art.part(self, Art.box(Vector3(220, 1, 220)), Color("#8a6a55"), Vector3(0, -2.6, 0))
	Kit.landmark(self, b, "soup_pot", Vector3.ZERO)
	# everyone starts on a big raft of toast, just above the soup
	Art.col_cyl(self, 13.0, 1.0, Vector3(0, -1.2, 0))
	Kit.landmark(self, b, "soup_raft", Vector3(0, -1.2, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args.get("seed", 1))
	# one guaranteed spiral all the way up, plus decoys that dead-end
	var a := rng.randf() * TAU
	var y := 0.5
	var i := 0
	while y < CLIMB_TOP:
		var r := 17.0 + sin(float(i) * 0.7) * 4.0
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		_climb.append(p)
		_platform(b, p, FOODS[i % FOODS.size()])
		if i % 3 == 0:
			var off := a + rng.randf_range(1.5, 4.5)
			var r2 := rng.randf_range(7.0, 23.0)
			_platform(b, Vector3(cos(off) * r2, y + rng.randf_range(-0.5, 0.5), sin(off) * r2), FOODS[(i + 1) % FOODS.size()])
		a += deg_to_rad(21.0)
		y += CLIMB_STEP
		i += 1
	_soup = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = POT_R + 0.4
	disc.bottom_radius = POT_R + 0.4
	disc.height = 0.1
	disc.radial_segments = 48
	disc.rings = 1
	_soup.mesh = disc
	var m := ShaderMaterial.new()
	m.shader = Art.WATER
	m.set_shader_parameter("shallow", Color("#ffb347"))
	m.set_shader_parameter("deep", Color("#d9531e"))
	m.set_shader_parameter("wave", 0.0)
	_soup.material_override = m
	_soup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_soup.position.y = SOUP_START
	add_child(_soup)
	_floaters = MeshInstance3D.new()  # veg and bubbles riding the surface
	_floaters.mesh = Kit.part_mesh("game_bits", "floaters")
	_floaters.material_override = Art.vcol_mat()
	_floaters.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floaters.position.y = SOUP_START
	add_child(_floaters)
	water_y = SOUP_START
	# the chef, looming: a statue of whoever is running the kitchen
	var look: Dictionary = Net.profile(boss_id).duplicate()
	look.hat = "chef"
	var chef: Node3D = Art.build_character(look).root
	chef.position = Vector3(0, -2, -58)
	chef.rotation.y = PI
	chef.scale = Vector3.ONE * 26.0
	add_child(chef)
	b.absorb(self, [_soup, _floaters])
	b.commit(self)


## Food of any shape, with its top exactly at p.y, so every step is the same height.
func _platform(b: Batch, p: Vector3, food: Array) -> void:
	var id: String = food[0]
	var mesh: Mesh = Kit.part_mesh("game_bits", id.substr(5)) if id.begins_with("bits:") else Kit.mesh(id)
	var box := mesh.get_aabb()
	var sc := float(food[1])
	b.add(mesh, Dress.xf(p - Vector3.UP * box.end.y * sc, randf() * 360.0, sc))
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	body.position = p - Vector3.UP * 0.25
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = minf(box.size.x, box.size.z) * sc * 0.48
	sh.height = 0.5
	cs.shape = sh
	body.add_child(cs)


func mortal_spawn(index: int) -> Vector3:
	var a := index * 1.3
	return Vector3(cos(a) * 9.0, 0.5, sin(a) * 9.0)


func configure_mortal(av: Avatar) -> void:
	av.set_size(0.6)
	av.role = "little"
	av.base_speed = 7.0
	av.sprint_mult = 1.55
	av.jump_vel = 9.5
	base_config(av)
	if av.is_local():
		cam.distance = 3.8
		cam.height = 1.0


func game_begin() -> void:
	bot_pace = Vector2(5.0, 9.0)
	_bot_think = 16.0
	if Net.me() == boss_id:
		banner("YOU ARE THE CHEF\nnobody leaves your kitchen raw", 5.0)
	else:
		banner("YOU ARE A VEGETABLE\nthe floor is about to be soup. climb.", 5.0)
	allow_shove = true
	if multiplayer.is_server():
		time_left = 600.0
		extra = {"soup": soup_y, "heat": 0.0}
		for id: int in mortals():
			scores[id] = 0


func game_tick(delta: float) -> void:
	tick_powers(delta)
	heat_t = maxf(0.0, heat_t - delta)
	extra.soup = soup_y
	extra.heat = heat_t
	for id: int in mortals():
		if not _out_order.has(id):
			scores[id] = int(600.0 - time_left)
	_bots()
	var alive := alive_mortals()
	var solo := mortals().size() == 1
	if alive.is_empty():
		_end_all_cooked()
	elif not solo and alive.size() == 1:
		_veg_wins(alive[0])
	elif solo and 600.0 - time_left > SOLO_SURVIVE:
		_veg_wins(alive[0])


func on_time_up() -> void:
	_end_all_cooked()


func on_player_left(id: int) -> void:
	if id == boss_id:
		var alive := alive_mortals()
		if not alive.is_empty():
			_veg_wins(alive[0])


func _veg_wins(av: Avatar) -> void:
	var pays := {av.pid: [3, 90, 150], boss_id: [1, 40, 70]}
	var n := _out_order.size()
	for i in n:  # survived longer, paid better
		pays[_out_order[i]] = [1 if i > n / 2 else 0, 20 + i * 8, 50]
	finish("%s IS THE LAST VEGETABLE" % Net.pname(av.pid), [av.pid], pays)


func _end_all_cooked() -> void:
	var pays := {boss_id: [3, 90, 150]}
	finish("DINNER IS SERVED. THE CHEF WINS", [boss_id], pays)


## Owner reports the splash; the host decides who's out.
func on_avatar_fell(av: Avatar) -> void:
	Net.to_server(self, "req_cooked", [av.pid])


@rpc("any_peer", "reliable")
func req_cooked(pid: int) -> void:
	if not multiplayer.is_server() or over or _out_order.has(pid):
		return
	if Net.sender() != pid and not (Net.sender() == 1 and Net.is_bot(pid)):
		return
	_out_order.append(pid)
	_ev_cooked.rpc(pid)


@rpc("authority", "call_local", "reliable")
func _ev_cooked(pid: int) -> void:
	var av: Avatar = avatars.get(pid)
	if av:
		av.set_dead(true)
	toast("%s has been cooked" % Net.pname(pid))
	if pid == Net.me():
		banner("YOU ARE SOUP NOW", 3.0)


func respawn_for(_av: Avatar) -> Vector3:
	return Vector3(0, soup_y + 16.0, 0)


func cast(id: String, pos: Vector3) -> void:
	match id:
		"chop":
			strike(pos, 3.2, 0.8, 20.0)
		"taste":
			_ev_ladle.rpc(pos)
			strike(pos, 5.0, 1.4, 30.0)
		"stir":
			Net.announce("THE CHEF IS STIRRING")
			_stir()
		"salt":
			_ev_warn.rpc(pos, 8.0)
			await get_tree().create_timer(0.9).timeout
			if not is_inside_tree():
				return
			for av: Avatar in alive_mortals():
				if av.global_position.distance_to(pos) < 9.0:
					tricks.hex_on(av.pid, "salt", 4.0)
		"heat":
			heat_t = HEAT_SECS
			Net.announce("THE HEAT IS UP")


## A whirlpool shove around the pot, three pulses. Pushes, doesn't kill.
func _stir() -> void:
	for i in 3:
		for av: Avatar in alive_mortals():
			var p := Vector2(av.global_position.x, av.global_position.z)
			if p.length() > 2.0:
				var t := Vector2(-p.y, p.x).normalized()
				av.push.rpc(Vector3(t.x, 0.15, t.y) * 11.0)
		await get_tree().create_timer(0.7).timeout
		if not is_inside_tree():
			return


@rpc("authority", "call_local", "reliable")
func _ev_ladle(pos: Vector3) -> void:
	var l := Node3D.new()
	add_child(l)
	l.position = pos + Vector3.UP * 40.0
	var ladle := MeshInstance3D.new()
	ladle.mesh = Kit.part_mesh("game_bits", "ladle")
	ladle.material_override = Art.vcol_mat()
	l.add_child(ladle)
	var tw := l.create_tween()
	tw.tween_property(l, "position", pos + Vector3.UP * 1.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "position", pos + Vector3.UP * 44.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


func game_visuals(delta: float) -> void:
	if not active or over:
		return
	var hot := float(extra.get("heat", 0.0)) > 0.0
	_grace -= delta
	if _grace < 0.0:
		soup_y = minf(SOUP_MAX, soup_y + SOUP_RATE * (HEAT_MULT if hot else 1.0) * delta)
	if not multiplayer.is_server():  # drift back toward the host's level
		soup_y = lerpf(soup_y, float(extra.get("soup", soup_y)), clampf(delta * 2.0, 0.0, 1.0))
	_soup.position.y = soup_y
	water_y = soup_y
	var t := Time.get_ticks_msec() * 0.001
	_floaters.position.y = soup_y + 0.04 + sin(t * 1.3) * 0.05
	_floaters.rotation.y = t * 0.015  # the soup turns, slowly


func info_text() -> String:
	if Net.me() == boss_id:
		return boss_info()
	return "shove people in. the only way out is up."


func board_lines() -> PackedStringArray:
	return PackedStringArray(["CHEF: %s" % Net.pname(boss_id), "VEG LEFT: %d" % alive_mortals().size(), "SOUP: %.0f m" % maxf(0.0, soup_y)])


## Bots hop up the guaranteed spiral, one step ahead of the soup. They walk the
## last few metres so a jump lands on the food instead of sailing past it.
func _bots() -> void:
	for av: Avatar in alive_mortals():
		if not av.is_bot:
			continue
		var idx: int = _brain.get(av.pid, 0)
		var goal: Vector3 = _climb[mini(idx, _climb.size() - 1)]
		if av.global_position.y < -1.0:  # fell: back onto the toast
			goal = Vector3(0, -0.7, 0)
			_brain[av.pid] = 0
		elif av.global_position.y < goal.y - 2.8:
			_brain[av.pid] = maxi(0, idx - 2)
		var to := goal - av.global_position
		var flat := Vector3(to.x, 0, to.z)
		var d := flat.length()
		if d < 1.8 and av.global_position.y > goal.y - 0.3:
			_brain[av.pid] = idx + 1
		av.bot_sprint = false
		av.bot_move = flat.normalized() if d > 0.5 else Vector3.ZERO
		if not av.is_on_floor():
			av.bot_move = Vector3.ZERO  # committed to the jump: let it land
			continue
		var fallen := av.global_position.y < -1.0
		if (d < 6.5 and d > 1.0 and to.y > -0.5) or (fallen and d < 15.5):
			# a bot can't judge a jump, so it computes one from the real arc
			var v := av.jump_vel
			var apex := v * v / (2.0 * Avatar.GRAVITY)
			var air := v / Avatar.GRAVITY + sqrt(2.0 * maxf(apex - to.y, 0.05) / (Avatar.GRAVITY * Avatar.FALL_MULT))
			var step := flat / air if not fallen else flat.normalized() * 7.0
			av.velocity.x = step.limit_length(BOT_LEAP).x
			av.velocity.z = step.limit_length(BOT_LEAP).z
			av.bot_jump = true
