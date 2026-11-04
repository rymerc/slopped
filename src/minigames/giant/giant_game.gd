class_name GiantGame
extends WorldBase
## GIANT HUNT: one big slow giant vs. many small fast littles.
##   Littles: throw spears at his eyes (LMB), plant rope stakes (RMB twice) to
##            make tripwires, and TIE HIM UP (E) while he's on the ground.
##   Giant:   stomp (LMB), hand slap (RMB, 8s), ice pee (Q, 20s), fire fart (F, 30s).
## This node renders state; GiantRules (child "Rules") decides everything.

const SPEAR_SPEED := 28.0
const SPEAR_GRAVITY := 12.0

var giant_id := 0
var littles: Array = []
var modifier := "none"
var eye_max := 3
var racks: Array[Vector3] = []
var rules: GiantRules
var bots: GiantBots

# Replicated state (written by _ev_* RPCs from the host)
var time_left := 0.0
var eye_hp: Array = [3, 3]
var bind := 0.0
var tripped := 0.0
var spears: Dictionary = {}
var cds: Dictionary = {}
var ices: Array = []  # {pos, r, until}
var over := false

var _ropes: Dictionary = {}
var _stakes: Dictionary = {}
var _spears: Dictionary = {}
var _throw_cd := 0.0


static func ballistic(origin: Vector3, target: Vector3, speed: float, g: float) -> Vector3:
	var d := target - origin
	var t := clampf(d.length() / speed, 0.05, 2.0)
	return d / t + Vector3.UP * 0.5 * g * t


func build_world() -> void:
	giant_id = int(args.get("giant", 1))
	littles = args.get("littles", [])
	modifier = str(args.get("modifier", "none"))
	eye_max = 1 if modifier == "glass_eyes" else 3
	eye_hp = [eye_max, eye_max]
	seed(int(args.get("seed", 0)))
	make_environment(Color("#5fb8ff"), Color("#d8f3ff"), 0.6, 1.3)
	racks = GiantArena.build(self)
	randomize()
	rules = GiantRules.new()
	rules.name = "Rules"
	rules.game = self
	add_child(rules)
	bots = GiantBots.new()
	bots.name = "Bots"
	bots.game = self
	add_child(bots)
	var gh := GiantHud.new()
	gh.game = self
	hud.add_child(gh)
	add_interact(_tie_point, 99.0, "TIE HIM UP!", _tie, _can_tie)


func world_started() -> void:
	var mod: Dictionary = PerkDB.modifier(modifier)
	var me := Net.me()
	if me == giant_id:
		banner("YOU ARE THE GIANT\ncrush the little freaks\n[%s]" % mod.name, 5.0)
	elif littles.has(me):
		banner("YOU ARE LITTLE\nspear his eyes, trip him, TIE HIM UP\n[%s]" % mod.name, 5.0)
	else:
		banner("spectating (ghost)", 3.0)
	rules.begin()


func giant_av() -> Avatar:
	return avatars.get(giant_id)


## Distance from p to the giant's body (standing: a point, fallen: a line).
func dist_to_giant_body(p: Vector3) -> float:
	var g := giant_av()
	if g == null:
		return INF
	var a := g.global_position
	var b := a + g.forward() * (1.7 * g.size if g.fallen else 0.0)
	return GiantRules._seg_dist_xz(p, a, b)


func spawn_for(av: Avatar, index: int) -> Vector3:
	if av.pid == giant_id:
		return Vector3(0, 1, 0)
	var a := index * 1.3
	return Vector3(cos(a) * 32.0, 0.5, sin(a) * 32.0)


func configure_avatar(av: Avatar) -> void:
	var perks := Net.perks_of(av.pid)
	var s := 0.6
	if av.pid == giant_id:
		av.role = "giant"
		s = 4.0
		av.base_speed = 4.6
		if modifier == "tiny_giant":
			s = 2.6
			av.base_speed = 5.6
		elif modifier == "mega_giant":
			s = 5.5
			av.base_speed = 3.9
		av.sprint_mult = 1.15
		av.jump_vel = 6.0
		av.face_camera = true
	else:
		av.role = "little"
		av.base_speed = 7.0
		av.sprint_mult = 1.55
		av.jump_vel = 9.0
	av.set_size(s)
	av.speed_mult = PerkDB.speed_mult(perks) * (1.3 if modifier == "zoomies" else 1.0)
	av.jump_vel *= PerkDB.jump_mult(perks)
	av.gravity_mult = 0.45 if modifier == "low_gravity" else 1.0
	av.set_head_scale(2.0 if modifier == "big_heads" else 1.0)
	av.set_glow(perks.has("glow_stick"))
	if av.pid != giant_id and not littles.has(av.pid) and not av.dead:
		av.set_dead(true)  # late joiner: spectate
	if av.is_local():
		cam.distance = 13.0 * s / 4.0 if av.role == "giant" else 3.8
		cam.height = 6.0 * s / 4.0 if av.role == "giant" else 1.0


