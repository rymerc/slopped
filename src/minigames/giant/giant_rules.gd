class_name GiantRules
extends Node
## Host-only game logic for GIANT HUNT. Clients call req_* (or bots call do_*
## directly); results are broadcast through GiantGame._ev_* RPCs.
##
## Littles win: fill the BIND meter by tying up the giant while he's tripped.
## Giant wins: flatten every little, or survive the clock.

const CD := {"stomp": 1.4, "slap": 8.0, "pee": 20.0, "fart": 30.0}
const BASE_SPEARS := 3
const TRIP_TIME := 3.5
const TRIP_PER_BLIND_EYE := 1.25
const TRIP_EXTEND_MAX := 1.5
const TIE_BUDGET := 13.0  # bind per tie = TIE_BUDGET / starting littles (team-size fair)
const TIE_COOLDOWN := 1.0
const BIND_DECAY := 1.0
const ROPES_PER_LITTLE := 2
const ROPE_MIN := 2.5
const ROPE_MAX := 16.0
const RACK_RADIUS := 2.6

var game: GiantGame
var active := false
var over := false
var time_left := 300.0
var eye_hp: Array = [3, 3]
var bind := 0.0
var tripped := 0.0
var cds := {"stomp": 0.0, "slap": 0.0, "pee": 0.0, "fart": 0.0}
var spears := {}  # little id -> count
var alive := {}  # little id -> bool

var _trip_ext := 0.0
var _trip_immune := 0.0
var _shields := {}
var _tie_cd := {}
var _ropes := {}  # rid -> {a, b, owner}
var _pending := {}  # owner -> Vector3 (first stake)
var _flying := {}  # sid -> {pos, vel, owner, t}
var _rope_seq := 0
var _spear_seq := 0
var _sync_t := 0.0
var _team_size := 1


func begin() -> void:
	if not multiplayer.is_server():
		return
	eye_hp = [game.eye_max, game.eye_max]
	for id: int in game.littles:
		if Net.players.has(id):
			alive[id] = true
			spears[id] = max_spears(id)
			_shields[id] = PerkDB.count(Net.perks_of(id), "thick_skull")
	_team_size = maxi(1, alive.size())
	time_left = clampf(150.0 + 45.0 * alive.size(), 240.0, 600.0)
	Net.peer_left.connect(_on_left)
	active = true


func max_spears(id: int) -> int:
	return BASE_SPEARS + PerkDB.extra_spears(Net.perks_of(id))


func blind_count() -> int:
	return int(eye_hp[0] <= 0) + int(eye_hp[1] <= 0)


func alive_count() -> int:
	return alive.values().count(true)


# --- client requests ---------------------------------------------------------

@rpc("any_peer", "reliable")
func req_throw(origin: Vector3, vel: Vector3) -> void:
	do_throw(Net.sender(), origin, vel)


@rpc("any_peer", "reliable")
func req_stake() -> void:
	do_stake(Net.sender())


@rpc("any_peer", "reliable")
func req_tie() -> void:
	do_tie(Net.sender())


@rpc("any_peer", "reliable")
func req_ability(kind: String) -> void:
	do_ability(Net.sender(), kind)


# --- actions -------------------------------------------------------------------

func do_throw(id: int, origin: Vector3, vel: Vector3) -> void:
	if not _can_little(id) or int(spears.get(id, 0)) <= 0:
		return
	var av: Avatar = game.avatars[id]
	if origin.distance_to(av.global_position) > 3.0:
		origin = av.global_position + Vector3.UP
	vel = vel.limit_length(45.0) * PerkDB.throw_mult(Net.perks_of(id))
	spears[id] = int(spears[id]) - 1
	_spear_seq += 1
	_flying[_spear_seq] = {"pos": origin, "vel": vel, "owner": id, "t": 0.0}
	game._ev_spear.rpc(_spear_seq, origin, vel)


