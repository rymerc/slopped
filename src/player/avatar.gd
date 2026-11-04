class_name Avatar
extends CharacterBody3D
## Networked player body. The owning peer (or the host, for bots) simulates and
## broadcasts its transform + a few state flags; every other peer interpolates.
##
## Movement: acceleration / momentum on the ground, weighty jumps (buffer,
## coyote time, variable height, faster fall), air control that steers without
## killing momentum, sprint that ramps up, slope snapping, dive + belly slide.
##
## Bodies: conventional procedural animation normally. Impacts are graded:
##   small  -> partial ragdoll (spring-driven lean / head whip / arm flail)
##   medium -> stumble (control loss, big lean)
##   strong -> full physics Ragdoll, then blend into a get-up animation.

enum St { NORMAL, RAGDOLL, GETUP, SLIDE }

const SEND_INTERVAL := 0.05
const GRAVITY := 24.0
const FALL_MULT := 1.55
const JUMP_CUT := 2.4
const APEX_MULT := 0.6
const TERMINAL := 42.0
const COYOTE := 0.12
const BUFFER := 0.14
const ACCEL := 40.0
const DECEL := 26.0
const TURN_BOOST := 1.8
const AIR_ACCEL := 15.0
const AIR_DRAG := 1.0
const SPRINT_RAMP := 2.6
const STAGGER_AT := 7.0
const KNOCKDOWN_AT := 12.0
const HARD_LAND := 23.0
const SPLAT_LAND := 31.0
const SLIDE_MAX := 26.0
const GETUP_TIME := 0.75
const BLEND_TIME := 0.3

var pid := 0
var is_bot := false
var role := "normal"  # normal | giant | little
var size := 1.0
var base_speed := 6.0
var sprint_mult := 1.6
var speed_mult := 1.0
var jump_vel := 8.5
var gravity_mult := 1.0
var head_scale := 1.0
var slippery := false
var face_camera := false  # giant: body follows camera yaw (aiming abilities)
var dead := false
var fallen := false
var stun_t := 0.0
var input_locked := false
var glow := false
var holding: Node3D  # Prop currently carried (set by PropSystem)

var cam: CamRig
var bot_move := Vector3.ZERO
var bot_jump := false
var bot_sprint := false
var facing := 0.0
var parts: Dictionary = {}
var net_velocity := Vector3.ZERO
var state := St.NORMAL
var sprint_k := 0.0
var floor_vis := true
var anim_phase := 0.0
var move_amt := 0.0

var _look: Dictionary = {}
var _look_key := ""
var _shape: CapsuleShape3D
var _col: CollisionShape3D
var _label: Label3D
var _ghost: MeshInstance3D
var _light: OmniLight3D
var _blob: MeshInstance3D
var _wind: AudioStreamPlayer
var _scrape: AudioStreamPlayer3D
var _slide_dust: CPUParticles3D
var _net_t := 0.0
var _tpos := Vector3.ZERO
var _tyaw := 0.0
var _tflags := 0
var _prev_pos := Vector3.ZERO
var _knock := Vector3.ZERO
var _spawn := Vector3.ZERO
# movement timers
var _coyote := 0.0
var _jump_buf := 0.0
var _jumping := false
var _bot_hold := 0.0
var _knock_t := 0.0
var _stumble_t := 0.0
var _was_floor := true
var _air_t := 0.0
var _slide_t := 0.0
var _dive_cd := 0.0
var _bump_cd := 0.0
var _prop_bump_cd := 0.0
# animation
var _lean := Vector2.ZERO
var _lean_v := Vector2.ZERO
var _squash := 0.0
var _squash_v := 0.0
var _flail := 0.0
var _turn_rate := 0.0
var _last_facing := 0.0
var _step_sign := 1.0
var _shove_t := 0.0
var _blink_t := 2.0
var _vis_yaw := 0.0
var _fallen_k := 0.0
# ragdoll
var _ragdoll: Ragdoll
var _rag_t := 0.0
var _rag_min := 1.2
var _getup_t := 0.0
var _getup_dir := -1.0
var _blend_from: Dictionary = {}
var _blend_t := 99.0
var _saved_layers := Vector2i(2, 7)


func setup(id: int, data: Dictionary) -> void:
	pid = id
	name = str(id)
	is_bot = Net.is_bot(id)
	set_multiplayer_authority(1 if is_bot else id)
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(48)
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_block_on_wall = true
	max_slides = 5
	_shape = CapsuleShape3D.new()
	_col = CollisionShape3D.new()
	_col.shape = _shape
	add_child(_col)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.006
	_label.outline_modulate = Art.INK
	add_child(_label)
	_blob = Fx.blob_shadow(self, 0.42)
	apply_look(data)
	set_size(1.0)


func is_local() -> bool:
	return not is_bot and pid == multiplayer.get_unique_id()


func controls() -> bool:
	return is_multiplayer_authority()


func world() -> Node:
	return get_parent().get_parent() if get_parent() else null


func can_ragdoll() -> bool:
	return role != "giant" and not dead


func ragdolled() -> bool:
	return state == St.RAGDOLL or state == St.GETUP