# --- local input -----------------------------------------------------------------

func world_input(event: InputEvent) -> void:
	var me := local_avatar()
	if me == null or me.dead or over:
		return
	if me.pid == giant_id:
		for pair: Array in [["primary", "stomp"], ["secondary", "slap"], ["ability_1", "pee"], ["ability_2", "fart"]]:
			if event.is_action_pressed(pair[0]):
				Net.to_server(rules, "req_ability", [pair[1]])
	elif event.is_action_pressed("primary"):
		_throw(me)
	elif event.is_action_pressed("secondary"):
		Net.to_server(rules, "req_stake")


func _throw(me: Avatar) -> void:
	if _throw_cd > 0.0 or int(spears.get(me.pid, 0)) <= 0:
		return
	_throw_cd = 0.35
	var skip: Array[RID] = [me.get_rid()]
	var origin := me.global_position + Vector3.UP * 1.1 * me.size + cam.aim_dir() * 0.4
	var vel := ballistic(origin, cam.aim_point(skip), SPEAR_SPEED, SPEAR_GRAVITY)
	Net.to_server(rules, "req_throw", [origin, vel])


func _tie_point() -> Vector3:
	var g := giant_av()
	if g == null:
		return Vector3(0, -999, 0)
	var me := local_avatar()
	var a := g.global_position
	var b := a + g.forward() * 1.7 * g.size
	if me == null:
		return a
	return Geometry3D.get_closest_point_to_segment(Vector3(me.global_position.x, a.y, me.global_position.z), a, b)


func _can_tie() -> bool:
	var me := local_avatar()
	var g := giant_av()
	return tripped > 0.0 and me != null and g != null and me.pid != giant_id \
		and dist_to_giant_body(me.global_position) < 0.5 * g.size + 1.6


func _tie() -> void:
	Net.to_server(rules, "req_tie")


func world_process(delta: float) -> void:
	_throw_cd -= delta