func do_stake(id: int) -> void:
	if not _can_little(id):
		return
	var pos: Vector3 = (game.avatars[id] as Avatar).global_position
	pos.y = 0.0
	if not _pending.has(id):
		_pending[id] = pos
		game._ev_stake.rpc(id, pos, true)
		return
	var a: Vector3 = _pending[id]
	var dist := Vector2(a.x - pos.x, a.z - pos.z).length()
	if dist < ROPE_MIN:
		return
	_pending.erase(id)
	game._ev_stake.rpc(id, a, false)
	if dist > ROPE_MAX:  # too far: restart from here
		_pending[id] = pos
		game._ev_stake.rpc(id, pos, true)
		return
	var mine: Array = _ropes.keys().filter(func(r: int) -> bool: return _ropes[r].owner == id)
	if mine.size() >= ROPES_PER_LITTLE:
		_cut(mine.min())
	_rope_seq += 1
	_ropes[_rope_seq] = {"a": a, "b": pos, "owner": id}
	game._ev_rope.rpc(_rope_seq, a, pos)


func do_tie(id: int) -> void:
	if not _can_little(id) or tripped <= 0.0 or float(_tie_cd.get(id, 0.0)) > 0.0:
		return
	var av: Avatar = game.avatars[id]
	var gav := game.giant_av()
	if game.dist_to_giant_body(av.global_position) > 0.5 * gav.size + 1.6:
		return
	_tie_cd[id] = TIE_COOLDOWN
	var per_tie := TIE_BUDGET / maxf(1.0, float(_team_size))
	bind = minf(100.0, bind + per_tie * PerkDB.tie_mult(Net.perks_of(id)))
	Net.award(id, 8, "Tied the giant")
	if _trip_ext < TRIP_EXTEND_MAX:
		tripped += 0.15
		_trip_ext += 0.15
		gav.stun.rpc(tripped)
	game._ev_fx.rpc("tie", av.global_position, 0.0, 1.0)


func do_ability(id: int, kind: String) -> void:
	if id != game.giant_id or not active or over:
		return
	var gav := game.giant_av()
	if gav == null:
		return
	if tripped > 0.0:
		if kind == "stomp":  # mash to struggle free
			tripped = maxf(0.05, tripped - 0.18)
			game._ev_fx.rpc("struggle", gav.global_position, 0.0, gav.size)
		return
	if not CD.has(kind) or float(cds[kind]) > 0.0:
		return
	var mult := PerkDB.cooldown_mult(Net.perks_of(id)) * (0.8 if game.modifier == "mega_giant" else 1.0)
	cds[kind] = float(CD[kind]) * mult
	var sf := gav.size / 4.0
	match kind:
		"stomp":
			_stomp(gav.global_position + gav.forward() * 2.4 * sf, 2.6 * sf)
		"slap":
			_slap(gav.global_position + gav.forward() * 4.5 * sf, 4.2 * sf)
		"pee":
			var p := gav.global_position + gav.forward() * 4.0 * sf
			game._ev_fx.rpc("pee", gav.global_position, gav.facing, sf)
			game._ev_ice.rpc(p, 5.0 * sf, 25.0)
		"fart":
			_fart(gav, sf)


func _stomp(pos: Vector3, r: float) -> void:
	game._ev_fx.rpc("warn", pos, 0.0, r)
	await get_tree().create_timer(0.3).timeout
	if over:
		return
	game._ev_fx.rpc("stomp", pos, 0.0, r)
	game.props.blast(pos, r * 1.8, 9.0)
	for id: int in alive.keys():
		var av: Avatar = game.avatars.get(id)
		if av == null:
			continue
		var fd := _flat_dist(av.global_position, pos)
		if fd < r and av.global_position.y - pos.y < 0.9:
			kill(id, "got pancaked")
		elif fd < r * 1.7:  # near miss: shockwave wobble
			var away := av.global_position - pos
			av.push.rpc(Vector3(away.x, 0, away.z).normalized() * 5.0 + Vector3.UP * 3.0)
	for rid: int in _ropes.keys():
		var rp: Dictionary = _ropes[rid]
		if _seg_dist_xz(pos, rp.a, rp.b) < r:
			_cut(rid)


