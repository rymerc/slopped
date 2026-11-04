class_name Prop
extends RigidBody3D
## A physics object that can be pushed, knocked over, picked up and thrown.
## Host simulates it; clients keep it kinematic and interpolate (PropSystem).
##   solid props (layer 3 / 4):  avatars collide with + stand on them
##   light props (layer 4 / 8):  avatars walk through and kick them around

const KINDS := {
	"crate": {"mass": 6.0, "box": Vector3(1, 1, 1), "solid": true},
	"crate_s": {"mass": 2.5, "box": Vector3(0.6, 0.6, 0.6), "solid": true},
	"barrel": {"mass": 5.0, "cyl": Vector2(0.4, 1.0), "solid": true},
	"tnt": {"mass": 4.0, "cyl": Vector2(0.38, 0.95), "solid": true, "explosive": true},
	"ball": {"mass": 0.6, "sphere": 0.45, "bounce": 0.8, "solid": false},
	"big_ball": {"mass": 10.0, "sphere": 1.3, "bounce": 0.55, "solid": true},
	"cone": {"mass": 0.5, "cyl": Vector2(0.24, 0.7), "solid": false},
	"plank": {"mass": 3.0, "box": Vector3(3.0, 0.15, 0.45), "solid": true},
	"pin": {"mass": 0.8, "cyl": Vector2(0.17, 0.9), "solid": false},
	"duck": {"mass": 0.4, "sphere": 0.32, "bounce": 0.5, "solid": false},
	"beam": {"mass": 9.0, "box": Vector3(4.0, 0.3, 0.3), "solid": true},
}

var id := 0
var kind := "crate"
var holder := 0
var radius := 0.5
var explosive := false
var solid := true
var home: Transform3D
var thrown_by := 0
var thrown_t := 99.0
var gone := false  # exploded / respawning
var vel_est := Vector3.ZERO
var system: Node
var trail: CPUParticles3D

var _net_pos := Vector3.ZERO
var _net_rot := Quaternion.IDENTITY
var _prev_pos := Vector3.ZERO
var _prev_speed := 0.0
var _sound_cd := 0.0
var _snap := 1.0
var _snap_from := Vector3.ZERO


func setup(k: String) -> void:
	kind = k
	var d: Dictionary = KINDS[k]
	mass = float(d.mass)
	solid = bool(d.get("solid", true))
	explosive = bool(d.get("explosive", false))
	collision_layer = 4 if solid else 8
	collision_mask = 1 | 4 | 8 | 16
	var pm := PhysicsMaterial.new()
	pm.bounce = float(d.get("bounce", 0.15))
	pm.friction = 0.7
	physics_material_override = pm
	can_sleep = true
	continuous_cd = mass < 1.0
	angular_damp = 0.6
	var cs := CollisionShape3D.new()
	if d.has("box"):
		var b := BoxShape3D.new()
		b.size = d.box
		cs.shape = b
		radius = (d.box as Vector3).length() * 0.4
	elif d.has("cyl"):
		var c := CylinderShape3D.new()
		c.radius = (d.cyl as Vector2).x
		c.height = (d.cyl as Vector2).y
		cs.shape = c
		radius = maxf(c.radius, c.height * 0.5)
	else:
		var s := SphereShape3D.new()
		s.radius = float(d.sphere)
		cs.shape = s
		radius = s.radius
	add_child(cs)
	_build_visual()
	trail = Fx.trail(self, Color.WHITE, clampf(radius * 0.25, 0.06, 0.2))


