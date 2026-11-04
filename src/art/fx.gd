class_name Fx
extends RefCounted
## Game-juice effects shared by every world: dust puffs, impact stars,
## confetti, explosions, trails, floating text. CPUParticles3D with low-poly
## meshes that shrink to nothing (no alpha, no textures: matches the style and
## runs on the Compatibility renderer).

static var _shrink: Curve


static func _curve() -> Curve:
	if _shrink == null:
		_shrink = Curve.new()
		_shrink.add_point(Vector2(0, 0.6))
		_shrink.add_point(Vector2(0.15, 1.0))
		_shrink.add_point(Vector2(1, 0))
	return _shrink


static func _burst(root: Node, pos: Vector3, color: Color, amount: int, size: float, speed: float,
		life: float, spread := 70.0, gravity := -4.0, dir := Vector3.UP, glow := 0.0) -> CPUParticles3D:
	if root == null or not root.is_inside_tree():
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.mesh = Art.sphere(size, 5)
	p.material_override = Art.mat(color, false, glow)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _curve()
	p.angular_velocity_min = -200
	p.angular_velocity_max = 200
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	root.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	return p


## Ground dust ring (landing, skids, footsteps).
static func dust(root: Node, pos: Vector3, power := 1.0, color := Color("#e9dcc0")) -> void:
	var p := _burst(root, pos + Vector3.UP * 0.05, color, int(6 + 10 * power), 0.12 + 0.1 * power,
		2.0 + 3.0 * power, 0.45 + 0.2 * power, 85.0, -1.0)
	if p:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 0.3 * power
		p.emission_ring_inner_radius = 0.1
		p.emission_ring_height = 0.05


static func step(root: Node, pos: Vector3) -> void:
	_burst(root, pos + Vector3.UP * 0.05, Color("#e9dcc0"), 3, 0.08, 1.2, 0.3, 60.0, -1.0)


## Impact: white puff + yellow stars.
static func impact(root: Node, pos: Vector3, power := 1.0) -> void:
	_burst(root, pos, Color.WHITE, int(5 + 6 * power), 0.1 + 0.06 * power, 4.0 * power + 2.0, 0.3, 180.0, 0.0)
	_burst(root, pos, Art.GOLD, int(3 + 3 * power), 0.07, 5.0 * power + 2.0, 0.45, 180.0, -6.0, Vector3.UP, 0.8)


static func confetti(root: Node, pos: Vector3, amount := 30) -> void:
	for c: Color in [Art.P_PINK, Art.GOLD, Art.P_BLUE, Art.P_GRASS_LIGHT]:
		_burst(root, pos, c, amount / 4, 0.07, 7.0, 1.3, 60.0, -9.0, Vector3.UP, 0.3)


static func splash(root: Node, pos: Vector3) -> void:
	_burst(root, pos, Color("#bff0ff"), 18, 0.16, 7.0, 0.7, 35.0, -14.0, Vector3.UP, 0.3)


static func explosion(root: Node, pos: Vector3, r := 5.0) -> void:
	_burst(root, pos, Color("#fff2a8"), 14, 0.45 * r / 5.0, 9.0, 0.35, 180.0, 0.0, Vector3.UP, 2.5)
	_burst(root, pos, Art.P_ORANGE, 18, 0.55 * r / 5.0, 12.0, 0.6, 180.0, 0.0, Vector3.UP, 1.4)
	_burst(root, pos, Color("#5a5068"), 14, 0.6 * r / 5.0, 5.0, 1.2, 70.0, 3.0)
	if root and root.is_inside_tree():
		var flash := OmniLight3D.new()
		flash.light_color = Color("#ffcf7a")
		flash.light_energy = 6.0
		flash.omni_range = r * 3.0
		root.add_child(flash)
		flash.global_position = pos + Vector3.UP
		var tw := flash.create_tween()
		tw.tween_property(flash, "light_energy", 0.0, 0.35)
		tw.tween_callback(flash.queue_free)


## Continuous trail for thrown objects / fast slides. Caller toggles `emitting`.
static func trail(parent: Node3D, color := Color.WHITE, size := 0.1) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.35
	p.local_coords = false
	p.mesh = Art.sphere(size, 4)
	p.material_override = Art.mat(color, false, 0.4)
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.4
	p.gravity = Vector3.ZERO
	p.scale_amount_curve = _curve()
	p.emitting = false
	parent.add_child(p)
	return p


static func text(root: Node, pos: Vector3, msg: String, color := Color.WHITE, px := 0.018, rise := 1.6, life := 1.1) -> void:
	if root == null or not root.is_inside_tree():
		return
	var n := Node3D.new()
	root.add_child(n)
	n.global_position = pos
	var l := Art.label(n, msg, Vector3.ZERO, px, color)
	l.no_depth_test = true
	n.scale = Vector3.ONE * 0.3
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "position:y", n.position.y + rise, life)
	tw.tween_callback(n.queue_free)


## Dizzy stars that orbit a node for `secs`.
static func dizzy(parent: Node3D, height: float, secs := 2.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var ring := Node3D.new()
	ring.name = "Dizzy"
	ring.position.y = height
	parent.add_child(ring)
	for i in 3:
		var a := TAU * i / 3.0
		Art.part(ring, Art.sphere(0.07, 4), Art.GOLD, Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), Vector3.ONE,
			Vector3.ZERO, false, 1.0)
	var tw := ring.create_tween()
	tw.tween_property(ring, "rotation:y", TAU * secs * 1.5, secs)
	tw.tween_callback(ring.queue_free)


## Soft dark disc that follows a body on the ground: cheap contact shadow /
## ambient occlusion so jumps and props read clearly.
static func blob_shadow(parent: Node3D, radius: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "Blob"
	m.mesh = Art.cyl(radius, radius, 0.01, 12)
	m.material_override = Art.shadow_mat()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.top_level = true
	parent.add_child(m)
	return m
