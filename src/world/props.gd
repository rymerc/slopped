class_name PropSystem
extends Node3D
## Owns every Prop in a world. Props are spawned in the same order on every
## peer (deterministic builders), so a prop's index is its network id.
##   Host:    simulates rigid bodies, decides grabs/throws/hits/explosions,
##            streams transforms (moved props at 20 Hz + full snapshot every 2 s).
##   Clients: kinematic copies that interpolate; held props attach locally to
##            the holder so carrying looks lag-free for everyone.

const SYNC_DT := 0.05
const FULL_DT := 2.0
const HIT_SPEED := 7.5

var list: Array[Prop] = []
var game: Node  # WorldBase
var last_hit: Dictionary = {}  # avatar pid -> {by, t} (for "who yeeted whom")

var _sync_t := 0.0
var _full_t := 0.0
var _sent: Dictionary = {}
var _hit_cd: Dictionary = {}
var _light_cd: Dictionary = {}


func spawn(kind: String, pos: Vector3, yaw_deg := 0.0) -> Prop:
	var p := Prop.new()
	p.id = list.size()
	p.name = "P%d" % p.id
	p.system = self
	p.setup(kind)
	add_child(p)
	p.global_position = pos
	p.rotation_degrees.y = yaw_deg
	p.home = p.global_transform
	p.set_net(p.global_position, p.global_transform.basis.get_rotation_quaternion())
	if not _host():
		p.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		p.freeze = true
	else:
		p.sleeping = true
	list.append(p)
	return p


func _host() -> bool:
	return multiplayer.is_server()


func _online() -> bool:
	return multiplayer.multiplayer_peer != null and \
		multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func held_by(pid: int) -> Prop:
	for p: Prop in list:
		if p.holder == pid:
			return p
	return null


func nearest_grabbable(av: Avatar) -> Prop:
	var best: Prop = null
	var best_d := 1.2 + 0.7 * av.size
	for p: Prop in list:
		if not p.can_grab(av):
			continue
		var d := (p.global_position - (av.global_position + Vector3.UP * 0.6 * av.size)).length() - p.radius
		if d < best_d:
			best_d = d
			best = p
	return best


# --- requests (client -> host) ------------------------------------------------

func grab(p: Prop) -> void:
	Net.to_server(self, "req_grab", [p.id])


func release(throw: bool, dir: Vector3) -> void:
	Net.to_server(self, "req_release", [throw, dir])


func bump(p: Prop, v: Vector3, at: Vector3) -> void:
	if _host():
		_apply_bump(p.id, v, at)
	elif _online():
		req_bump.rpc_id(1, p.id, v, at)


@rpc("any_peer", "reliable")
func req_grab(id: int) -> void:
	do_grab(Net.sender(), id)


func do_grab(pid: int, id: int) -> void:
	if not _host() or id < 0 or id >= list.size():
		return
	var av: Avatar = game.avatars.get(pid)
	var p := list[id]
	if av == null or av.dead or av.ragdolled() or held_by(pid) or not p.can_grab(av):
		return
	if (p.global_position - av.global_position).length() > 3.5 + 1.5 * av.size:
		return
	_ev_hold.rpc(id, pid)


@rpc("any_peer", "reliable")
func req_release(throw: bool, dir: Vector3) -> void:
	do_release(Net.sender(), throw, dir)


func do_release(pid: int, throw: bool, dir: Vector3) -> void:
	if not _host():
		return
	var p := held_by(pid)
	if p == null:
		return
	var av: Avatar = game.avatars.get(pid)
	var vel := Vector3.ZERO
	var pos := p.global_position
	if av:
		pos = p.hold_point(av)
		vel = av.net_velocity * 0.8
		if throw:
			dir = dir.normalized() if dir.length() > 0.1 else av.forward()
			var spd := clampf(24.0 - p.mass * 1.4, 9.0, 22.0) * sqrt(maxf(av.size, 0.5))
			vel += dir * spd + Vector3.UP * 3.0
	_ev_release.rpc(p.id, pid, pos, vel, throw)


@rpc("any_peer", "unreliable")
func req_bump(id: int, v: Vector3, at: Vector3) -> void:
	_apply_bump(id, v, at)


func _apply_bump(id: int, v: Vector3, at: Vector3) -> void:
	if not _host() or id < 0 or id >= list.size():
		return
	var p := list[id]
	if p.holder != 0 or p.gone:
		return
	p.sleeping = false
	p.apply_impulse(v.limit_length(40.0) / maxf(1.0, p.mass * 0.25), at - p.global_position)