func _slap(pos: Vector3, r: float) -> void:
	game._ev_fx.rpc("warn", pos, 0.0, r)
	await get_tree().create_timer(0.6).timeout
	if over:
		return
	game._ev_fx.rpc("slap", pos, 0.0, r)
	game.props.blast(pos, r * 2.2, 16.0)
	for id: int in alive.keys():
		var av: Avatar = game.avatars.get(id)
		if av == null:
			continue
		var d := _flat_dist(av.global_position, pos)
		if d < r:
			kill(id, "got slapped into next week")
		elif d < r * 2.0:
			var away := av.global_position - pos
			av.push.rpc(Vector3(away.x, 0, away.z).normalized() * 10.0 + Vector3.UP * 7.0)


func _fart(gav: Avatar, sf: float) -> void:
	game._ev_fx.rpc("rumble", gav.global_position, gav.facing, sf)
	await get_tree().create_timer(0.45).timeout
	if over or not is_instance_valid(gav):
		return
	var back := -gav.forward()
	game._ev_fx.rpc("fart", gav.global_position, gav.facing, sf)
	game.props.blast(gav.global_position + back * 4.0 * sf, 8.0 * sf, 14.0)
	for id: int in alive.keys():
		var av: Avatar = game.avatars.get(id)
		if av == null:
			continue
		var to := av.global_position - gav.global_position
		to.y = 0.0
		if to.length() < 10.0 * sf and to.length() > 0.01 and rad_to_deg(back.angle_to(to)) < 55.0:
			kill(id, "was cremated by a fart")


func kill(id: int, cause: String) -> void:
	if not alive.get(id, false):
		return
	var av: Avatar = game.avatars.get(id)
	if int(_shields.get(id, 0)) > 0:
		_shields[id] = int(_shields[id]) - 1
		if av:
			av.push.rpc(Vector3.UP * 12.0)
			game._ev_fx.rpc("shield", av.global_position, 0.0, 1.0)
		Net.announce("%s's Thick Skull tanked it!" % Net.pname(id))
		return
	alive[id] = false
	_pending.erase(id)
	game._ev_kill.rpc(id, cause)
	Net.award(game.giant_id, 25, "Flattened %s" % Net.pname(id))


# --- tick --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not active or over:
		return
	var gav := game.giant_av()
	if gav == null:
		_end("littles", "The giant vanished. LITTLES WIN by default.")
		return
	time_left -= delta
	for k: String in cds:
		cds[k] = maxf(0.0, float(cds[k]) - delta)
	for k: int in _tie_cd:
		_tie_cd[k] = float(_tie_cd[k]) - delta
	_trip_immune -= delta
	if tripped > 0.0:
		tripped -= delta
		if tripped <= 0.0:
			_getup(gav)
	else:
		bind = maxf(0.0, bind - BIND_DECAY * delta)
		_check_trip(gav)
	_sim_spears(delta, gav)
	_refill()
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.2
		game._ev_state.rpc(time_left, eye_hp, bind, tripped, spears, cds)
	if bind >= 100.0:
		_end("littles", "%s got HOG-TIED! LITTLES WIN" % Net.pname(game.giant_id))
	elif alive_count() == 0:
		_end("giant", "Everyone got flattened. GIANT WINS")
	elif time_left <= 0.0:
		_end("giant", "Time's up. The giant survives. GIANT WINS")


func _check_trip(gav: Avatar) -> void:
	if _trip_immune > 0.0:
		return
	if Vector2(gav.net_velocity.x, gav.net_velocity.z).length() < 0.6:
		return
	for rid: int in _ropes:
		var r: Dictionary = _ropes[rid]
		if _seg_dist_xz(gav.global_position, r.a, r.b) < 0.5 * gav.size:
			var owner_id: int = r.owner
			_cut(rid)
			tripped = TRIP_TIME + TRIP_PER_BLIND_EYE * blind_count()
			_trip_ext = 0.0
			gav.stun.rpc(tripped + 0.1)
			game._ev_trip.rpc(true)
			Net.announce("%s TRIPPED on %s's rope! TIE HIM UP!" % [Net.pname(game.giant_id), Net.pname(owner_id)])
			return


func _getup(gav: Avatar) -> void:
	tripped = 0.0
	_trip_immune = 2.5
	gav.stun.rpc(0.0)
	game._ev_trip.rpc(false)