func world_physics(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	ices = ices.filter(func(i: Dictionary) -> bool: return int(i.until) > now)
	for av: Avatar in avatars.values():
		if av.controls():
			av.slippery = modifier == "slippery" or _on_ice(av.global_position)


func _on_ice(p: Vector3) -> bool:
	for i: Dictionary in ices:
		if GiantRules._flat_dist(p, i.pos) < float(i.r) and p.y < float((i.pos as Vector3).y) + 1.0:
			return true
	return false


# --- host -> everyone events ----------------------------------------------------

@rpc("authority", "call_local", "unreliable_ordered")
func _ev_state(t: float, eyes: Array, b: float, tr: float, sp: Dictionary, cd: Dictionary) -> void:
	time_left = t
	eye_hp = eyes
	bind = b
	tripped = tr
	spears = sp
	cds = cd


@rpc("authority", "call_local", "reliable")
func _ev_spear(sid: int, pos: Vector3, vel: Vector3) -> void:
	var s := Spear.new()
	s.vel = vel
	s.gravity = SPEAR_GRAVITY
	add_child(s)
	s.position = pos
	_spears[sid] = s


@rpc("authority", "call_local", "reliable")
func _ev_spear_end(sid: int, pos: Vector3) -> void:
	var s: Spear = _spears.get(sid)
	_spears.erase(sid)
	if is_instance_valid(s):
		s.stick(pos)


@rpc("authority", "call_local", "reliable")
func _ev_stake(owner_id: int, pos: Vector3, on: bool) -> void:
	if _stakes.has(owner_id):
		(_stakes[owner_id] as Node3D).queue_free()
		_stakes.erase(owner_id)
	if on:
		var n := Node3D.new()
		add_child(n)
		n.position = pos
		Art.part(n, Art.cyl(0.07, 0.1, 1.0, 6), Art.WOOD, Vector3(0, 0.5, 0))
		Art.part(n, Art.sphere(0.14, 6), Ui.YELLOW, Vector3(0, 1.05, 0), Vector3.ONE, Vector3.ZERO, true, 0.8)
		_stakes[owner_id] = n
		if owner_id == Net.me():
			toast("Stake planted. Run 3-16m and plant the other end (RMB).")


@rpc("authority", "call_local", "reliable")
func _ev_rope(rid: int, a: Vector3, b: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	for p: Vector3 in [a, b]:
		Art.part(n, Art.cyl(0.07, 0.1, 1.0, 6), Art.WOOD, p + Vector3(0, 0.5, 0))
	Art.beam(n, a + Vector3.UP * 0.55, b + Vector3.UP * 0.55, 0.045, Color("#f4e1b0"))
	_ropes[rid] = n


@rpc("authority", "call_local", "reliable")
func _ev_rope_cut(rid: int) -> void:
	if _ropes.has(rid):
		(_ropes[rid] as Node3D).queue_free()
		_ropes.erase(rid)


@rpc("authority", "call_local", "reliable")
func _ev_trip(on: bool) -> void:
	var g := giant_av()
	if g == null:
		return
	g.fallen = on
	if on:
		tripped = 1.0
		banner("TIMBERRR!\nTIE HIM UP!", 2.0)
		cam.shake(1.2 if local_avatar() and local_avatar().pid == giant_id else 0.6)
		GiantFx.dust(self, g.global_position + g.forward() * g.size, 2.0 * g.size)
	else:
		tripped = 0.0


@rpc("authority", "call_local", "reliable")
func _ev_eye(idx: int, hp: int) -> void:
	eye_hp[idx] = hp
	var g := giant_av()
	if g == null:
		return
	var eye := (g.parts.eyes as Array)[idx] as Node3D
	GiantFx.burst(self, eye.global_position, Color("#e63946"))
	if hp <= 0:
		Art.part(eye, Art.box(Vector3(0.3, 0.06, 0.06)), Art.INK, Vector3(0, 0, -0.1), Vector3.ONE, Vector3(0, 0, 45), false)
		Art.part(eye, Art.box(Vector3(0.3, 0.06, 0.06)), Art.INK, Vector3(0, 0, -0.1), Vector3.ONE, Vector3(0, 0, -45), false)
		if Net.me() == giant_id:
			banner("YOUR %s EYE IS GONE" % ("LEFT" if idx == 0 else "RIGHT"), 2.0)


@rpc("authority", "call_local", "reliable")
func _ev_ice(pos: Vector3, r: float, dur: float) -> void:
	ices.append({"pos": pos, "r": r, "until": Time.get_ticks_msec() + int(dur * 1000.0)})
	GiantFx.ice(self, pos, r, dur)


@rpc("authority", "call_local", "reliable")
func _ev_fx(kind: String, pos: Vector3, yaw: float, r: float) -> void:
	var me := local_avatar()
	var near := me != null and me.global_position.distance_to(pos) < 20.0
	match kind:
		"warn": GiantFx.warn(self, pos, r)
		"stomp":
			GiantFx.dust(self, pos, r)
			if near: cam.shake(0.6)
		"slap":
			GiantFx.slap(self, pos, r)
			if near: cam.shake(1.0)
		"pee": GiantFx.pee(self, pos, yaw, r)
		"rumble": GiantFx.text(self, pos + Vector3.UP * 3.0 * r, "*rumble*", Color("#ff7a3d"))
		"fart":
			GiantFx.fart(self, pos, yaw, r)
			if near: cam.shake(0.8)
		"tie": GiantFx.burst(self, pos + Vector3.UP * 0.5, Color("#f4e1b0"))
		"struggle": GiantFx.text(self, pos + Vector3.UP * 2.0, "*struggle*", Color.WHITE)
		"shield": GiantFx.burst(self, pos + Vector3.UP, Color.WHITE)


@rpc("authority", "call_local", "reliable")
func _ev_kill(id: int, cause: String) -> void:
	var av: Avatar = avatars.get(id)
	if av:
		GiantFx.burst(self, av.global_position + Vector3.UP * 0.5, Color("#ff5fa2"))
		av.set_dead(true)
	toast("%s %s" % [Net.pname(id), cause])
	if id == Net.me():
		banner("YOU DIED\n(you're a ghost now: SPACE/SHIFT to fly)", 3.0)


@rpc("authority", "call_local", "reliable")
func _ev_over(side: String, msg: String) -> void:
	over = true
	var me := Net.me()
	var won := (side == "giant") == (me == giant_id)
	banner("%s\n%s" % [msg, "YOU WIN" if won else "you lose lol"], 7.0)
