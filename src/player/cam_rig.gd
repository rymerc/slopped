class_name CamRig
extends Node3D
## Third-person orbit camera. Follows `target`, mouse controls yaw/pitch
## (raw, unsmoothed: turning stays instant). Everything else is feel:
##   - split follow damping (snappy horizontally, softer vertically on jumps)
##   - subtle head bob + sway synced to the avatar's stride
##   - landing bump spring, small kick on jump
##   - FOV widens with sprint and fall speed; looks down + pulls back when falling
##   - strafe roll, trauma-based smooth shake

var target: Node3D
var yaw := 0.0
var pitch := -0.3
var distance := 5.0
var height := 1.6
var base_fov := 72.0
var wobble := 0.0  # drunk camera, seconds remaining
var arm: SpringArm3D
var cam: Camera3D

var _trauma := 0.0
var _bump := 0.0
var _bump_v := 0.0
var _roll := 0.0
var _fall_k := 0.0
var _fov_k := 0.0
var _pos := Vector3.ZERO
var _noise_t := 0.0


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	arm.margin = 0.3
	add_child(arm)
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	arm.shape = probe
	cam = Camera3D.new()
	base_fov = Settings.fov()
	cam.fov = base_fov
	cam.far = 600.0
	arm.add_child(cam)
	cam.current = true


func set_target(t: Node3D) -> void:
	target = t
	if t is CollisionObject3D:
		arm.add_excluded_object((t as CollisionObject3D).get_rid())
	_pos = t.global_position + Vector3.UP * height
	global_position = _pos


func shake(amount: float) -> void:
	_trauma = clampf(maxf(_trauma, amount * float(Settings.shake_scale())), 0.0, 1.5)


## Called by the avatar on touchdown with the downward speed at impact.
func land(impact: float) -> void:
	_bump_v -= clampf(impact / 18.0, 0.0, 1.6) * 3.2
	if impact > 20.0:
		shake(clampf((impact - 20.0) / 25.0, 0.1, 0.6))


func jumped() -> void:
	_bump_v += 0.9


func _pad_look(delta: float) -> void:
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if v == Vector2.ZERO:
		return
	v *= v.length()  # response curve: fine aim near centre, fast turns at full tilt
	var speed := 3.2 * float(Settings.g("controls", "pad_look"))
	var inv := -1.0 if Settings.g("controls", "invert_y") else 1.0
	yaw -= v.x * speed * delta
	pitch = clampf(pitch - v.y * speed * 0.7 * inv * delta, -1.35, 0.7)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		var sens: float = Settings.sensitivity()
		var inv := -1.0 if Settings.g("controls", "invert_y") else 1.0
		var hex := target as Avatar
		if hex and is_instance_valid(hex):
			if hex.hexed("invert"):
				inv = -inv
			if hex.hexed("espresso"):
				sens *= 4.0
		yaw -= m.relative.x * sens
		pitch = clampf(pitch - m.relative.y * sens * inv, -1.35, 0.7)


func _process(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pad_look(delta)
	base_fov = Settings.fov()
	var av := target as Avatar
	var vel := Vector3.ZERO
	var on_floor := true
	var sprint := 0.0
	var phase := 0.0
	var move := 0.0
	var s := 1.0
	if av and is_instance_valid(av):
		vel = av.velocity if av.controls() else av.net_velocity
		on_floor = av.floor_vis
		sprint = av.sprint_k
		phase = av.anim_phase
		move = av.move_amt
		s = av.size
	if is_instance_valid(target):
		var goal := target.global_position + Vector3.UP * height
		var kh := 1.0 - exp(-18.0 * delta)
		var fall_speed := maxf(0.0, -vel.y)
		var kv := 1.0 - exp(-(7.0 + fall_speed * 0.9) * delta)
		_pos.x = lerpf(_pos.x, goal.x, kh)
		_pos.z = lerpf(_pos.z, goal.z, kh)
		_pos.y = lerpf(_pos.y, goal.y, kv)
		if _pos.distance_to(goal) > 25.0:
			_pos = goal

	# landing / jump spring
	_bump_v += (-_bump * 90.0 - _bump_v * 11.0) * delta
	_bump += _bump_v * delta
	_bump = clampf(_bump, -0.6, 0.4)

	# bob: tiny vertical bounce per step, half-rate sideways sway
	var bob_amp := 0.03 * clampf(move, 0.0, 1.2) * (1.0 + sprint * 0.8) * sqrt(s) * float(Settings.bob_scale()) if on_floor else 0.0
	var bob_y := absf(sin(phase)) * bob_amp
	var bob_x := sin(phase * 0.5) * bob_amp * 0.6

	var hv := Vector3(vel.x, 0, vel.z)
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var lateral := clampf(hv.dot(right) / (8.0 * maxf(s, 1.0)), -1.0, 1.0)
	_roll = lerpf(_roll, -lateral * 0.035, clampf(delta * 5.0, 0.0, 1.0))

	var fall := clampf((-vel.y - 9.0) / 22.0, 0.0, 1.0)
	_fall_k = lerpf(_fall_k, fall, clampf(delta * 3.0, 0.0, 1.0))
	var speed_k := clampf(hv.length() / (9.0 * maxf(s, 1.0)), 0.0, 1.3)
	_fov_k = lerpf(_fov_k, sprint * speed_k, clampf(delta * 4.0, 0.0, 1.0))
	cam.fov = base_fov + 9.0 * _fov_k + 12.0 * _fall_k

	var roll := _roll
	var wob_yaw := 0.0
	if wobble > 0.0:
		wobble -= delta
		var t := Time.get_ticks_msec() * 0.002
		roll += sin(t * 1.3) * 0.18
		wob_yaw = sin(t * 0.9) * delta * 0.6
	yaw += wob_yaw
	global_position = _pos + Vector3(0, _bump + bob_y, 0)
	rotation = Vector3(pitch - 0.25 * _fall_k, yaw, roll)
	arm.spring_length = distance * (1.0 + 0.3 * _fall_k)

	# trauma shake: smooth noise, quadratic falloff
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	_noise_t += delta * 30.0
	var sh := _trauma * _trauma
	cam.h_offset = bob_x + sh * 0.5 * (sin(_noise_t * 1.1) + sin(_noise_t * 2.3) * 0.5)
	cam.v_offset = sh * 0.5 * (sin(_noise_t * 1.7 + 1.0) + sin(_noise_t * 3.1) * 0.5)
	cam.rotation.z = sh * 0.06 * sin(_noise_t * 1.3)


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func aim_dir() -> Vector3:
	return -cam.global_transform.basis.z


## World point under the crosshair (mask: world + avatars + props), excluding `skip`.
func aim_point(skip: Array[RID] = [], max_dist := 250.0) -> Vector3:
	var from := cam.global_position
	var to := from + aim_dir() * max_dist
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, skip)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else to
