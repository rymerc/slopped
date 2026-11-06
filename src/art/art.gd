class_name Art
extends RefCounted
## The whole art style lives here: faceted low-poly primitives + one toon
## shader (flat-shaded, hemispheric ambient). No textures; colour is a material
## uniform drawn from ONE shared palette so everything belongs together.
## Materials and meshes are cached so identical parts share GPU resources.

const TOON := preload("res://src/art/toon.gdshader")
const WATER := preload("res://src/art/water.gdshader")
const SKY := preload("res://src/art/sky.gdshader")

const HATS := ["none", "party", "top", "propeller", "bucket", "traffic", "chef"]
const BODIES := Chars.KINDS
const SWATCHES := [
	Color("#ff5fa2"), Color("#ffd23f"), Color("#3ec1ff"), Color("#7ccf4e"),
	Color("#8b5cf6"), Color("#ff8a3d"), Color("#f2efe9"), Color("#4a4e69"),
]

# --- the palette (every world builds from these) ---------------------------
const INK := Color("#241a2e")
const SHOE := Color("#2f2838")
const WOOD := Color("#b0773f")
const GOLD := Color("#ffc935")
const SKIN := Color("#f1c49a")
const P_GRASS := Color("#74a950")
const P_GRASS_DARK := Color("#5a9148")
const P_GRASS_LIGHT := Color("#8fbd5e")
const P_DIRT := Color("#b39a7a")
const P_SAND := Color("#f0d48e")
const P_ROCK := Color("#a39cb3")
const P_ROCK_DARK := Color("#7b7390")
const P_BARK := Color("#8f5a35")
const P_LEAF_A := Color("#62b545")
const P_LEAF_B := Color("#86cc4c")
const P_LEAF_C := Color("#4c9c47")
const P_WATER := Color("#3a9fc0")
const P_STEEL := Color("#9aa6b8")
const P_HAZARD := Color("#ffc935")
const P_RED := Color("#ee4b4b")
const P_PINK := Color("#ff5fa2")
const P_BLUE := Color("#3ec1ff")
const P_PURPLE := Color("#8b5cf6")
const P_ORANGE := Color("#ff8a3d")
const P_CREAM := Color("#fff3dc")

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


# --- materials -------------------------------------------------------------

## `outline` is kept for call-site compatibility; the faceted style has none.
static func mat(color: Color, _outline := true, glow := 0.0, gloss := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s" % [color.to_html(), glow, gloss]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_strength", glow)
	m.set_shader_parameter("gloss", gloss)
	_mats[key] = m
	return m


static func vcol_mat() -> ShaderMaterial:
	if not _mats.has("vcol"):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("use_vertex_color", true)
		m.set_shader_parameter("rim_strength", 0.0)
		m.set_shader_parameter("grain", 0.22)
		_mats["vcol"] = m
	return _mats["vcol"]


## Grass and flowers: thin cross-blades would shade black with per-face normals, so
## they keep the up-facing normal baked into the mesh.
static func foliage_mat() -> ShaderMaterial:
	if not _mats.has("foliage"):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("use_vertex_color", true)
		m.set_shader_parameter("rim_strength", 0.0)
		m.set_shader_parameter("faceted", false)
		_mats["foliage"] = m
	return _mats["foliage"]


static func water_mat() -> ShaderMaterial:
	if not _mats.has("water"):
		var m := ShaderMaterial.new()
		m.shader = WATER
		_mats["water"] = m
	return _mats["water"]


static func shadow_mat() -> StandardMaterial3D:
	if not _mats.has("blob"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.1, 0.05, 0.2, 0.32)
		m.no_depth_test = false
		m.render_priority = 1
		_mats["blob"] = m
	return _mats["blob"]


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


## Chamfered box: 6 faces + 12 edge bevels + 8 corner tris. With faceted
## shading this is the signature chunky low-poly block (heads, bodies, crates).
static func bbox(size: Vector3, bevel := 0.18) -> Mesh:
	var key := "bb%s_%s" % [size, bevel]
	if _meshes.has(key):
		return _meshes[key]
	var h := size * 0.5
	# bevel is a fraction of the smallest half-extent
	var b := clampf(bevel, 0.0, 0.95) * minf(h.x, minf(h.y, h.z))
	# P(corner signs, axis at full extent)
	var pt := func(sx: float, sy: float, sz: float, ax: int) -> Vector3:
		var v := Vector3(sx * (h.x - b), sy * (h.y - b), sz * (h.z - b))
		v[ax] = [sx, sy, sz][ax] * h[ax]
		return v
	var polys: Array = []
	var signs := [-1.0, 1.0]
	for ax in 3:  # main faces
		for s: float in signs:
			var poly: Array = []
			for u: float in signs:
				for w: float in signs:
					var c := [0.0, 0.0, 0.0]
					c[ax] = s
					c[(ax + 1) % 3] = u
					c[(ax + 2) % 3] = w
					poly.append(pt.call(c[0], c[1], c[2], ax))
			polys.append(poly)
	for ax in 3:  # edges running along `ax`
		var b1 := (ax + 1) % 3
		var b2 := (ax + 2) % 3
		for s1: float in signs:
			for s2: float in signs:
				var poly: Array = []
				for sa: float in signs:
					var c := [0.0, 0.0, 0.0]
					c[ax] = sa
					c[b1] = s1
					c[b2] = s2
					poly.append(pt.call(c[0], c[1], c[2], b1))
					poly.append(pt.call(c[0], c[1], c[2], b2))
				polys.append(poly)
	for sx: float in signs:  # corners
		for sy: float in signs:
			for sz: float in signs:
				polys.append([pt.call(sx, sy, sz, 0), pt.call(sx, sy, sz, 1), pt.call(sx, sy, sz, 2)])
	var m := hull_mesh(polys)
	_meshes[key] = m
	return m