func _sim_spears(delta: float, gav: Avatar) -> void:
	var space := game.get_world_3d().direct_space_state
	var eyes: Array = gav.parts.get("eyes", [])
	var gp := gav.global_position
	for sid: int in _flying.keys():
		var s: Dictionary = _flying[sid]
		var old: Vector3 = s.pos
		var v: Vector3 = s.vel
		v.y -= GiantGame.SPEAR_GRAVITY * delta
		var np := old + v * delta
		s.vel = v
		s.pos = np
		s.t = float(s.t) + delta
		var hit := false
		for i in eyes.size():
			if int(eye_hp[i]) <= 0:
				continue
			var ep: Vector3 = (eyes[i] as Node3D).global_position
			if _seg_point_dist(old, np, ep) < 0.24 * gav.size * gav.head_scale:
				_eye_hit(i, int(s.owner))
				hit = true
				break
		if not hit:
			var axis_a := gp + Vector3.UP * 0.4 * gav.size
			var axis_b := gp + Vector3.UP * 0.95 * gav.size
			if _seg_point_dist(axis_a, axis_b, np) < 0.45 * gav.size and not gav.fallen:
				hit = true
		if not hit:
			var q := PhysicsRayQueryParameters3D.create(old, np, 1)
			var r := space.intersect_ray(q)
			if r:
				np = r.position
				hit = true
		if hit or float(s.t) > 5.0 or np.y < -5.0:
			_flying.erase(sid)
			game._ev_spear_end.rpc(sid, np)


func _eye_hit(i: int, owner_id: int) -> void:
	eye_hp[i] = int(eye_hp[i]) - 1
	game._ev_eye.rpc(i, int(eye_hp[i]))
	Net.award(owner_id, 10, "Spear to the eye")
	if int(eye_hp[i]) <= 0:
		Net.award(owner_id, 30, "Blinded the giant")
		Net.give_coins(owner_id, 15)
		Net.announce("%s BLINDED the giant's %s eye!" % [Net.pname(owner_id), "LEFT" if i == 0 else "RIGHT"])


func _refill() -> void:
	for id: int in alive:
		if not alive[id] or int(spears.get(id, 0)) >= max_spears(id):
			continue
		var av: Avatar = game.avatars.get(id)
		if av == null:
			continue
		for rack: Vector3 in game.racks:
			if _flat_dist(av.global_position, rack) < RACK_RADIUS:
				spears[id] = max_spears(id)
				break


func _cut(rid: int) -> void:
	if _ropes.erase(rid):
		game._ev_rope_cut.rpc(rid)


func _can_little(id: int) -> bool:
	return active and not over and bool(alive.get(id, false)) and game.avatars.has(id)


func _on_left(id: int) -> void:
	if over:
		return
	if id == game.giant_id:
		_end("littles", "The giant rage-quit. LITTLES WIN")
	else:
		alive.erase(id)


func _end(side: String, msg: String) -> void:
	if over:
		return
	over = true
	game._ev_over.rpc(side, msg)
	var g := game.giant_id
	for id: int in game.littles:
		if not Net.players.has(id):
			continue
		var p: Dictionary = Net.players[id]
		if side == "littles":
			var survived: bool = alive.get(id, false)
			p.score = int(p.score) + (2 if survived else 1)
			Net.reward(id, 60 if survived else 40)
			Net.award(id, 120 if survived else 90, "Littles win!", "giant_win")
		else:
			Net.reward(id, 15)
			Net.award(id, 40, "Good effort")
		p.perks = []
	if Net.players.has(g):
		var gp: Dictionary = Net.players[g]
		if side == "giant":
			gp.score = int(gp.score) + 3
			Net.reward(g, 80)
			Net.award(g, 150, "Giant wins!", "giant_win")
		else:
			Net.reward(g, 15)
			Net.award(g, 40, "Good effort")
		gp.perks = []
	Net.broadcast()
	await get_tree().create_timer(7.0).timeout
	Net.request_world("lobby", {})


# --- geometry ----------------------------------------------------------------------

static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _seg_dist_xz(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	return p2.distance_to(Geometry2D.get_closest_point_to_segment(p2, a2, b2))


static func _seg_point_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	return p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))