# --- events (host -> everyone) ------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _ev_hold(id: int, pid: int) -> void:
	var p := list[id]
	p.holder = pid
	p.begin_hold()
	var av: Avatar = game.avatars.get(pid)
	if av:
		av.holding = p
	Sfx.at(self, "pop", p.global_position, -2.0)


@rpc("authority", "call_local", "reliable")
func _ev_release(id: int, pid: int, pos: Vector3, vel: Vector3, thrown: bool) -> void:
	var p := list[id]
	p.holder = 0
	var av: Avatar = game.avatars.get(pid)
	if av and av.holding == p:
		av.holding = null
	p.global_position = pos
	p.end_hold()
	p.thrown_by = pid if thrown else 0
	p.thrown_t = 0.0 if thrown else 99.0
	if _host():
		p.freeze = false
		p.sleeping = false
		p.linear_velocity = vel
		p.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (6.0 if thrown else 1.0)
	if thrown:
		Sfx.at(self, "whoosh", pos, 0.0, 0.1, clampf(1.4 / sqrt(p.mass), 0.6, 1.5))
		if av:
			av.play_shove()


@rpc("authority", "unreliable_ordered")
func _sync(data: PackedFloat32Array) -> void:
	var i := 0
	while i + 7 < data.size():
		var id := int(data[i])
		if id >= 0 and id < list.size():
			var p := list[id]
			p.set_net(Vector3(data[i + 1], data[i + 2], data[i + 3]),
				Quaternion(data[i + 4], data[i + 5], data[i + 6], data[i + 7]))
		i += 8


@rpc("authority", "call_local", "reliable")
func _ev_fx(kind: String, pos: Vector3, power: float) -> void:
	match kind:
		"bonk":
			Fx.impact(self, pos, clampf(power, 0.4, 1.6))
			Sfx.at(self, "bonk", pos, 2.0)
		"boom":
			Fx.explosion(self, pos, power)
			Sfx.at(self, "boom", pos, 6.0, 0.1)
			var me: Avatar = game.local_avatar() if game else null
			if me and game.cam:
				var d := me.global_position.distance_to(pos)
				game.cam.shake(clampf(1.4 - d / 25.0, 0.0, 1.2))