## Builds a mesh from convex polygons (unordered points). Each polygon is
## sorted around its centroid and wound clockwise seen from outside (Godot's
## front-face convention), so this works for any convex solid around origin.
static func hull_mesh(polys: Array, offset := Vector3.ZERO) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly: Array in polys:
		var c := Vector3.ZERO
		for p: Vector3 in poly:
			c += p
		c /= poly.size()
		var n := c.normalized()
		var t := (poly[0] as Vector3 - c).normalized()
		var bt := n.cross(t)
		var sorted := poly.duplicate()
		sorted.sort_custom(func(a: Vector3, bb: Vector3) -> bool:
			return atan2((a - c).dot(bt), (a - c).dot(t)) > atan2((bb - c).dot(bt), (bb - c).dot(t)))
		# dedupe (degenerate bevels)
		var pts: Array = []
		for p: Vector3 in sorted:
			if pts.is_empty() or (pts[-1] as Vector3).distance_to(p) > 0.0001:
				pts.append(p)
		if pts.size() > 2 and (pts[0] as Vector3).distance_to(pts[-1]) < 0.0001:
			pts.pop_back()
		for i in range(1, pts.size() - 1):
			var a: Vector3 = pts[0]
			var b: Vector3 = pts[i]
			var d: Vector3 = pts[i + 1]
			if (b - a).cross(d - a).dot(n) > 0.0:
				var tmp := b
				b = d
				d = tmp
			st.set_normal(n)
			st.add_vertex(a + offset)
			st.set_normal(n)
			st.add_vertex(b + offset)
			st.set_normal(n)
			st.add_vertex(d + offset)
	return st.commit()


## Square-based pyramid / wedge helpers for ears, beards, roofs.
static func prism(size: Vector3, left_to_right := 0.5) -> Mesh:
	var key := "pr%s_%s" % [size, left_to_right]
	if not _meshes.has(key):
		var m := PrismMesh.new()
		m.size = size
		m.left_to_right = left_to_right
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
	else:
		l.double_sided = false  # Label3D draws both faces by default: signs read mirrored
	# small text disappears before it can pile up into a mess at range
	l.visibility_range_end = 16.0 + px * 1400.0
	l.visibility_range_end_margin = 3.0
	l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(l)
	return l


# --- characters ------------------------------------------------------------

## Builds a chunky low-poly character (see Chars). Origin at the feet, facing -Z.
static func build_character(look: Dictionary) -> Dictionary:
	return Chars.build(look)


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


## Low-poly tree: faceted trunk + 2-3 blobby canopies from the palette.
static func tree(parent: Node3D, pos: Vector3, s := 1.0, kind := -1) -> StaticBody3D:
	var h := absf(sin(pos.x * 12.9898 + pos.z * 78.233))
	if kind < 0:
		kind = int(h * 3.0) % 3
	var t := solid_cyl(parent, 0.3 * s, 2.2 * s, P_BARK, pos + Vector3(0, 1.1 * s, 0), 0.2 * s, 5)
	var greens := [P_LEAF_A, P_LEAF_B, P_LEAF_C]
	var g: Color = greens[int(h * 7.0) % 3]
	match kind:
		0:  # round puffball tree
			part(t, sphere(1.5 * s, 7), g, Vector3(0, 2.0 * s, 0), Vector3(1, 0.9, 1))
			part(t, sphere(1.0 * s, 6), g.lightened(0.08), Vector3(0.6 * s, 2.7 * s, 0.3 * s))
		1:  # pine
			part(t, cyl(0.0, 1.7 * s, 2.2 * s, 6), g.darkened(0.1), Vector3(0, 1.9 * s, 0))
			part(t, cyl(0.0, 1.25 * s, 1.9 * s, 6), g.darkened(0.05), Vector3(0, 3.0 * s, 0))
			part(t, cyl(0.0, 0.8 * s, 1.4 * s, 6), g, Vector3(0, 3.9 * s, 0))
		_:  # lollipop cluster
			part(t, sphere(1.2 * s, 6), g, Vector3(0, 2.2 * s, 0))
			part(t, sphere(0.9 * s, 6), g.lightened(0.06), Vector3(-0.8 * s, 1.8 * s, 0.2 * s))
			part(t, sphere(0.8 * s, 6), g.darkened(0.05), Vector3(0.7 * s, 1.7 * s, -0.4 * s))
	return t


static func rock(parent: Node3D, pos: Vector3, s := 1.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.collision_mask = 0
	parent.add_child(b)
	var h := absf(sin(pos.x * 3.1 + pos.z * 7.7))
	part(b, sphere(1.0 * s, 5), P_ROCK.lerp(P_ROCK_DARK, h * 0.6), Vector3.ZERO, Vector3(1.25, 0.75, 1.0),
		Vector3(h * 40.0, h * 360.0, 0))
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
