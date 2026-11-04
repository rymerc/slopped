class_name CamRig
extends Node3D
## Third-person orbit camera. Follows `target`, mouse controls yaw/pitch.

var target: Node3D
var yaw := 0.0
var pitch := -0.3
var distance := 5.0
var height := 1.6
var sensitivity := 0.0025
var wobble := 0.0  # drunk camera, seconds remaining
var _shake := 0.0
var arm: SpringArm3D
var cam: Camera3D


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	arm.margin = 0.3
	add_child(arm)
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	arm.shape = probe
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.far = 400.0
	arm.add_child(cam)
	cam.current = true


func set_target(t: Node3D) -> void:
	target = t
	if t is CollisionObject3D:
		arm.add_excluded_object((t as CollisionObject3D).get_rid())
	global_position = t.global_position + Vector3.UP * height


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		yaw -= m.relative.x * sensitivity
		pitch = clampf(pitch - m.relative.y * sensitivity, -1.35, 0.7)


func _process(delta: float) -> void:
	if is_instance_valid(target):
		var goal := target.global_position + Vector3.UP * height
		global_position = global_position.lerp(goal, clampf(delta * 14.0, 0.0, 1.0))
	var roll := 0.0
	if wobble > 0.0:
		wobble -= delta
		var t := Time.get_ticks_msec() * 0.002
		roll = sin(t * 1.3) * 0.18
		yaw += sin(t * 0.9) * delta * 0.6
	rotation = Vector3(pitch, yaw, roll)
	arm.spring_length = distance
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.4
		cam.v_offset = randf_range(-1, 1) * _shake * 0.4
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func aim_dir() -> Vector3:
	return -cam.global_transform.basis.z


## World point under the crosshair (mask: world + avatars), excluding `skip`.
func aim_point(skip: Array[RID] = [], max_dist := 250.0) -> Vector3:
	var from := cam.global_position
	var to := from + aim_dir() * max_dist
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, skip)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else to
