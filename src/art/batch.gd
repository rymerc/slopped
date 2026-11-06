class_name Batch
extends RefCounted
## Static world merger. Everything that never moves ends up in a handful of
## vertex-coloured meshes, chunked on a grid, so a whole town costs a few dozen
## draw calls instead of thousands, and off-screen chunks still frustum-cull.
##   main   layer: buildings + big props; casts shadows; always drawn
##   detail layer: small set dressing; no shadows; fades out with distance
## Merging is native-speed (packed array transforms), a few ms per thousand items.

const CELL := 56.0
const DETAIL_END := 150.0
const GROUP_DETAIL := "batch_detail"

static var _flat: Dictionary = {}  # Mesh -> [PackedVector3Array, normals, colors]

var _main: Dictionary = {}
var _detail: Dictionary = {}
var tris := 0


func add(mesh: Mesh, xf: Transform3D, detail := false, tint := Color.WHITE, glow := 0.0) -> void:
	if mesh == null:
		return
	var f: Array = _flatten(mesh)
	var cell := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
	var buckets := _detail if detail else _main
	if not buckets.has(cell):
		buckets[cell] = []
	var verts: PackedVector3Array = f[0]
	var norms: PackedVector3Array = f[1]
	var cols: PackedColorArray = f[2]
	if tint != Color.WHITE or glow != 0.0:
		cols = cols.duplicate()
		for i in cols.size():
			var c := cols[i]
			cols[i] = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, maxf(c.a, glow))
	var nb := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
	(buckets[cell] as Array).append([xf * verts, nb * norms, cols])
	tris += verts.size() / 3


## Flattens indexed surfaces to plain triangle soup (cached per mesh). Vertices
## without colours get white; primitives from Art get theirs from add_flat().
static func _flatten(mesh: Mesh) -> Array:
	if _flat.has(mesh):
		return _flat[mesh]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if c.is_empty():
			c.resize(v.size())
			c.fill(Color(1, 1, 1, 0))  # alpha is the emission mask: plain meshes must not glow
		if idx.is_empty():
			verts.append_array(v)
			norms.append_array(n)
			cols.append_array(c)
		else:
			var start := verts.size()
			verts.resize(start + idx.size())
			norms.resize(start + idx.size())
			cols.resize(start + idx.size())
			for i in idx.size():
				var k := idx[i]
				verts[start + i] = v[k]
				norms[start + i] = n[k]
				cols[start + i] = c[k]
	_flat[mesh] = [verts, norms, cols]
	return _flat[mesh]


## Swallows the static toon MeshInstance3Ds under `root` (Art.part / solid_box
## output) into this batch and frees them. Anything in `keep`, or below it, stays
## a live node because code animates it.
func absorb(root: Node, keep: Array) -> void:
	var skip := {}
	for k: Variant in keep:
		if k is Node:
			skip[k] = true
	var found: Array[MeshInstance3D] = []
	_collect(root, skip, found)
	for mi: MeshInstance3D in found:
		var m := mi.material_override as ShaderMaterial
		var c: Color = m.get_shader_parameter("albedo")
		var g: Variant = m.get_shader_parameter("emission_strength")
		var glow := clampf(float(g if g != null else 0.0) / 6.0, 0.0, 1.0)
		add(mi.mesh, mi.global_transform, false, c.srgb_to_linear(), glow)
		mi.get_parent().remove_child(mi)
		mi.queue_free()


func _collect(n: Node, skip: Dictionary, out: Array[MeshInstance3D]) -> void:
	if skip.has(n) or n is PropSystem or n is Avatar or n is Npcs:
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override is ShaderMaterial and mi.transparency == 0.0 and mi.mesh != null \
				and (mi.material_override as ShaderMaterial).shader == Art.TOON \
				and not (mi.material_override as ShaderMaterial).get_shader_parameter("use_vertex_color"):
			out.append(mi)
	for c: Node in n.get_children():
		_collect(c, skip, out)


func commit(parent: Node3D) -> void:
	_build(parent, _main, false)
	_build(parent, _detail, true)
	_main = {}
	_detail = {}


func _build(parent: Node3D, buckets: Dictionary, detail: bool) -> void:
	for cell: Vector2i in buckets:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cols := PackedColorArray()
		for item: Array in buckets[cell]:
			verts.append_array(item[0])
			norms.append_array(item[1])
			cols.append_array(item[2])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "Batch%s_%d_%d" % ["D" if detail else "M", cell.x, cell.y]
		mi.mesh = m
		mi.material_override = Art.vcol_mat()
		if detail:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = DETAIL_END * Settings.draw_distance_scale()
			mi.visibility_range_end_margin = 12.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			mi.add_to_group(GROUP_DETAIL)
		parent.add_child(mi)