@rpc("authority", "call_local", "reliable")
func _ev_gone(id: int, on: bool) -> void:
	var p := list[id]
	p.gone = on
	p.visible = not on
	p.collision_layer = 0 if on else (4 if p.solid else 8)
	if not on:
		p.global_transform = p.home
		p.set_net(p.home.origin, p.home.basis.get_rotation_quaternion())
		p.scale = Vector3.ONE * 0.1
		p.create_tween().tween_property(p, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _host():
			p.linear_velocity = Vector3.ZERO
			p.angular_velocity = Vector3.ZERO
			p.freeze = false
	elif _host():
		p.freeze = true


# --- host helpers -------------------------------------------------------------

## Radial impulse on props + avatars (stomps, slaps, explosions, hazards).
## `launch` > 0 also knocks avatars around (big values -> full ragdoll).
func blast(pos: Vector3, r: float, power: float, launch := 0.0, skip_pid := 0) -> void:
	if not _host():
		return
	for p: Prop in list:
		if p.holder != 0 or p.gone:
			continue
		var d := p.global_position - pos
		var dist := d.length()
		if dist < r:
			var f := (1.0 - dist / r) * power
			p.sleeping = false
			p.apply_central_impulse((d.normalized() + Vector3.UP * 0.6).normalized() * f * minf(p.mass, 6.0))
	if launch <= 0.0 or game == null:
		return
	for av: Avatar in game.avatars.values():
		if av.dead or av.pid == skip_pid:
			continue
		var d := av.global_position + Vector3.UP * 0.8 * av.size - pos
		var dist := d.length()
		if dist < r:
			var f := (1.0 - dist / r) * launch
			var hv := Vector3(d.x, 0, d.z).normalized()
			av.push.rpc(hv * f + Vector3.UP * f * 0.7)


func explode(pos: Vector3, r := 6.0, power := 24.0, by := 0) -> void:
	if not _host():
		return
	_ev_fx.rpc("boom", pos, r)
	if game:
		for av: Avatar in game.avatars.values():
			if av.global_position.distance_to(pos) < r:
				last_hit[av.pid] = {"by": by, "t": Time.get_ticks_msec()}
	blast(pos, r, power, power)
	for p: Prop in list:
		if p.explosive and not p.gone and p.global_position.distance_to(pos) < r * 0.8:
			get_tree().create_timer(0.15).timeout.connect(_detonate.bind(p, by))


func _detonate(p: Prop, by: int) -> void:
	if p.gone or not _host():
		return
	_ev_gone.rpc(p.id, true)
	explode(p.global_position, 6.0, 24.0, by)
	get_tree().create_timer(12.0).timeout.connect(func() -> void: _ev_gone.rpc(p.id, false))


func _physics_process(delta: float) -> void:
	var host := _host()
	var avs: Dictionary = game.avatars if game else {}
	for p: Prop in list:
		var holder_av: Avatar = avs.get(p.holder) if p.holder != 0 else null
		p.tick(delta, host, holder_av)
	if not host:
		return
	var now := Time.get_ticks_msec()
	for p: Prop in list:
		if p.gone:
			continue
		if p.holder != 0:
			var hav: Avatar = avs.get(p.holder)
			if hav == null or hav.dead or hav.ragdolled():
				_ev_release.rpc(p.id, p.holder, p.global_position, hav.net_velocity if hav else Vector3.ZERO, false)
			continue
		var sp := p.linear_velocity.length()
		# explosive barrels go off on a hard impact
		if p.explosive and p.get_meta("prev_sp", 0.0) > 9.0 and sp < float(p.get_meta("prev_sp", 0.0)) * 0.45:
			_detonate(p, p.thrown_by)
			continue
		p.set_meta("prev_sp", sp)
		if p.global_position.y < -20.0 or (game and p.global_position.y < float(game.water_y) - 1.0):
			_ev_gone.rpc(p.id, true)
			get_tree().create_timer(3.0).timeout.connect(func() -> void: _ev_gone.rpc(p.id, false))
			continue
		for av: Avatar in avs.values():
			if av.dead:
				continue
			var d := av.global_position - p.global_position
			var dy := p.global_position.y - av.global_position.y
			var flat := Vector2(d.x, d.z).length()
			if dy < -p.radius or dy > 1.7 * av.size + p.radius:
				continue
			# fast prop -> impact on the avatar
			if sp > HIT_SPEED and flat < av.size * 0.4 + p.radius + 0.15 and not (p.thrown_by == av.pid and p.thrown_t < 0.5):
				var key := "%d_%d" % [p.id, av.pid]
				if now - int(_hit_cd.get(key, 0)) > 500:
					_hit_cd[key] = now
					var imp := (p.linear_velocity * sqrt(p.mass) * 0.55).limit_length(26.0)
					av.push.rpc(imp + Vector3.UP * 3.0)
					_ev_fx.rpc("bonk", p.global_position, sp / 12.0)
					if p.thrown_by != 0:
						last_hit[av.pid] = {"by": p.thrown_by, "t": now}
					p.linear_velocity *= 0.4
			# avatars kick light props they walk through
			elif not p.solid and flat < av.size * 0.36 + p.radius + 0.05:
				if now - int(_light_cd.get(p.id, 0)) > 120:
					_light_cd[p.id] = now
					var n := Vector3(-d.x, 0, -d.z).normalized()
					var push := maxf(av.net_velocity.dot(n), 1.5)
					p.sleeping = false
					p.apply_central_impulse((n * push * 0.9 + Vector3.UP * 1.2) * p.mass * av.size)
	_sync_t -= delta
	_full_t -= delta
	if _sync_t <= 0.0 and _online():
		_sync_t = SYNC_DT
		var full := _full_t <= 0.0
		if full:
			_full_t = FULL_DT
		var data := PackedFloat32Array()
		for p: Prop in list:
			if p.holder != 0:
				continue
			var pos := p.global_position
			var last: Vector3 = _sent.get(p.id, Vector3.INF)
			if not full and (p.sleeping or last.distance_squared_to(pos) < 0.0001):
				continue
			_sent[p.id] = pos
			var q := p.global_transform.basis.get_rotation_quaternion()
			data.append_array([p.id, pos.x, pos.y, pos.z, q.x, q.y, q.z, q.w])
			if data.size() >= 8 * 36:  # stay under the ENet MTU per packet
				_sync.rpc(data)
				data = PackedFloat32Array()
		if data.size() > 0:
			_sync.rpc(data)