func place(pos: Vector3) -> void:
	_cancel_ragdoll()
	state = St.NORMAL
	_spawn = pos
	global_position = pos
	_tpos = pos
	_prev_pos = pos
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO


## Rebuilds the visual if the cosmetic look (or crown status) changed.
func apply_look(data: Dictionary) -> void:
	var look := data.duplicate()
	if Net.rank_of(pid) == "leader":
		look.hat = "crown"
	var key := "%s|%s|%s|%s" % [look.get("color"), look.get("hat"), look.get("body"), head_scale]
	_label.text = str(data.get("name", "?"))
	if key == _look_key:
		return
	_cancel_ragdoll()
	_look_key = key
	_look = look
	if parts.has("root"):
		(parts.root as Node3D).queue_free()
	parts = Art.build_character(look)
	add_child(parts.root)
	(parts.root as Node3D).scale = Vector3.ONE * size
	(parts.head as Node3D).scale = Vector3.ONE * head_scale
	(parts.root as Node3D).visible = not dead


func set_size(s: float) -> void:
	size = s
	_shape.radius = 0.36 * s
	_shape.height = 1.6 * s
	_col.position.y = 0.8 * s
	floor_snap_length = 0.45 * s
	if parts.has("root"):
		(parts.root as Node3D).scale = Vector3.ONE * s
	_label.position.y = 2.0 * s * maxf(1.0, head_scale * 0.8) + 0.25
	if _blob:
		_blob.scale = Vector3.ONE * s


func set_head_scale(s: float) -> void:
	head_scale = s
	if parts.has("head"):
		(parts.head as Node3D).scale = Vector3.ONE * s
	set_size(size)


func set_glow(on: bool) -> void:
	glow = on
	if on and _light == null:
		_light = OmniLight3D.new()
		_light.light_color = Color("#9dff6b")
		_light.light_energy = 2.5
		_light.omni_range = 5.0
		_light.position.y = 1.0
		add_child(_light)
	if _light:
		_light.visible = on


func set_dead(d: bool) -> void:
	if d:
		_cancel_ragdoll()
		state = St.NORMAL
	dead = d
	if parts.has("root"):
		(parts.root as Node3D).visible = not d
	collision_layer = 0 if d else 2
	collision_mask = 0 if d else 7
	_saved_layers = Vector2i(2, 7)
	if d and _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.mesh = Art.sphere(0.4, 8)
		_ghost.material_override = Art.ghost_mat()
		_ghost.position.y = 1.0
		add_child(_ghost)
	if _ghost:
		_ghost.visible = d
	if _blob:
		_blob.visible = not d
	_label.modulate = Color(1, 1, 1, 0.4) if d else Color.WHITE


## Funny death: leaves a ragdolled (or pancaked / burnt) corpse with X eyes,
## dizzy stars and a caption, then turns this avatar into a ghost.
## style: "launch" | "pancake" | "burnt"
func die(impulse: Vector3, style := "launch") -> void:
	if dead:
		return
	var w := world()
	if w and parts.has("root"):
		_cancel_ragdoll()
		var corpse: Dictionary = Chars.build(_look)
		var croot: Node3D = corpse.root
		w.add_child(croot)
		croot.global_transform = (parts.root as Node3D).global_transform
		(corpse.head as Node3D).scale = Vector3.ONE * head_scale
		for n: String in (parts.limbs as Dictionary):
			((corpse.limbs as Dictionary)[n] as Node3D).transform = ((parts.limbs as Dictionary)[n] as Node3D).transform
		(corpse.pivot as Node3D).transform = (parts.pivot as Node3D).transform
		Chars.x_eyes(corpse)
		var pos := global_position
		if style == "burnt":
			_tint(croot, Color("#3a3036"))
		var life := 7.0
		if style == "pancake":
			(corpse.pivot as Node3D).transform = Transform3D.IDENTITY
			croot.scale = Vector3(size * 1.5, size * 0.1, size * 1.5)
			Fx.text(w, pos + Vector3.UP * 1.0, "SPLAT", Color("#ff5fa2"), 0.03)
			Sfx.at(w, "squish", pos, 4.0)
		else:
			var rd := Ragdoll.create(w, corpse, size, head_scale, net_velocity, impulse + Vector3.UP * 3.0)
			rd.get_tree().create_timer(life).timeout.connect(rd.queue_free)
			Fx.dizzy(corpse.head, 0.75, life)
		var croot_ref := croot
		w.get_tree().create_timer(life).timeout.connect(func() -> void:
			if is_instance_valid(croot_ref):
				Fx.dust(croot_ref.get_parent(), croot_ref.global_position, 1.2, Color.WHITE)
				croot_ref.queue_free())
		Fx.confetti(w, pos + Vector3.UP, 24)
		Fx.text(w, pos + Vector3.UP * 2.2 * size, ["RIP", "BONK", "ouchie", "skill issue", "x_x", "WASTED (lol)"].pick_random(),
			Art.GOLD, 0.022, 2.0, 1.6)
		Sfx.at(w, "death", pos, 2.0, 0.1)
		Sfx.at(w, "bonk", pos, 0.0)
	set_dead(true)


