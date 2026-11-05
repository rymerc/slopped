class_name Kit
extends RefCounted
## Loads the baked asset library (res://assets/models): single-mesh, vertex
## coloured GLBs that all share Art.vcol_mat(), so the CC0 kits and the custom
## landmarks look like one world. Visual data only; gameplay never depends on it.
##   Kit.mesh("pirate_barrel")           -> ArrayMesh (cached)
##   Kit.scene("saloon")                 -> custom landmark, instanced
## Landmark GLBs are split by object-name prefix:
##   COL_*  box collider (the mesh is only a shape description, never rendered)
##   DYN_*  stays a separate node so code can animate it
##   rest   static geometry, merged into the world Batch

const KIT_DIR := "res://assets/models/kit/%s.glb"
const CUSTOM_DIR := "res://assets/models/custom/%s.glb"

static var _meshes: Dictionary = {}
static var _scenes: Dictionary = {}


static func has(id: String) -> bool:
	return ResourceLoader.exists(KIT_DIR % id)


static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var m: Mesh = null
	var path := KIT_DIR % id
	if ResourceLoader.exists(path):
		var inst: Node = (load(path) as PackedScene).instantiate()
		var mi := _first_mesh(inst)
		if mi:
			m = mi.mesh
		inst.free()
	if m == null:
		push_error("Kit: missing mesh %s" % id)
	_meshes[id] = m
	return m


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c: Node in n.get_children():
		var r := _first_mesh(c)
		if r:
			return r
	return null


## Local-space bounds of a kit mesh.
static func aabb(id: String) -> AABB:
	var m := mesh(id)
	return m.get_aabb() if m else AABB()


static func _packed(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load(CUSTOM_DIR % id)
	return _scenes[id]


## Places a custom landmark. Static meshes go to `batch`, colliders to a StaticBody3D
## under `parent`; returns {"root": Node3D, "dyn": {name: MeshInstance3D}}.
static func landmark(parent: Node3D, batch: Batch, id: String, pos: Vector3, yaw_deg := 0.0) -> Dictionary:
	var root := Node3D.new()
	root.name = "LM_%s" % id
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var inst: Node = _packed(id).instantiate()
	var dyn := {}
	var meshes: Array[MeshInstance3D] = []
	_gather(inst, meshes)
	for mi: MeshInstance3D in meshes:
		var xf := _local_xform(mi, inst)
		var n := String(mi.name)
		if n.begins_with("COL_"):
			_box_collider(body, mi.mesh.get_aabb(), xf)
		elif n.begins_with("DYN_"):
			var d := MeshInstance3D.new()
			d.name = n.substr(4)
			d.mesh = mi.mesh
			d.material_override = Art.vcol_mat()
			d.transform = xf
			root.add_child(d)
			dyn[String(d.name)] = d
		else:
			batch.add(mi.mesh, root.global_transform * xf)
	inst.free()
	return {"root": root, "dyn": dyn, "body": body}


static func _gather(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c: Node in n.get_children():
		_gather(c, out)


static func _local_xform(n: Node3D, top: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != top and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## A COL_ mesh is a (possibly rotated / scaled) cube: its local bounds + node
## transform fully describe a BoxShape3D.
static func _box_collider(body: StaticBody3D, box: AABB, xf: Transform3D) -> void:
	var s := xf.basis.get_scale()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = (box.size * s).abs()
	cs.shape = sh
	var unscaled := xf.basis.orthonormalized()
	cs.transform = Transform3D(unscaled, xf * box.get_center())
	body.add_child(cs)
