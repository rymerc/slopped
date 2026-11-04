class_name Ragdoll
extends Node3D
## Physics ragdoll built on the fly from a Chars rig. The rig's own limb nodes
## (meshes and all) are reparented onto RigidBody3Ds joined by cone-twist
## joints, so whatever the character was doing at impact is the starting pose.
## `restore()` hands the limbs back to the rig and returns their poses so the
## avatar can blend from "where the body landed" into the get-up animation.
##
## Only spawned on impact: normal movement never pays for this.
## Layer 5 (16): collides with world + props, not with avatars or itself.

const LAYER := 16
const MASK := 1 | 4 | 8
const ORDER := ["torso", "head", "arm_l", "arm_r", "leg_l", "leg_r"]
# [box size, centre offset from the joint, mass, swing limit deg]
const DEFS := {
	"torso": [Vector3(0.5, 0.52, 0.34), Vector3(0, 0.24, 0), 3.0, 0.0],
	"head": [Vector3(0.6, 0.54, 0.52), Vector3(0, 0.29, 0), 1.2, 45.0],
	"arm_l": [Vector3(0.14, 0.42, 0.14), Vector3(0, -0.2, 0), 0.4, 100.0],
	"arm_r": [Vector3(0.14, 0.42, 0.14), Vector3(0, -0.2, 0), 0.4, 100.0],
	"leg_l": [Vector3(0.17, 0.42, 0.19), Vector3(0, -0.2, 0), 0.6, 70.0],
	"leg_r": [Vector3(0.17, 0.42, 0.19), Vector3(0, -0.2, 0), 0.6, 70.0],
}

static var _pmat: PhysicsMaterial

var parts: Dictionary
var bodies: Dictionary = {}
var size := 1.0
var follow := Vector3.ZERO
var use_follow := false
var age := 0.0
var _parents: Dictionary = {}


static func create(world: Node, rig: Dictionary, s: float, head_scale: float, vel: Vector3, impulse: Vector3) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "Ragdoll"
	r.parts = rig
	r.size = s
	world.add_child(r)
	r._build(head_scale, vel, impulse)
	return r


func _build(head_scale: float, vel: Vector3, impulse: Vector3) -> void:
	if _pmat == null:
		_pmat = PhysicsMaterial.new()
		_pmat.friction = 0.9
		_pmat.bounce = 0.15
	var limbs: Dictionary = parts.limbs
	var spin := impulse.length() * 0.6 + 2.0
	for n: String in ORDER:
		var limb: Node3D = limbs[n]
		var def: Array = DEFS[n]
		var k := size * (head_scale if n == "head" else 1.0)
		var b := RigidBody3D.new()
		b.name = n
		b.collision_layer = LAYER
		b.collision_mask = MASK
		b.mass = float(def[2]) * size * size
		b.physics_material_override = _pmat
		b.linear_damp = 0.1
		b.angular_damp = 1.2
		b.continuous_cd = true
		add_child(b)
		var xf := limb.global_transform
		b.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = (def[0] as Vector3) * k
		cs.shape = sh
		cs.position = (def[1] as Vector3) * k
		b.add_child(cs)
		_parents[n] = limb.get_parent()
		limb.reparent(b, true)
		var kick := 1.0 if n == "torso" else randf_range(0.9, 1.4)
		b.linear_velocity = vel + impulse * kick + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * 0.6
		b.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spin
		bodies[n] = b
	for n: String in ORDER:
		if n == "torso":
			continue
		var j := ConeTwistJoint3D.new()
		add_child(j)
		j.global_transform = Transform3D(Basis(), (bodies[n] as Node3D).global_position)
		j.node_a = j.get_path_to(bodies.torso)
		j.node_b = j.get_path_to(bodies[n])
		j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(float((DEFS[n] as Array)[3])))
		j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(35.0))
		j.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)


func _physics_process(delta: float) -> void:
	age += delta
	if use_follow and bodies.has("torso"):
		var t: RigidBody3D = bodies.torso
		var err := follow - t.global_position
		if err.length() > 5.0:
			_shift(err)
		else:
			t.apply_central_force((err * 40.0 - t.linear_velocity * 4.0) * t.mass)


func _shift(by: Vector3) -> void:
	for b: RigidBody3D in bodies.values():
		b.global_position += by


func torso() -> RigidBody3D:
	return bodies.get("torso")


func torso_pos() -> Vector3:
	return torso().global_position


func speed() -> float:
	var s := 0.0
	for b: RigidBody3D in bodies.values():
		s = maxf(s, b.linear_velocity.length())
	return s


func kick(impulse: Vector3) -> void:
	for b: RigidBody3D in bodies.values():
		b.linear_velocity += impulse * randf_range(0.8, 1.2)


## Returns limbs to the rig (keeping their current global pose) and frees the
## ragdoll. Result: limb name -> local Transform3D under its original parent.
func restore() -> Dictionary:
	var out := {}
	var limbs: Dictionary = parts.limbs
	for n: String in ORDER:
		var limb: Node3D = limbs[n]
		var p: Node3D = _parents[n]
		if is_instance_valid(limb) and is_instance_valid(p):
			limb.reparent(p, true)
			out[n] = limb.transform
	queue_free()
	return out
