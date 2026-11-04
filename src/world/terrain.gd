class_name Terrain
extends RefCounted
## Faceted low-poly terrain from an analytic height function.
## Every triangle gets one flat colour (picked by slope / height / zone, with
## a little per-face jitter) multiplied by baked ambient occlusion, so cliffs,
## beaches and valleys read clearly without any textures. Same triangles feed a
## trimesh collider. Deterministic: every peer builds the identical island.

## height_fn(x, z) -> float ; color_fn(x, z, h, normal) -> Color
static func build(root: Node3D, height_fn: Callable, color_fn: Callable, half: float, cell: float,
		collide := true) -> MeshInstance3D:
	var n := int(ceil(half * 2.0 / cell))
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			hs[iz * (n + 1) + ix] = float(height_fn.call(-half + ix * cell, -half + iz * cell))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for iz in n:
		for ix in n:
			var x0 := -half + ix * cell
			var z0 := -half + iz * cell
			var p00 := Vector3(x0, hs[iz * (n + 1) + ix], z0)
			var p10 := Vector3(x0 + cell, hs[iz * (n + 1) + ix + 1], z0)
			var p01 := Vector3(x0, hs[(iz + 1) * (n + 1) + ix], z0 + cell)
			var p11 := Vector3(x0 + cell, hs[(iz + 1) * (n + 1) + ix + 1], z0 + cell)
			var flip := (ix + iz) % 2 == 0
			var tris: Array = [[p00, p10, p11], [p00, p11, p01]] if flip else [[p00, p10, p01], [p10, p11, p01]]
			for t: Array in tris:
				var a: Vector3 = t[0]
				var b: Vector3 = t[1]
				var c: Vector3 = t[2]
				if (b - a).cross(c - a).y > 0.0:  # make clockwise from above
					var tmp := b
					b = c
					c = tmp
				var nrm := (c - a).cross(b - a).normalized()
				var mid := (a + b + c) / 3.0
				var col: Color = color_fn.call(mid.x, mid.z, mid.y, nrm)
				# baked AO: darker where the surroundings stand higher (valleys, cliff feet)
				var around := (float(height_fn.call(mid.x + cell * 2.0, mid.z)) + float(height_fn.call(mid.x - cell * 2.0, mid.z))
					+ float(height_fn.call(mid.x, mid.z + cell * 2.0)) + float(height_fn.call(mid.x, mid.z - cell * 2.0))) * 0.25
				var ao := clampf(1.0 - maxf(0.0, around - mid.y) * 0.07, 0.62, 1.0)
				col = Color(col.r * ao, col.g * ao, col.b * ao)
				# clockwise seen from above (Godot front face)
				for v: Vector3 in [a, b, c]:
					st.set_color(col)
					st.set_normal(nrm)
					st.add_vertex(v)
				faces.append_array(PackedVector3Array([a, b, c]))
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	mi.material_override = Art.vcol_mat()
	root.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = "TerrainBody"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
	return mi


## Scatter little low-poly instances (grass tufts, flowers, pebbles) with
## per-instance colour. accept_fn(x, z) -> bool picks valid spots.
static func scatter(root: Node3D, mesh: Mesh, count: int, half: float, height_fn: Callable,
		accept_fn: Callable, colors: Array, seed_v: int, scale_rng := Vector2(0.7, 1.3)) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var xfs: Array[Transform3D] = []
	var cols: Array[Color] = []
	var tries := 0
	while xfs.size() < count and tries < count * 6:
		tries += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if not bool(accept_fn.call(x, z)):
			continue
		var y := float(height_fn.call(x, z))
		var s := rng.randf_range(scale_rng.x, scale_rng.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		xfs.append(Transform3D(b, Vector3(x, y, z)))
		var c: Color = colors[rng.randi() % colors.size()]
		cols.append(c.lightened(rng.randf_range(-0.05, 0.08)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Art.vcol_mat()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	return mmi


## Grass tuft: three leaning blades (white vertex colour; tinted per instance).
static func tuft_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var a := TAU * i / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.06
		var tip := d * 0.12 + Vector3.UP * 0.38
		for tri: Array in [[-side, tip, side], [side, tip, -side]]:
			for v: Vector3 in tri:
				st.set_color(Color.WHITE)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


static func flower_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := Color("#5ea443")
	var tris := [
		[Vector3(-0.015, 0, 0), Vector3(0, 0.3, 0), Vector3(0.015, 0, 0)],
		[Vector3(0.015, 0, 0), Vector3(0, 0.3, 0), Vector3(-0.015, 0, 0)],
	]
	for t: Array in tris:
		for v: Vector3 in t:
			st.set_color(stem)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	for i in 5:
		var a := TAU * i / 5.0
		var b := TAU * (i + 1) / 5.0
		var c0 := Vector3(0, 0.32, 0)
		var c1 := Vector3(cos(a), 0, sin(a)) * 0.09 + Vector3(0, 0.3, 0)
		var c2 := Vector3(cos(b), 0, sin(b)) * 0.09 + Vector3(0, 0.3, 0)
		if (c1 - c0).cross(c2 - c0).y > 0.0:
			var tmp := c1
			c1 = c2
			c2 = tmp
		for t: Array in [[c0, c1, c2]]:
			for v: Vector3 in t:
				st.set_color(Color.WHITE)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


static func water(root: Node3D, y: float, size: float, mat: Material = null) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 48
	pm.subdivide_depth = 48
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = pm
	mi.material_override = mat if mat else Art.water_mat()
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
