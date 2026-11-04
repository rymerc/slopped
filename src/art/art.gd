class_name Art
extends RefCounted
## The whole art style lives here: low-poly primitives + one toon shader +
## inverted-hull outlines. No textures; colour is a material uniform.
## Materials and meshes are cached so identical parts share GPU resources.

const TOON := preload("res://src/art/toon.gdshader")
const OUTLINE := preload("res://src/art/outline.gdshader")

const HATS := ["none", "party", "top", "propeller", "bucket", "traffic", "chef"]
const BODIES := ["bean", "box", "pear"]
const SWATCHES := [
	Color("#ff5fa2"), Color("#ffd23f"), Color("#3ec1ff"), Color("#8ce36b"),
	Color("#b388ff"), Color("#ff7a3d"), Color("#f2f2f2"), Color("#4a4e69"),
]

const INK := Color(0.09, 0.06, 0.12)
const SHOE := Color(0.18, 0.14, 0.2)
const WOOD := Color("#9c6b43")
const GOLD := Color("#ffcc33")

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _outline_mat: ShaderMaterial


# --- materials -------------------------------------------------------------

static func mat(color: Color, outline := true, glow := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s" % [color.to_html(), outline, glow]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_strength", glow)
	if outline:
		m.next_pass = _outline()
	_mats[key] = m
	return m


static func _outline() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE
	return _outline_mat


static func ghost_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.95, 1.0, 0.45)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# --- meshes (low segment counts on purpose) --------------------------------

static func box(size: Vector3) -> Mesh:
	var key := "box%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func sphere(r: float, segs := 10) -> Mesh:
	var key := "sph%s_%d" % [r, segs]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = maxi(3, segs / 2)
		_meshes[key] = m
	return _meshes[key]