func _build_visual() -> void:
	match kind:
		"crate", "crate_s":
			var s: float = (KINDS[kind].box as Vector3).x
			Art.part(self, Art.bbox(Vector3.ONE * s, 0.12), Color("#c98a4b"))
			for ax: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
				for side: float in [-1.0, 1.0]:
					var p := ax * s * 0.505 * side
					var sz := Vector3(0.02, s * 0.98, s * 0.18) if ax.x != 0.0 else Vector3(s * 0.18, s * 0.98, 0.02)
					Art.part(self, Art.box(sz), Color("#8f5a2f"), p, Vector3.ONE, Vector3(0, 0, 45) if ax.x == 0.0 else Vector3(45, 0, 0))
		"barrel":
			Art.part(self, Art.cyl(0.4, 0.4, 1.0, 8), Color("#3d8bd9"))
			for y: float in [-0.32, 0.32]:
				Art.part(self, Art.cyl(0.415, 0.415, 0.08, 8), Art.P_STEEL, Vector3(0, y, 0))
		"tnt":
			Art.part(self, Art.cyl(0.38, 0.38, 0.95, 8), Art.P_RED)
			Art.part(self, Art.cyl(0.39, 0.39, 0.2, 8), Art.P_HAZARD, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false, 0.3)
			Art.part(self, Art.cyl(0.03, 0.03, 0.25, 4), Art.INK, Vector3(0, 0.58, 0))
			Art.label(self, "TNT", Vector3(0, 0, -0.4), 0.008, Color.WHITE, false).rotation.y = 0.0
		"ball":
			var cols := [Art.P_RED, Color.WHITE, Art.P_BLUE, Art.P_HAZARD]
			Art.part(self, Art.sphere(0.45, 8), cols[id % cols.size()])
			Art.part(self, Art.sphere(0.46, 8), Color.WHITE, Vector3.ZERO, Vector3(0.25, 1.0, 1.0))
		"big_ball":
			Art.part(self, Art.sphere(1.3, 9), Art.P_PINK)
			Art.part(self, Art.sphere(1.32, 9), Art.P_HAZARD, Vector3.ZERO, Vector3(1.0, 0.2, 1.0))
		"cone":
			Art.part(self, Art.cyl(0.03, 0.24, 0.7, 7), Art.P_ORANGE)
			Art.part(self, Art.cyl(0.11, 0.15, 0.12, 7), Color.WHITE, Vector3(0, 0.05, 0))
			Art.part(self, Art.box(Vector3(0.52, 0.06, 0.52)), Art.P_ORANGE, Vector3(0, -0.32, 0))
		"plank":
			Art.part(self, Art.bbox(Vector3(3.0, 0.15, 0.45), 0.2), Color("#d9a865"))
		"pin":
			Art.part(self, Art.cyl(0.08, 0.17, 0.6, 7), Color.WHITE, Vector3(0, -0.15, 0))
			Art.part(self, Art.sphere(0.12, 6), Color.WHITE, Vector3(0, 0.33, 0))
			Art.part(self, Art.cyl(0.085, 0.085, 0.06, 7), Art.P_RED, Vector3(0, 0.15, 0))
		"duck":
			Art.part(self, Art.sphere(0.32, 7), Ui.YELLOW, Vector3(0, -0.05, 0), Vector3(1.15, 0.85, 1.0))
			Art.part(self, Art.sphere(0.2, 6), Ui.YELLOW, Vector3(0, 0.22, -0.16))
			Art.part(self, Art.box(Vector3(0.14, 0.05, 0.14)), Art.P_ORANGE, Vector3(0, 0.2, -0.36))
			for sx: float in [-1.0, 1.0]:
				Art.part(self, Art.sphere(0.035, 4), Art.INK, Vector3(0.09 * sx, 0.28, -0.32))
		"beam":
			Art.part(self, Art.box(Vector3(4.0, 0.3, 0.3)), Art.P_RED.darkened(0.1), Vector3.ZERO, Vector3.ONE, Vector3.ZERO,
				false, 0.0).material_override = Art.mat(Art.P_RED.darkened(0.1), false, 0.0, 0.6)


func request_bump(v: Vector3, at: Vector3) -> void:
	if system and holder == 0 and not gone:
		system.call("bump", self, v, at)


func can_grab(av: Avatar) -> bool:
	return holder == 0 and not gone and mass <= 7.0 * av.size * av.size


func hold_point(av: Avatar) -> Vector3:
	return av.global_position + av.forward() * (0.32 * av.size + radius + 0.15) + Vector3.UP * (0.95 * av.size)


func set_net(p: Vector3, r: Quaternion) -> void:
	_net_pos = p
	_net_rot = r


func begin_hold() -> void:
	_snap = 0.0
	_snap_from = global_position
	collision_layer = 0
	collision_mask = 0
	freeze = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.25, 0.06)
	tw.tween_property(self, "scale", Vector3.ONE, 0.1)


func end_hold() -> void:
	collision_layer = 4 if solid else 8
	collision_mask = 1 | 4 | 8 | 16
	_net_pos = global_position
	_net_rot = global_transform.basis.get_rotation_quaternion()


## Per-tick visuals that every peer runs: holding, interpolation, trail, impact sounds.
func tick(delta: float, is_host: bool, av: Avatar) -> void:
	thrown_t += delta
	_sound_cd -= delta
	if holder != 0 and av:
		_snap = minf(1.0, _snap + delta / 0.12)
		var target := hold_point(av)
		global_position = _snap_from.lerp(target, ease(_snap, -2.0)) if _snap < 1.0 else target
		global_rotation = Vector3(0, av.facing, 0)
	elif not is_host and not gone:
		var k := clampf(delta * 15.0, 0.0, 1.0)
		if global_position.distance_to(_net_pos) > 10.0:
			k = 1.0
		var q := global_transform.basis.get_rotation_quaternion().slerp(_net_rot, k)
		global_transform = Transform3D(Basis(q), global_position.lerp(_net_pos, k))
	vel_est = (global_position - _prev_pos) / maxf(delta, 0.0001)
	_prev_pos = global_position
	var sp := vel_est.length()
	if trail:
		trail.emitting = holder == 0 and thrown_t < 2.0 and sp > 6.0
	if holder == 0 and _prev_speed > 4.0 and sp < _prev_speed * 0.55 and _sound_cd <= 0.0:
		_sound_cd = 0.15
		var snd := "boing" if kind in ["ball", "big_ball", "duck"] else ("knock" if mass < 7.0 else "thud")
		Sfx.at(self, snd, global_position, linear_to_db(clampf(_prev_speed / 12.0, 0.15, 1.2)) - 2.0, 0.15,
			clampf(1.6 / sqrt(mass), 0.5, 1.8))
		if _prev_speed > 8.0:
			Fx.dust(get_parent(), global_position - Vector3.UP * radius * 0.8, clampf(_prev_speed / 14.0, 0.3, 1.0))
	_prev_speed = sp
