class_name Dress
extends RefCounted
## Set dressing helpers. Everything placed here is static: geometry goes into the
## world Batch, and collision (when asked for) is the cheapest shape that fits.
##   put()      a kit mesh, optional box collider from its bounds
##   tree()     a kit mesh with a trunk-only cylinder collider
##   bulbs() / bunting()   catenary strings between two points

const COL_NONE := 0
const COL_BOX := 1


static func xf(pos: Vector3, yaw_deg := 0.0, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * s), pos)


## detail=true puts it on the no-shadow, distance-culled layer (small clutter).
static func put(root: Node3D, b: Batch, id: String, pos: Vector3, yaw_deg := 0.0, s := 1.0,
		col := COL_NONE, detail := false) -> void:
	var t := xf(pos, yaw_deg, s)
	b.add(Kit.mesh(id), t, detail)
	if col == COL_BOX:
		box_collider(root, t, Kit.aabb(id))


static func box_collider(root: Node3D, t: Transform3D, box: AABB) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var s := t.basis.get_scale()
	body.global_transform = Transform3D(t.basis.orthonormalized(), t * box.get_center())
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size * s
	cs.shape = sh
	body.add_child(cs)


static func tree(root: Node3D, b: Batch, id: String, pos: Vector3, yaw_deg: float, s: float, trunk := 0.3) -> void:
	b.add(Kit.mesh(id), xf(pos, yaw_deg, s))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	body.position = pos + Vector3.UP * 1.5
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = trunk
	sh.height = 3.0
	cs.shape = sh
	body.add_child(cs)


## A warm bulb string sagging between two points.
static func bulbs(b: Batch, a: Vector3, c: Vector3, n: int, sag := 1.2, cols: Array = [Color("#ffe6a8")]) -> void:
	var bulb := Art.sphere(0.09, 6)
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(c, t) + Vector3.DOWN * sin(t * PI) * sag
		var col: Color = cols[i % cols.size()]
		b.add(bulb, Transform3D(Basis.IDENTITY, p), true, col.srgb_to_linear(), 1.0)


## Festival pennants on a line.
static func bunting(b: Batch, a: Vector3, c: Vector3, n: int, sag := 1.0) -> void:
	var cols := [Art.P_RED, Art.GOLD, Art.P_BLUE, Art.P_CREAM, Art.P_PINK]
	var flag := _pennant()
	var dir := (c - a).normalized()
	var yaw := atan2(-dir.z, dir.x)
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(c, t) + Vector3.DOWN * sin(t * PI) * sag
		var col: Color = cols[i % cols.size()]
		b.add(flag, Transform3D(Basis(Vector3.UP, yaw), p), true, col.srgb_to_linear())


static var _pen: ArrayMesh


static func _pennant() -> ArrayMesh:
	if _pen:
		return _pen
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(-0.28, 0, 0), Vector3(0, -0.6, 0), Vector3(0.28, 0, 0)]
	for tri: Array in [[pts[0], pts[1], pts[2]], [pts[2], pts[1], pts[0]]]:
		for v: Vector3 in tri:
			st.set_normal(Vector3.BACK)
			st.add_vertex(v)
	_pen = st.commit()
	return _pen