func _tint(n: Node, c: Color) -> void:
	for ch: Node in n.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).material_override = Art.mat(c)
		_tint(ch, c)


# --- network ---------------------------------------------------------------

@rpc("any_peer", "unreliable_ordered")
func _net_state(p: Vector3, yaw: float, flags: int) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_tpos = p
	_tyaw = yaw
	_tflags = flags


## Server -> everyone: an impact. Owner applies physics; all peers react.
@rpc("any_peer", "call_local", "reliable")
func push(v: Vector3) -> void:
	if Net.sender() != 1:
		return
	_hit(v)


## Owner -> others: an impact the owner caused itself (hazards, falls).
@rpc("any_peer", "reliable")
func _hit_fx(v: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_hit(v)


func self_hit(v: Vector3) -> void:
	if not controls():
		return
	_hit(v)
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_hit_fx.rpc(v)


## Server -> owner: freeze movement for t seconds (t <= 0 clears).
@rpc("any_peer", "call_local", "reliable")
func stun(t: float) -> void:
	if Net.sender() != 1:
		return
	stun_t = 0.0 if t <= 0.0 else maxf(stun_t, t)


@rpc("any_peer", "call_local", "reliable")
func teleport(p: Vector3) -> void:
	if Net.sender() != 1:
		return
	if controls():
		place(p)


func _hit(v: Vector3) -> void:
	if dead:
		return
	var m := v.length() / maxf(1.0, size * size * 0.8)
	# partial ragdoll: spring kick in local space (pitch from front/back, roll from sides)
	var local := (parts.root as Node3D).global_transform.basis.inverse() * v if parts.has("root") else v
	_lean_v += Vector2(local.z, -local.x).normalized() * minf(m, 14.0) * 1.1 if Vector2(local.z, local.x).length() > 0.01 else Vector2.ZERO
	_flail = clampf(m / 9.0, _flail, 1.0)
	if m >= KNOCKDOWN_AT and can_ragdoll():
		start_ragdoll(v)
		return
	if controls():
		_knock += v
		if m >= STAGGER_AT:
			_stumble_t = maxf(_stumble_t, 0.55)
	if m >= STAGGER_AT:
		Sfx.at(self, "bonk", global_position + Vector3.UP * size, -4.0)


func play_shove() -> void:
	_shove_t = 0.35
	Sfx.at(self, "whoosh", global_position + Vector3.UP, -6.0, 0.1, 1.4)


# --- ragdoll ---------------------------------------------------------------

func start_ragdoll(impulse: Vector3) -> void:
	if not parts.has("limbs") or dead:
		return
	if state == St.RAGDOLL and _ragdoll:
		_ragdoll.kick(impulse * 0.6)
		_rag_t = minf(_rag_t, 0.4)
		return
	if state == St.GETUP:
		_finish_blend()
	var w := world()
	if w == null:
		return
	var v := velocity if controls() else net_velocity
	_ragdoll = Ragdoll.create(w, parts, size, head_scale, v, impulse)
	_ragdoll.use_follow = not controls()
	state = St.RAGDOLL
	_rag_t = 0.0
	_rag_min = clampf(0.8 + impulse.length() * 0.05, 1.0, 2.6)
	if controls():
		_saved_layers = Vector2i(collision_layer, collision_mask)
		collision_layer = 0
		collision_mask = 0
	Fx.impact(w, global_position + Vector3.UP * size, 1.0)
	Fx.text(w, global_position + Vector3.UP * 2.0 * size, ["OOF", "BONK", "WHAM", "ow"].pick_random(), Color.WHITE, 0.011)
	Sfx.at(self, "thud", global_position, 2.0)


func _ragdoll_tick(delta: float) -> void:
	_rag_t += delta
	if _ragdoll == null or not is_instance_valid(_ragdoll):
		state = St.NORMAL
		return
	var tp := _ragdoll.torso_pos()
	global_position = tp - Vector3.UP * 0.42 * size
	velocity = _ragdoll.torso().linear_velocity
	if tp.y < maxf(-25.0, _water_y()):
		_fell()
		return
	if _rag_t > _rag_min and (_ragdoll.speed() < 1.5 or _rag_t > 4.5):
		_end_ragdoll()


func _end_ragdoll() -> void:
	if _ragdoll == null or not is_instance_valid(_ragdoll):
		state = St.NORMAL
		return
	var tb := _ragdoll.torso().global_transform.basis
	var up := tb.y.normalized()
	var front := -tb.z.normalized()
	_getup_dir = -1.0 if front.y < 0.0 else 1.0  # -1: face down
	var head_dir := Vector3(up.x, 0, up.z)
	if head_dir.length() > 0.15:
		head_dir = head_dir.normalized()
		var d := head_dir if _getup_dir < 0.0 else -head_dir
		facing = atan2(-d.x, -d.z)
	var hips := _ragdoll.torso_pos()
	if controls():
		var q := PhysicsRayQueryParameters3D.create(hips + Vector3.UP * 0.5, hips + Vector3.DOWN * 4.0, 1 | 4)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		global_position = hit.position if hit else hips - Vector3.UP * 0.3 * size
		velocity = Vector3.ZERO
		collision_layer = _saved_layers.x
		collision_mask = _saved_layers.y
	_vis_yaw = facing
	(parts.root as Node3D).rotation.y = facing
	_getup_t = 0.0
	_pose_getup(0.0)
	_blend_from = _ragdoll.restore()
	_ragdoll = null
	_blend_t = 0.0
	_remote_getup_t = 0.0
	state = St.GETUP
	_squash_v = -3.0


func _cancel_ragdoll() -> void:
	if _ragdoll and is_instance_valid(_ragdoll):
		_ragdoll.restore()
		if controls():
			collision_layer = _saved_layers.x
			collision_mask = _saved_layers.y
	_ragdoll = null
	_blend_from = {}
	_blend_t = 99.0
	if state == St.RAGDOLL or state == St.GETUP:
		state = St.NORMAL


func _finish_blend() -> void:
	_blend_t = 99.0
	_blend_from = {}
	state = St.NORMAL


func _fell() -> void:
	var w := world()
	var p := global_position
	if w:
		Fx.splash(w, Vector3(p.x, maxf(_water_y(), p.y), p.z))
		Sfx.at(w, "splash", p, 2.0)
	var to: Vector3 = w.call("respawn_for", self) if w and w.has_method("respawn_for") else _spawn
	var keep := _spawn
	place(to)
	_spawn = keep
	if w and w.has_method("on_avatar_fell"):
		w.call("on_avatar_fell", self)


# --- simulation ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if controls():
		_simulate(delta)
		_net_t -= delta
		if _net_t <= 0.0:
			_net_t = SEND_INTERVAL
			var flags := int(state == St.RAGDOLL) | (int(floor_vis) << 1) | (int(state == St.SLIDE) << 2)
			if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				_net_state.rpc(global_position, facing, flags)
	else:
		var k := clampf(delta * 14.0, 0.0, 1.0)
		if global_position.distance_to(_tpos) > 12.0:
			global_position = _tpos
		global_position = global_position.lerp(_tpos, k)
		facing = lerp_angle(facing, _tyaw, k)
		_remote_flags()
	net_velocity = (global_position - _prev_pos) / maxf(delta, 0.0001)
	_prev_pos = global_position
	_animate(delta)


func _remote_flags() -> void:
	var rag := _tflags & 1 != 0
	floor_vis = _tflags & 2 != 0
	if rag and state != St.RAGDOLL and can_ragdoll():
		start_ragdoll(Vector3.ZERO)
	elif not rag and state == St.RAGDOLL and _rag_t > 0.25:
		_end_ragdoll()
	if state == St.RAGDOLL:
		_rag_t += get_physics_process_delta_time()
		if _ragdoll:
			_ragdoll.follow = global_position + Vector3.UP * 0.42 * size
	elif state != St.GETUP:
		state = St.SLIDE if _tflags & 4 != 0 else St.NORMAL


func _simulate(delta: float) -> void:
	var dir := Vector3.ZERO
	var want_jump := false
	var hold_jump := false
	var sprint := false
	var want_dive := false
	if is_bot:
		dir = bot_move
		want_jump = bot_jump
		sprint = bot_sprint
		if bot_jump:
			_bot_hold = 0.35
		bot_jump = false
		_bot_hold -= delta
		hold_jump = _bot_hold > 0.0
	elif not input_locked and cam:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = cam.yaw_basis() * Vector3(iv.x, 0.0, iv.y)
		want_jump = Input.is_action_just_pressed("jump")
		hold_jump = Input.is_action_pressed("jump")
		sprint = Input.is_action_pressed("sprint")
		want_dive = Input.is_action_just_pressed("dive")
	if dir.length() > 1.0:
		dir = dir.normalized()

	if dead:  # ghost: free flight, no collision
		var gv := dir * 12.0
		if hold_jump:
			gv.y = 8.0
		elif sprint:
			gv.y = -8.0
		velocity = gv
		move_and_slide()
		return

	if state == St.RAGDOLL:
		_ragdoll_tick(delta)
		return

	_knock_t -= delta
	_stumble_t -= delta
	_dive_cd -= delta
	_bump_cd -= delta
	_prop_bump_cd -= delta
	if stun_t > 0.0:
		stun_t -= delta
		dir = Vector3.ZERO
		want_jump = false
		want_dive = false
	if state == St.GETUP:
		dir = Vector3.ZERO
		want_jump = false
		want_dive = false

	var on_floor := is_on_floor()
	_coyote = COYOTE if on_floor else _coyote - delta
	_jump_buf = BUFFER if want_jump else _jump_buf - delta
	var moving := dir.length() > 0.1
	if on_floor:
		sprint_k = move_toward(sprint_k, 1.0 if sprint and moving else 0.0, delta * (SPRINT_RAMP if sprint and moving else 4.0))
	var spd := base_speed * speed_mult * (1.0 + (sprint_mult - 1.0) * sprint_k)
	var weight := 1.0 / sqrt(maxf(size, 1.0))
	var control := 0.3 if _stumble_t > 0.0 else 1.0

	# dive: lunge forward, land into a belly slide
	if want_dive and state == St.NORMAL and holding == null and _dive_cd <= 0.0 and (moving or not on_floor):
		var f := dir.normalized() if moving else forward()
		var hv0 := Vector3(velocity.x, 0, velocity.z)
		var boost := maxf(hv0.length(), spd) + 3.5
		velocity = Vector3(f.x * boost, maxf(velocity.y, 4.5 if on_floor else velocity.y + 2.0), f.z * boost)
		facing = atan2(-f.x, -f.z)
		state = St.SLIDE
		_slide_t = 0.0
		_dive_cd = 0.6
		_coyote = 0.0
		_squash_v = 2.0
		Sfx.at(self, "whoosh", global_position, -2.0, 0.1, 0.9)

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if state == St.SLIDE:
		hv = _slide_move(hv, dir, on_floor, delta)
		if state == St.SLIDE and _jump_buf > 0.0 and (on_floor or _coyote > 0.0) and _slide_t > 0.15:
			state = St.NORMAL
			_jump_buf = 0.0
			_coyote = 0.0
			velocity.y = jump_vel * 0.75
			_jumping = true
			_on_jump()
	elif on_floor:
		if slippery:
			hv = hv.move_toward(dir * spd, 5.0 * delta)
		elif moving:
			var a := ACCEL * weight
			if hv.length() > 1.0 and hv.dot(dir) < 0.0:
				a *= TURN_BOOST
			hv = hv.move_toward(dir * spd * control, a * delta * control)
		else:
			hv = hv.move_toward(Vector3.ZERO, DECEL * weight * delta * (0.25 if _knock_t > 0.0 else 1.0))
	else:
		var air := (0.3 if _knock_t > 0.0 else 1.0) * control
		if moving:
			hv = hv.move_toward(dir * maxf(spd, hv.length()), AIR_ACCEL * air * delta)
		else:
			hv = hv.move_toward(Vector3.ZERO, AIR_DRAG * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if state == St.NORMAL and _jump_buf > 0.0 and _coyote > 0.0 and jump_vel > 0.0:
		velocity.y = jump_vel
		_jump_buf = 0.0
		_coyote = 0.0
		_jumping = true
		if sprint_k > 0.5:
			velocity.x *= 1.06
			velocity.z *= 1.06
		_on_jump()

	if not on_floor or velocity.y > 0.0:
		var g := GRAVITY * gravity_mult
		if velocity.y < 0.0:
			g *= FALL_MULT
		elif _jumping and not hold_jump:
			g *= JUMP_CUT
		elif hold_jump and absf(velocity.y) < 1.8:
			g *= APEX_MULT
		velocity.y = maxf(velocity.y - g * delta, -TERMINAL)
	if velocity.y <= 0.0:
		_jumping = false

	if _knock.length() > 0.01:
		velocity += _knock
		if _knock.length() > 3.0:
			_knock_t = 0.5
		_knock = Vector3.ZERO

	_push_from_others(delta)
	var vy_before := velocity.y
	move_and_slide()
	_bump_props()

	var now_floor := is_on_floor()
	floor_vis = now_floor
	if now_floor and not _was_floor and _air_t > 0.08:
		_on_land(-vy_before)
	_air_t = 0.0 if now_floor else _air_t + delta
	_was_floor = now_floor

	if state == St.GETUP:
		_getup_t += delta
		if _getup_t >= GETUP_TIME:
			state = St.NORMAL
			_squash_v = 2.5

	if state != St.SLIDE:
		var turn := 16.0 if now_floor else 7.0
		if face_camera and cam and stun_t <= 0.0:
			facing = lerp_angle(facing, cam.yaw, clampf(delta * 10.0, 0.0, 1.0))
		elif moving and state == St.NORMAL:
			facing = lerp_angle(facing, atan2(-dir.x, -dir.z), clampf(delta * turn, 0.0, 1.0))

	if global_position.y < maxf(-25.0, _water_y()):
		_fell()


func _water_y() -> float:
	var w := world()
	return float(w.water_y) if w is WorldBase else -1000.0


func _slide_move(hv: Vector3, dir: Vector3, on_floor: bool, delta: float) -> Vector3:
	_slide_t += delta
	if on_floor:
		var n := get_floor_normal()
		var downhill := Vector3(n.x, 0.0, n.z)
		hv += downhill * GRAVITY * 1.2 * delta
		var friction := 2.0 if downhill.length() > 0.12 else 7.0
		hv = hv.move_toward(Vector3.ZERO, friction * delta)
		if dir.length() > 0.1 and hv.length() > 0.5:
			var ang := clampf(hv.signed_angle_to(dir, Vector3.UP), -1.0, 1.0)
			hv = hv.rotated(Vector3.UP, ang * 1.8 * delta)
		hv = hv.limit_length(SLIDE_MAX)
		if hv.length() < 1.3 and _slide_t > 0.35:
			state = St.NORMAL
			_squash_v = 2.0
	elif _slide_t > 2.5 and velocity.y < -2.0:
		pass
	if hv.length() > 0.5:
		facing = lerp_angle(facing, atan2(-hv.x, -hv.z), clampf(delta * 6.0, 0.0, 1.0))
	return hv


## Physical pushing between players. Each owner reacts to bodies shoving into
## it (CharacterBodies don't push each other), heavier bodies push harder.
func _push_from_others(_delta: float) -> void:
	var root := get_parent()
	if root == null:
		return
	for o: Node in root.get_children():
		if o == self or not (o is Avatar):
			continue
		var other := o as Avatar
		if other.dead or other.state == St.RAGDOLL:
			continue
		var d := global_position - other.global_position
		var dy := d.y
		d.y = 0.0
		var rs := (_shape.radius + other._shape.radius) * 1.08
		var dist := d.length()
		if dist > rs or dist < 0.001 or absf(dy) > (size + other.size) * 0.8:
			continue
		var n := d / dist
		var ratio := clampf(pow(other.size / size, 2.0), 0.25, 8.0)
		var toward := other.net_velocity.dot(n)
		var hv := Vector3(velocity.x, 0, velocity.z)
		if toward > 0.4:
			var want := toward * minf(ratio, 1.6)
			var along := hv.dot(n)
			if along < want:
				hv += n * (want - along)
		hv += n * (rs - dist) * 8.0 * minf(ratio, 2.0)
		velocity.x = hv.x
		velocity.z = hv.z
		if toward > 7.5 and ratio >= 0.6 and _bump_cd <= 0.0:
			_bump_cd = 0.7
			self_hit(n * toward * 0.75 * minf(ratio, 2.0) + Vector3.UP * 2.0)


func _bump_props() -> void:
	if _prop_bump_cd > 0.0:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var obj := c.get_collider()
		if obj is Prop:
			var hv := Vector3(velocity.x, 0, velocity.z)
			var push := -c.get_normal() * maxf(hv.length(), 2.0) * size * size
			push.y = maxf(push.y, 0.0)
			(obj as Prop).request_bump(push * 0.6, c.get_position())
			_prop_bump_cd = 0.12
			return


func _on_jump() -> void:
	_squash_v = 3.2
	Sfx.at(self, "jump", global_position, -6.0, 0.08, 1.0 / sqrt(size))
	if cam:
		cam.jumped()


func _on_land(impact: float) -> void:
	_squash_v -= clampf(impact / 5.0, 0.6, 5.0)
	var w := world()
	if impact > 5.0 and w:
		Fx.dust(w, global_position, clampf(impact / 16.0, 0.3, 1.6) * sqrt(size))
		Sfx.at(self, "land", global_position, linear_to_db(clampf(impact / 18.0, 0.2, 1.4)), 0.1, 1.0 / sqrt(size))
	if cam:
		cam.land(impact)
	if state == St.SLIDE:
		return
	if can_ragdoll() and gravity_mult > 0.6:
		if impact > SPLAT_LAND:
			start_ragdoll(Vector3(velocity.x, 2.0, velocity.z) * 0.5 + forward() * 2.0)
			if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				_hit_fx.rpc(Vector3.UP * 0.1)
		elif impact > HARD_LAND:
			_stumble_t = 0.5
			_lean_v += Vector2(-6.0, randf_range(-3, 3))


func forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


# --- animation ---------------------------------------------------------------

func _animate(delta: float) -> void:
	if not parts.has("root"):
		return
	var root := parts.root as Node3D
	var pivot := parts.pivot as Node3D
	_update_blob()
	_update_audio(delta)
	if dead:
		if _ghost:
			_ghost.position.y = 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.15
		return
	if state == St.RAGDOLL:
		return

	var turn := wrapf(facing - _last_facing, -PI, PI) / maxf(delta, 0.0001)
	_last_facing = facing
	_turn_rate = lerpf(_turn_rate, turn, clampf(delta * 10.0, 0.0, 1.0))
	_vis_yaw = facing
	root.rotation.y = facing

	var hv := Vector2(net_velocity.x, net_velocity.z).length() / maxf(size, 0.3)
	var on_floor := floor_vis
	move_amt = lerpf(move_amt, clampf(hv / 5.5, 0.0, 1.3) if on_floor else move_amt * 0.9, clampf(delta * 8.0, 0.0, 1.0))
	var prev := anim_phase
	anim_phase += delta * clampf(3.0 + hv * 1.35, 3.0, 15.0)
	var s := sin(anim_phase)
	if on_floor and move_amt > 0.25 and state == St.NORMAL and signf(sin(anim_phase)) != signf(sin(prev)):
		_footstep()

	# springs: partial-ragdoll lean, squash/stretch
	_lean_v += (-_lean * 70.0 - _lean_v * 9.0) * delta
	_lean += _lean_v * delta
	_lean = _lean.limit_length(1.3)
	_squash_v += (-_squash * 180.0 - _squash_v * 14.0) * delta
	_squash += _squash_v * delta
	_squash = clampf(_squash, -0.45, 0.45)
	_flail = move_toward(_flail, 0.0, delta * 1.2)
	_shove_t -= delta
	if _stumble_t > 0.0 and controls():
		_lean_v += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 30.0 * delta

	var vy := velocity.y if controls() else net_velocity.y
	var rise := clampf(vy / 8.0, -1.0, 1.0)
	var t := Time.get_ticks_msec() * 0.001
	var m := move_amt
	var pose := {}
	var torso_r := Vector3(-0.1 * m - 0.12 * sprint_k * m, s * 0.1 * m, clampf(-_turn_rate * 0.03 * m, -0.25, 0.25))
	var head_r := Vector3(0.05 * m, -s * 0.06 * m, 0.0)
	var arm_l := Vector3(-s * 0.85 * m, 0.0, -0.12 - sin(t * 2.0) * 0.03 * (1.0 - m))
	var arm_r := Vector3(s * 0.85 * m, 0.0, 0.12 + sin(t * 2.0) * 0.03 * (1.0 - m))
	var leg_l := Vector3(s * 0.75 * m, 0.0, 0.0)
	var leg_r := Vector3(-s * 0.75 * m, 0.0, 0.0)
	var piv_rot := Vector3.ZERO
	var piv_pos := Vector3(0, absf(s) * 0.06 * m, 0)

	if not on_floor and state == St.NORMAL:
		if rise > 0.0:  # going up: arms up, one knee tucked
			arm_l = Vector3(-2.4 * rise, 0, -0.4)
			arm_r = Vector3(-2.4 * rise, 0, 0.4)
			leg_l = Vector3(-0.9 * rise, 0, 0)
			leg_r = Vector3(0.3 * rise, 0, 0)
		else:  # falling: flail
			var f := clampf(-rise, 0.0, 1.0)
			var w := sin(t * 22.0) * 0.5 * f
			arm_l = Vector3(-1.2 * f + w, 0, -1.2 * f)
			arm_r = Vector3(-1.2 * f - w, 0, 1.2 * f)
			leg_l = Vector3(0.5 * w, 0, -0.15 * f)
			leg_r = Vector3(-0.5 * w, 0, 0.15 * f)
	if state == St.SLIDE:  # superman belly slide
		piv_rot.x = -1.3
		piv_pos = Vector3(0, 0.32, 0.0)
		arm_l = Vector3(-3.0, 0, -0.25)
		arm_r = Vector3(-3.0, 0, 0.25)
		leg_l = Vector3(0.15, 0, -0.05)
		leg_r = Vector3(0.15, 0, 0.05)
		head_r = Vector3(0.6, 0, 0)
	if holding:
		arm_l = Vector3(-1.35, 0, 0.25)
		arm_r = Vector3(-1.35, 0, -0.25)
	if _shove_t > 0.0:
		var k := sin(clampf(_shove_t / 0.35, 0.0, 1.0) * PI)
		arm_l = arm_l.lerp(Vector3(-1.6, 0, 0.2), k)
		arm_r = arm_r.lerp(Vector3(-1.6, 0, -0.2), k)
		torso_r.x -= 0.3 * k
	if _flail > 0.0:
		var fl := sin(t * 28.0) * _flail
		arm_l += Vector3(fl * 0.8, 0, -1.2 * _flail)
		arm_r += Vector3(-fl * 0.8, 0, 1.2 * _flail)
	# giant face-plant (tripped): fall with a bounce, arms out
	_fallen_k = move_toward(_fallen_k, 1.0 if fallen else 0.0, delta * (2.6 if fallen else 1.6))
	if _fallen_k > 0.0:
		var e := ease(_fallen_k, -2.2)
		piv_rot.x = lerpf(piv_rot.x, -1.45, e)
		arm_l = arm_l.lerp(Vector3(-2.8, 0, -0.9), e)
		arm_r = arm_r.lerp(Vector3(-2.8, 0, 0.9), e)
		head_r.x = lerpf(head_r.x, -0.5, e)
	if state == St.GETUP:
		var g := _pose_getup(clampf(_getup_t / GETUP_TIME, 0.0, 1.0)) if controls() else _pose_getup(_remote_getup(delta))
		piv_rot = g.rot
		piv_pos = g.pos
		arm_l = g.arm_l
		arm_r = g.arm_r
		leg_l = g.leg
		leg_r = g.leg
	# partial ragdoll lean on top of everything
	piv_rot.x += _lean.x * 0.5
	piv_rot.z += _lean.y * 0.5
	head_r.x += -_lean_v.x * 0.03
	head_r.z += -_lean_v.y * 0.03

	var q := _squash
	pivot.transform = Transform3D(Basis.from_euler(piv_rot).scaled(Vector3(1.0 + q * 0.5, 1.0 - q, 1.0 + q * 0.5)), piv_pos)
	pose["torso"] = torso_r
	pose["head"] = head_r
	pose["arm_l"] = arm_l
	pose["arm_r"] = arm_r
	pose["leg_l"] = leg_l
	pose["leg_r"] = leg_r
	_apply_pose(pose, delta)

	if parts.get("tail"):
		(parts.tail as Node3D).rotation.y = sin(t * 3.0) * 0.5
	var hat: Node3D = parts.hat
	if hat:
		var spin := hat.get_node_or_null("Spin") as Node3D
		if spin:
			spin.rotation.y += delta * (6.0 + hv * 4.0)
	_blink(delta)


var _remote_getup_t := 0.0


func _remote_getup(delta: float) -> float:
	_remote_getup_t += delta
	var k := clampf(_remote_getup_t / GETUP_TIME, 0.0, 1.0)
	if k >= 1.0:
		state = St.NORMAL
		_remote_getup_t = 0.0
	return k


## Get-up animation: lying (face down = push-up, face up = sit-up) -> standing.
func _pose_getup(k: float) -> Dictionary:
	var e := ease(k, -2.0)
	var lie := PI * 0.5 * _getup_dir
	var ang := lerpf(lie, 0.0, e)
	var hip := Vector3(0, Chars.HIP_Y, 0)
	var target := Vector3(0, lerpf(0.2, Chars.HIP_Y, e), 0)
	var r := Basis.from_euler(Vector3(ang, 0, 0))
	var pos := target - r * hip
	var push := sin(k * PI)
	var arms := Vector3(-1.5 * push if _getup_dir < 0.0 else 1.2 * push, 0, 0)
	var out := {"rot": Vector3(ang, 0, 0), "pos": pos, "arm_l": arms + Vector3(0, 0, -0.3),
		"arm_r": arms + Vector3(0, 0, 0.3), "leg": Vector3(0.6 * push * -_getup_dir, 0, 0)}
	if parts.has("pivot"):
		(parts.pivot as Node3D).transform = Transform3D(r, pos)
	return out


func _apply_pose(pose: Dictionary, delta: float) -> void:
	var limbs: Dictionary = parts.limbs
	var rest: Dictionary = parts.rest
	var blending := _blend_t < BLEND_TIME
	if blending:
		_blend_t += delta
	var w := ease(clampf(_blend_t / BLEND_TIME, 0.0, 1.0), -1.8)
	for n: String in pose:
		var limb: Node3D = limbs[n]
		var r: Transform3D = rest[limb.name]
		var b := Basis.from_euler(pose[n])
		if n == "head":
			b = b.scaled(Vector3.ONE * head_scale)
		var target := Transform3D(b, r.origin)
		if blending and _blend_from.has(n):
			var from: Transform3D = _blend_from[n]
			limb.transform = from.interpolate_with(target, w)
		else:
			limb.transform = target
	if blending and _blend_t >= BLEND_TIME:
		_blend_from = {}


func _blink(delta: float) -> void:
	_blink_t -= delta
	var eyes: Array = parts.get("eyes", [])
	var closed := _blink_t < 0.0 and _blink_t > -0.12
	for e: Node3D in eyes:
		e.scale.y = 0.15 if closed else 1.0
	if _blink_t < -0.12:
		_blink_t = randf_range(1.8, 5.0)


func _footstep() -> void:
	var w := world()
	if w == null:
		return
	var p := global_position
	var loud := -14.0 + sprint_k * 6.0 + 4.0 * log(size + 0.01)
	Sfx.at(w, "step", p, loud, 0.18, (1.0 + sprint_k * 0.15) / sqrt(size))
	if sprint_k > 0.6 or size > 2.0:
		Fx.step(w, p)
	if size > 2.0 and cam == null:
		pass


func _update_blob() -> void:
	if _blob == null or not _blob.visible:
		return
	var from := global_position + Vector3.UP * 0.3 * size
	if state == St.RAGDOLL and _ragdoll:
		from = _ragdoll.torso_pos()
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0, 1 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var h := from.y - float(hit.position.y)
		_blob.global_position = hit.position + Vector3.UP * 0.03
		var k := clampf(1.0 - h / (8.0 * size), 0.25, 1.0)
		_blob.scale = Vector3(k, 1, k) * size
		_blob.visible = true
	else:
		_blob.scale = Vector3.ZERO


func _update_audio(delta: float) -> void:
	if is_local() and not dead:
		if _wind == null:
			_wind = AudioStreamPlayer.new()
			_wind.stream = Sfx.stream("wind")
			_wind.volume_db = -60.0
			add_child(_wind)
			_wind.play()
		var spd := velocity.length()
		var fall := clampf((-velocity.y - 10.0) / 25.0, 0.0, 1.0)
		var k := maxf(fall, clampf((spd - 14.0) / 20.0, 0.0, 1.0))
		_wind.volume_db = lerpf(_wind.volume_db, linear_to_db(maxf(k, 0.001)) - 4.0, clampf(delta * 5.0, 0.0, 1.0))
		_wind.pitch_scale = 0.8 + k * 0.5
	var sliding := state == St.SLIDE and floor_vis
	if sliding and _scrape == null:
		_scrape = AudioStreamPlayer3D.new()
		_scrape.stream = Sfx.stream("scrape")
		_scrape.unit_size = 6.0
		add_child(_scrape)
		_scrape.play()
		_slide_dust = Fx.trail(self, Color("#e9dcc0"), 0.14)
	if _scrape:
		var sp := Vector2(net_velocity.x, net_velocity.z).length()
		_scrape.volume_db = linear_to_db(clampf(sp / 14.0, 0.001, 1.0)) - 6.0 if sliding else -80.0
		_scrape.pitch_scale = 0.7 + clampf(sp / 25.0, 0.0, 0.8)
		if _slide_dust:
			_slide_dust.emitting = sliding and sp > 4.0