static func cyl(top: float, bottom: float, h: float, segs := 10) -> Mesh:
	var key := "cyl%s_%s_%s_%d" % [top, bottom, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func capsule(r: float, h: float) -> Mesh:
	var key := "cap%s_%s" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 10
		m.rings = 4
		_meshes[key] = m
	return _meshes[key]


# --- node helpers ----------------------------------------------------------

static func part(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO,
		scl := Vector3.ONE, rot_deg := Vector3.ZERO, outline := true, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, outline, glow)
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Visible box with matching collision (world layer 1).
static func solid_box(parent: Node3D, size: Vector3, color: Color, pos: Vector3,
		outline := true, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	part(body, box(size), color, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, outline)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


static func solid_cyl(parent: Node3D, r: float, h: float, color: Color, pos: Vector3,
		top_r := -1.0, segs := 10) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	part(body, cyl(r if top_r < 0.0 else top_r, r, h, segs), color)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	body.add_child(cs)
	return body


static func label(parent: Node3D, text: String, pos: Vector3, px := 0.01,
		color := Color.WHITE, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = px
	l.font_size = 64
	l.outline_size = 18
	l.modulate = color
	l.outline_modulate = INK
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l


# --- characters ------------------------------------------------------------

## Builds a googly-eyed bean person. Origin at the feet, facing -Z.
## Returns handles to animated parts.
static func build_character(look: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Visual"
	var pivot := Node3D.new()
	root.add_child(pivot)
	var col: Color = look.get("color", Color.ORANGE)
	match str(look.get("body", "bean")):
		"box":
			part(pivot, box(Vector3(0.78, 0.95, 0.62)), col, Vector3(0, 0.72, 0))
		"pear":
			part(pivot, sphere(0.46), col, Vector3(0, 0.62, 0), Vector3(1.05, 1.15, 0.92))
		_:
			part(pivot, capsule(0.38, 1.1), col, Vector3(0, 0.75, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 1.42, 0)
	pivot.add_child(head)
	part(head, sphere(0.36), col.lightened(0.12))
	var eyes: Array = []
	for sx: float in [-1.0, 1.0]:
		var e := Node3D.new()
		e.position = Vector3(0.15 * sx, 0.07, -0.29)
		head.add_child(e)
		part(e, sphere(0.12, 8), Color.WHITE)
		var pupil := part(e, sphere(0.055, 6), INK, Vector3(0.0, 0.0, -0.09), Vector3.ONE, Vector3.ZERO, false)
		pupil.name = "Pupil"
		eyes.append(e)
	part(head, box(Vector3(0.16, 0.04, 0.04)), INK, Vector3(0, -0.14, -0.33), Vector3.ONE, Vector3.ZERO, false)
	var hands: Array = []
	for sx: float in [-1.0, 1.0]:
		hands.append(part(pivot, sphere(0.13, 8), col.darkened(0.12), Vector3(0.5 * sx, 0.72, 0)))
	var feet: Array = []
	for sx: float in [-1.0, 1.0]:
		feet.append(part(pivot, box(Vector3(0.2, 0.14, 0.34)), SHOE, Vector3(0.17 * sx, 0.07, -0.05)))
	var hat := build_hat(str(look.get("hat", "none")))
	if hat:
		hat.position = Vector3(0, 0.3, 0)
		head.add_child(hat)
	return {"root": root, "pivot": pivot, "head": head, "eyes": eyes,
		"hands": hands, "feet": feet, "hat": hat}


static func build_hat(kind: String) -> Node3D:
	if kind == "none":
		return null
	var h := Node3D.new()
	match kind:
		"party":
			part(h, cyl(0.0, 0.2, 0.5, 8), Color("#ff5fa2"), Vector3(0, 0.22, 0))
			part(h, sphere(0.07, 6), Color("#ffd23f"), Vector3(0, 0.48, 0))
		"top":
			part(h, cyl(0.34, 0.34, 0.04, 12), INK, Vector3(0, 0.0, 0))
			part(h, cyl(0.22, 0.22, 0.42, 12), INK, Vector3(0, 0.22, 0))
			part(h, cyl(0.225, 0.225, 0.07, 12), Color("#e63946"), Vector3(0, 0.06, 0), Vector3.ONE, Vector3.ZERO, false)
		"propeller":
			part(h, sphere(0.25, 10), Color("#3ec1ff"), Vector3(0, -0.06, 0), Vector3(1, 0.5, 1))
			part(h, cyl(0.02, 0.02, 0.2, 6), INK, Vector3(0, 0.12, 0))
			var spin := Node3D.new()
			spin.name = "Spin"
			spin.position = Vector3(0, 0.22, 0)
			h.add_child(spin)
			part(spin, box(Vector3(0.6, 0.02, 0.1)), Color("#ffd23f"))
		"bucket":
			part(h, cyl(0.21, 0.27, 0.32, 10), Color("#a8b2c1"), Vector3(0, 0.08, 0))
		"traffic":
			part(h, box(Vector3(0.46, 0.04, 0.46)), Color("#ff7a3d"), Vector3(0, -0.02, 0))
			part(h, cyl(0.03, 0.2, 0.6, 8), Color("#ff7a3d"), Vector3(0, 0.28, 0))
			part(h, cyl(0.12, 0.15, 0.1, 8), Color.WHITE, Vector3(0, 0.25, 0), Vector3.ONE, Vector3.ZERO, false)
		"chef":
			part(h, cyl(0.2, 0.2, 0.25, 10), Color.WHITE, Vector3(0, 0.08, 0))
			part(h, sphere(0.27, 10), Color.WHITE, Vector3(0, 0.3, 0), Vector3(1, 0.7, 1))
		"crown":
			part(h, cyl(0.24, 0.24, 0.16, 10), GOLD, Vector3(0, 0.03, 0), Vector3.ONE, Vector3.ZERO, true, 0.4)
			for i in 5:
				var a := TAU * i / 5.0
				part(h, cyl(0.0, 0.06, 0.16, 5), GOLD, Vector3(sin(a) * 0.21, 0.18, cos(a) * 0.21),
					Vector3.ONE, Vector3.ZERO, false, 0.4)
	return h


## Low-poly tree: trunk + stacked cones. Returns the static body.
static func tree(parent: Node3D, pos: Vector3, s := 1.0) -> StaticBody3D:
	var t := solid_cyl(parent, 0.35 * s, 2.4 * s, WOOD, pos + Vector3(0, 1.2 * s, 0), 0.25 * s, 6)
	var green := Color("#4caf50").lerp(Color("#8ce36b"), randf())
	part(t, cyl(0.0, 1.9 * s, 2.4 * s, 7), green, Vector3(0, 2.0 * s, 0))
	part(t, cyl(0.0, 1.4 * s, 2.0 * s, 7), green.lightened(0.1), Vector3(0, 3.2 * s, 0))
	return t


static func rock(parent: Node3D, pos: Vector3, s := 1.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.collision_mask = 0
	parent.add_child(b)
	part(b, sphere(1.0 * s, 6), Color("#8d8aa0"), Vector3.ZERO, Vector3(1.2, 0.7, 1.0),
		Vector3(0, randf() * 360.0, 0))
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.85 * s
	cs.shape = sh
	b.add_child(cs)
	return b


## A thin cylinder from a to b (ropes, beams).
static func beam(parent: Node3D, a: Vector3, b: Vector3, r: float, color: Color) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var d := b - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	n.transform = Transform3D(Basis.looking_at(d, up), (a + b) * 0.5)
	part(n, cyl(r, r, 1.0, 6), color, Vector3.ZERO, Vector3(1, d.length(), 1), Vector3(90, 0, 0))
	return n
