class_name GiantBots
extends Node
## Host-side bot brains for GIANT HUNT so you can test solo.
## Dumb on purpose: steering vectors, no pathfinding.

var game: GiantGame
var _brain: Dictionary = {}


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or game.rules == null or not game.rules.active or game.rules.over:
		for av: Avatar in game.avatars.values():
			if av.is_bot:
				av.bot_move = Vector3.ZERO
		return
	var gav := game.giant_av()
	if gav == null:
		return
	for av: Avatar in game.avatars.values():
		if not av.is_bot:
			continue
		if av.dead:
			av.bot_move = Vector3.ZERO
			continue
		if not _brain.has(av.pid):
			_brain[av.pid] = {"throw": randf_range(1, 3), "stake": randf_range(3, 8), "second": 0.0,
				"act": 0.0, "side": 1.0 if randf() < 0.5 else -1.0, "stuck": 0.0}
		var b: Dictionary = _brain[av.pid]
		if av.pid == game.giant_id:
			_giant(av, b, delta)
		else:
			_little(av, gav, b, delta)
		_unstick(av, b, delta)


func _little(av: Avatar, gav: Avatar, b: Dictionary, delta: float) -> void:
	var r := game.rules
	b.throw = float(b.throw) - delta
	b.stake = float(b.stake) - delta
	var to_g := gav.global_position - av.global_position
	to_g.y = 0.0
	var dist := to_g.length()
	var dir := to_g / maxf(dist, 0.01)
	var move := Vector3.ZERO
	av.bot_sprint = false

	if float(b.second) > 0.0:
		b.second = float(b.second) - delta
		if float(b.second) <= 0.0:
			r.do_stake(av.pid)

	if r.tripped > 0.0 and dist < 30.0:
		if game.dist_to_giant_body(av.global_position) > 0.5 * gav.size + 1.2:
			var body := gav.global_position + gav.forward() * 0.85 * gav.size
			move = _flat(body - av.global_position).normalized()
			av.bot_sprint = true
		else:
			r.do_tie(av.pid)
	elif int(r.spears.get(av.pid, 0)) <= 0:
		var rack := _nearest(av.global_position, game.racks)
		move = _flat(rack - av.global_position).normalized()
		if dist < 10.0:
			move = (move - dir * 1.2).normalized()
		av.bot_sprint = true
	else:
		var tangent := Vector3(-dir.z, 0, dir.x) * float(b.side)
		if dist < 9.0:
			move = (-dir * 1.2 + tangent * 0.5).normalized()
			av.bot_sprint = true
		elif dist > 17.0:
			move = (dir + tangent * 0.4).normalized()
		else:
			move = tangent
		if float(b.throw) <= 0.0 and dist > 5.0 and dist < 24.0:
			b.throw = randf_range(1.8, 3.5)
			_throw_at_eye(av, gav)
		if float(b.stake) <= 0.0 and dist < 15.0:
			b.stake = randf_range(6.0, 10.0)
			r.do_stake(av.pid)
			b.second = 0.9  # run sideways, then plant the other end
			b.side = -float(b.side) if randf() < 0.3 else float(b.side)
	av.bot_move = move


func _throw_at_eye(av: Avatar, gav: Avatar) -> void:
	var eyes: Array = gav.parts.get("eyes", [])
	if eyes.is_empty():
		return
	var i := randi() % 2
	if int(game.rules.eye_hp[i]) <= 0:
		i = 1 - i
	var jitter := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * 0.8
	var target: Vector3 = (eyes[i] as Node3D).global_position + jitter
	var origin := av.global_position + Vector3.UP * 0.9
	game.rules.do_throw(av.pid, origin, GiantGame.ballistic(origin, target, GiantGame.SPEAR_SPEED, GiantGame.SPEAR_GRAVITY))


func _giant(av: Avatar, b: Dictionary, delta: float) -> void:
	var r := game.rules
	b.act = float(b.act) - delta
	if r.tripped > 0.0:
		av.bot_move = Vector3.ZERO
		if float(b.act) <= 0.0:
			b.act = 0.25
			r.do_ability(av.pid, "stomp")
		return
	var target: Avatar = null
	var best := INF
	var near_front := 0
	var near_back := 0
	var sf := av.size / 4.0
	for other: Avatar in game.avatars.values():
		if other == av or other.dead or not r.alive.get(other.pid, false):
			continue
		var to := _flat(other.global_position - av.global_position)
		var d := to.length()
		if d < best:
			best = d
			target = other
		if d < 7.0 * sf:
			if av.forward().dot(to.normalized()) > 0.3:
				near_front += 1
			elif av.forward().dot(to.normalized()) < -0.5:
				near_back += 1
	if target == null:
		av.bot_move = Vector3.ZERO
		return
	av.bot_move = _flat(target.global_position - av.global_position).normalized()
	av.bot_sprint = true
	if float(b.act) > 0.0:
		return
	b.act = 0.5
	if near_back >= 1 and randf() < 0.5:
		r.do_ability(av.pid, "fart")
	elif near_front >= 2:
		r.do_ability(av.pid, "slap")
	elif best < 3.6 * sf:
		r.do_ability(av.pid, "stomp")
	elif best < 9.0 * sf and randf() < 0.1:
		r.do_ability(av.pid, "pee")


## If a bot is pushing but not moving (tree, wall), jump and change direction.
func _unstick(av: Avatar, b: Dictionary, delta: float) -> void:
	var moving := Vector2(av.net_velocity.x, av.net_velocity.z).length() > 0.5
	if av.bot_move.length() > 0.1 and not moving:
		b.stuck = float(b.stuck) + delta
		if float(b.stuck) > 0.6:
			b.stuck = 0.0
			b.side = -float(b.side)
			av.bot_jump = true
			av.bot_move = av.bot_move.rotated(Vector3.UP, PI * 0.5 * float(b.side))
	else:
		b.stuck = 0.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _nearest(p: Vector3, pts: Array[Vector3]) -> Vector3:
	var best := pts[0]
	for q in pts:
		if p.distance_squared_to(q) < p.distance_squared_to(best):
			best = q
	return best
