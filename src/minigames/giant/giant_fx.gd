class_name GiantFx
extends RefCounted
## Throwaway visual effects built from primitives + tweens. No particles, no
## textures: cheap enough for potato PCs.


static func _temp(root: Node3D, pos: Vector3, life: float) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	n.position = pos
	root.get_tree().create_timer(life).timeout.connect(n.queue_free)
	return n


static func warn(root: Node3D, pos: Vector3, r: float) -> void:
	var n := _temp(root, pos + Vector3.UP * 0.05, 0.6)
	var m := Art.part(n, Art.cyl(r, r, 0.05, 20), Color("#e63946"), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false, 1.0)
	m.transparency = 0.5
	n.scale = Vector3(0.2, 1, 0.2)
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.3)


static func dust(root: Node3D, pos: Vector3, r: float) -> void:
	var n := _temp(root, pos + Vector3.UP * 0.1, 0.6)
	for i in 8:
		var a := TAU * i / 8.0
		Art.part(n, Art.sphere(0.25 * r, 6), Color("#d9c3a0"), Vector3(cos(a), 0.2, sin(a)) * r * 0.5)
	n.create_tween().tween_property(n, "scale", Vector3(1.8, 0.4, 1.8), 0.5).set_ease(Tween.EASE_OUT)


static func slap(root: Node3D, pos: Vector3, r: float) -> void:
	dust(root, pos, r)
	var n := _temp(root, pos + Vector3.UP * 0.1, 0.5)
	var ring := Art.part(n, Art.cyl(r, r, 0.15, 24), Color("#fff6e8"), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false, 1.5)
	ring.transparency = 0.4
	var hand := _temp(root, pos + Vector3.UP * r * 1.5, 0.5)
	Art.part(hand, Art.box(Vector3(r * 0.9, r * 0.25, r * 1.1)), Color("#ffb38a"))
	hand.create_tween().tween_property(hand, "position:y", pos.y + r * 0.12, 0.12)


static func ice(root: Node3D, pos: Vector3, r: float, dur: float) -> void:
	var n := _temp(root, pos + Vector3.UP * 0.04, dur)
	var m := Art.part(n, Art.cyl(r, r, 0.06, 18), Color("#bff4ff"), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false, 0.6)
	m.transparency = 0.25
	n.scale = Vector3(0.1, 1, 0.1)
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.6)


static func pee(root: Node3D, pos: Vector3, yaw: float, sf: float) -> void:
	var n := _temp(root, pos, 0.9)
	n.rotation.y = yaw
	for i in 10:
		var t := i / 9.0
		var p := Vector3(0, (1.0 - t * t) * 2.6 * sf + 0.2, -t * 4.0 * sf)
		Art.part(n, Art.sphere(0.12 * sf + 0.05, 5), Color("#fff27a"), p, Vector3.ONE, Vector3.ZERO, false, 0.8)
	text(root, pos + Vector3.UP * 7.0 * sf, "*psssss*", Color("#bff4ff"))


static func fart(root: Node3D, pos: Vector3, yaw: float, sf: float) -> void:
	var n := _temp(root, pos + Vector3.UP * 1.0 * sf, 0.7)
	n.rotation.y = yaw
	for i in 7:
		var spread := Vector3(randf_range(-1, 1) * i * 0.35, randf_range(0, 0.4) * i * 0.3, 1.4 * i) * sf
		var c := Color("#ff7a3d").lerp(Color("#ffd23f"), randf())
		Art.part(n, Art.sphere((0.5 + i * 0.25) * sf, 6), c, spread, Vector3.ONE, Vector3.ZERO, false, 2.0)
	n.scale = Vector3.ONE * 0.3
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
	text(root, pos + Vector3.UP * 5.0 * sf, "PFFFRRRT", Color("#ff7a3d"))


static func burst(root: Node3D, pos: Vector3, color: Color) -> void:
	var n := _temp(root, pos, 0.4)
	for i in 6:
		var d := Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)).normalized()
		var m := Art.part(n, Art.sphere(0.12, 5), color, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false, 1.2)
		m.create_tween().tween_property(m, "position", d * 1.2, 0.35)


static func text(root: Node3D, pos: Vector3, msg: String, color: Color) -> void:
	var n := _temp(root, pos, 1.2)
	Art.label(n, msg, Vector3.ZERO, 0.02, color)
	n.create_tween().tween_property(n, "position:y", pos.y + 2.0, 1.2)
