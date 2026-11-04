class_name Avatar
extends CharacterBody3D
## Networked player body. The owning peer (or the host, for bots) simulates and
## broadcasts its transform; every other peer interpolates.

const GRAVITY := 24.0
const SEND_INTERVAL := 0.05

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

var cam: CamRig
var bot_move := Vector3.ZERO
var bot_jump := false
var bot_sprint := false
var facing := 0.0
var parts: Dictionary = {}
var net_velocity := Vector3.ZERO

var _look_key := ""
var _shape: CapsuleShape3D
var _col: CollisionShape3D
var _label: Label3D
var _ghost: MeshInstance3D
var _light: OmniLight3D
var _net_t := 0.0
var _tpos := Vector3.ZERO
var _tyaw := 0.0
var _prev_pos := Vector3.ZERO
var _anim_t := 0.0
var _move_amt := 0.0
var _knock := Vector3.ZERO
var _spawn := Vector3.ZERO


func setup(id: int, data: Dictionary) -> void:
	pid = id
	name = str(id)
	is_bot = Net.is_bot(id)
	set_multiplayer_authority(1 if is_bot else id)
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
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
	apply_look(data)
	set_size(1.0)


func is_local() -> bool:
	return not is_bot and pid == multiplayer.get_unique_id()


func controls() -> bool:
	return is_multiplayer_authority()


func place(pos: Vector3) -> void:
	_spawn = pos
	global_position = pos
	_tpos = pos
	_prev_pos = pos
	velocity = Vector3.ZERO


## Rebuilds the visual if the cosmetic look (or crown status) changed.
func apply_look(data: Dictionary) -> void:
	var look := data.duplicate()
	if Net.rank_of(pid) == "leader":
		look.hat = "crown"
	var key := "%s|%s|%s|%s" % [look.get("color"), look.get("hat"), look.get("body"), head_scale]
	_label.text = str(data.get("name", "?"))
	if key == _look_key:
		return
	_look_key = key
	if parts.has("root"):
		(parts.root as Node3D).queue_free()
	parts = Art.build_character(look)
	add_child(parts.root)
	(parts.root as Node3D).scale = Vector3.ONE * size
	(parts.head as Node3D).scale = Vector3.ONE * head_scale
	(parts.root as Node3D).visible = not dead


func set_size(s: float) -> void:
	size = s
	_shape.radius = 0.38 * s
	_shape.height = 1.75 * s
	_col.position.y = 0.875 * s
	floor_snap_length = 0.3 * s
	if parts.has("root"):
		(parts.root as Node3D).scale = Vector3.ONE * s
	_label.position.y = 2.15 * s * maxf(1.0, head_scale * 0.8) + 0.25


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
	dead = d
	if parts.has("root"):
		(parts.root as Node3D).visible = not d
	collision_layer = 0 if d else 2
	collision_mask = 0 if d else 3
	if d and _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.mesh = Art.sphere(0.4, 8)
		_ghost.material_override = Art.ghost_mat()
		_ghost.position.y = 1.0
		add_child(_ghost)
	if _ghost:
		_ghost.visible = d
	_label.modulate = Color(1, 1, 1, 0.4) if d else Color.WHITE


# --- network ---------------------------------------------------------------

@rpc("any_peer", "unreliable_ordered")
func _net_state(p: Vector3, yaw: float) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_tpos = p
	_tyaw = yaw


## Server -> owner: add an impulse.
@rpc("any_peer", "call_local", "reliable")
func push(v: Vector3) -> void:
	if Net.sender() != 1:
		return
	if controls():
		_knock += v


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


# --- simulation ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if controls():
		_simulate(delta)
		_net_t -= delta
		if _net_t <= 0.0:
			_net_t = SEND_INTERVAL
			_net_state.rpc(global_position, facing)
	else:
		var k := clampf(delta * 14.0, 0.0, 1.0)
		if global_position.distance_to(_tpos) > 12.0:
			global_position = _tpos
		global_position = global_position.lerp(_tpos, k)
		facing = lerp_angle(facing, _tyaw, k)
	net_velocity = (global_position - _prev_pos) / maxf(delta, 0.0001)
	_prev_pos = global_position
	_animate(delta)


func _simulate(delta: float) -> void:
	var dir := Vector3.ZERO
	var want_jump := false
	var hold_jump := false
	var sprint := false
	if is_bot:
		dir = bot_move
		want_jump = bot_jump
		sprint = bot_sprint
		bot_jump = false
	elif not input_locked and cam:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = cam.yaw_basis() * Vector3(iv.x, 0.0, iv.y)
		want_jump = Input.is_action_just_pressed("jump")
		hold_jump = Input.is_action_pressed("jump")
		sprint = Input.is_action_pressed("sprint")
	if dir.length() > 1.0:
		dir = dir.normalized()

	if dead:  # ghost: free flight, no collision
		var v := dir * 12.0
		if hold_jump:
			v.y = 8.0
		elif sprint:
			v.y = -8.0
		velocity = v
		move_and_slide()
		return

	if stun_t > 0.0:
		stun_t -= delta
		dir = Vector3.ZERO
		want_jump = false

	var spd := base_speed * speed_mult * (sprint_mult if sprint else 1.0)
	var accel := 70.0
	if slippery:
		accel = 5.0
	elif not is_on_floor():
		accel = 25.0
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.move_toward(dir * spd, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		if want_jump and jump_vel > 0.0:
			velocity.y = jump_vel
	else:
		velocity.y -= GRAVITY * gravity_mult * delta
	velocity += _knock
	_knock = Vector3.ZERO
	move_and_slide()

	if face_camera and cam and stun_t <= 0.0:
		facing = lerp_angle(facing, cam.yaw, clampf(delta * 10.0, 0.0, 1.0))
	elif dir.length() > 0.1:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), clampf(delta * 12.0, 0.0, 1.0))
	if global_position.y < -25.0:
		place(_spawn)


func forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


func _animate(delta: float) -> void:
	if not parts.has("root"):
		return
	var root := parts.root as Node3D
	var pivot := parts.pivot as Node3D
	root.rotation.y = facing
	var hv := Vector2(net_velocity.x, net_velocity.z).length() / maxf(size, 0.3)
	_move_amt = lerpf(_move_amt, clampf(hv / 5.0, 0.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	_anim_t += delta * (4.0 + hv * 2.2)
	var s := sin(_anim_t)
	pivot.rotation.z = s * 0.13 * _move_amt
	var tilt := -1.45 if fallen else -0.12 * _move_amt
	pivot.rotation.x = lerpf(pivot.rotation.x, tilt, clampf(delta * 8.0, 0.0, 1.0))
	pivot.position.y = absf(s) * 0.08 * _move_amt
	var feet: Array = parts.feet
	(feet[0] as Node3D).position.z = -0.05 + s * 0.2 * _move_amt
	(feet[1] as Node3D).position.z = -0.05 - s * 0.2 * _move_amt
	var hands: Array = parts.hands
	(hands[0] as Node3D).position.y = 0.72 + s * 0.1 * _move_amt
	(hands[1] as Node3D).position.y = 0.72 - s * 0.1 * _move_amt
	var hat: Node3D = parts.hat
	if hat:
		var spin := hat.get_node_or_null("Spin") as Node3D
		if spin:
			spin.rotation.y += delta * (6.0 + hv * 4.0)
	if _ghost and dead:
		_ghost.position.y = 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.15
