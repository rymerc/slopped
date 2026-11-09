class_name Furn
extends RefCounted
## Western furniture modelled in art_src/blender/furniture.py (DYN parts of
## `furn`), dropped straight into the world Batch as small detail.


static func put(b: Batch, part: String, pos: Vector3, yaw_deg := 0.0, s := 1.0) -> void:
	b.add(Kit.part_mesh("furn", part), Dress.xf(pos, yaw_deg, s), true)
