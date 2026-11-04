class_name GiantArena
extends RefCounted
## Arena for GIANT HUNT. Deterministic from the global RNG seed so every peer
## builds the same layout. Huts have doorways too small for the giant.

const HALF := 46.0
const RACK_RING := 24.0


static func build(root: Node3D) -> Array[Vector3]:
	Art.solid_box(root, Vector3(HALF * 2 + 4, 1, HALF * 2 + 4), Color("#7cc96b"), Vector3(0, -0.5, 0), false)
	# Dirt patches
	for i in 10:
		var p := Vector3(randf_range(-40, 40), 0.02, randf_range(-40, 40))
		Art.part(root, Art.cyl(randf_range(3, 7), randf_range(3, 7), 0.04, 9), Color("#b08a5a"), p,
			Vector3.ONE, Vector3.ZERO, false)
	# Fence
	for s: float in [-1.0, 1.0]:
		Art.solid_box(root, Vector3(HALF * 2, 3, 0.6), Art.WOOD, Vector3(0, 1.5, HALF * s))
		Art.solid_box(root, Vector3(0.6, 3, HALF * 2), Art.WOOD, Vector3(HALF * s, 1.5, 0))
	# Huts (little-only shelters)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		_hut(root, Vector3(cos(a), 0, sin(a)) * 33.0, -a + PI * 0.5)
	# Ruined pillars in the middle
	for i in 6:
		var a := TAU * i / 6.0
		var h := randf_range(1.5, 5.0)
		Art.solid_cyl(root, 0.8, h, Color("#d8cfc0"), Vector3(cos(a) * 9.0, h * 0.5, sin(a) * 9.0), 0.7, 8)
	# Trees + rocks, kept away from centre and huts
	var placed := 0
	while placed < 26:
		var p := Vector3(randf_range(-42, 42), 0, randf_range(-42, 42))
		if p.length() < 12.0 or absf(p.length() - 33.0) < 5.0:
			continue
		Art.tree(root, p, randf_range(0.9, 1.6))
		placed += 1
	for i in 14:
		var p := Vector3(randf_range(-42, 42), 0.3, randf_range(-42, 42))
		if p.length() > 12.0:
			Art.rock(root, p, randf_range(0.6, 1.3))
	# Spear racks
	var racks: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		var p := Vector3(cos(a), 0, sin(a)) * RACK_RING
		_rack(root, p)
		racks.append(p)
	return racks


static func _hut(root: Node3D, pos: Vector3, yaw: float) -> void:
	var hut := Node3D.new()
	hut.position = pos
	hut.rotation.y = yaw
	root.add_child(hut)
	var wall := Color("#e8b77a")
	Art.solid_box(hut, Vector3(6, 3, 0.4), wall, Vector3(0, 1.5, -3))
	Art.solid_box(hut, Vector3(0.4, 3, 6), wall, Vector3(-3, 1.5, 0))
	Art.solid_box(hut, Vector3(0.4, 3, 6), wall, Vector3(3, 1.5, 0))
	# Front wall with a small doorway (1.6 wide, 1.4 tall)
	Art.solid_box(hut, Vector3(2.2, 3, 0.4), wall, Vector3(-1.9, 1.5, 3))
	Art.solid_box(hut, Vector3(2.2, 3, 0.4), wall, Vector3(1.9, 1.5, 3))
	Art.solid_box(hut, Vector3(1.6, 1.6, 0.4), wall, Vector3(0, 2.2, 3))
	Art.solid_box(hut, Vector3(7, 0.5, 7), Color("#c44569"), Vector3(0, 3.25, 0))
	Art.part(hut, Art.cyl(0.0, 4.6, 2.0, 4), Color("#c44569"), Vector3(0, 4.5, 0), Vector3.ONE, Vector3(0, 45, 0))


static func _rack(root: Node3D, p: Vector3) -> void:
	for sx: float in [-1.0, 1.0]:
		Art.part(root, Art.box(Vector3(0.15, 1.6, 0.15)), Art.WOOD, p + Vector3(0.8 * sx, 0.8, 0))
	Art.part(root, Art.box(Vector3(1.9, 0.15, 0.15)), Art.WOOD, p + Vector3(0, 1.45, 0))
	for i in 3:
		Art.part(root, Art.cyl(0.04, 0.04, 2.0, 5), Color("#d9b27c"), p + Vector3(-0.5 + i * 0.5, 1.0, 0.2),
			Vector3.ONE, Vector3(-15, 0, 0))
		Art.part(root, Art.cyl(0.0, 0.09, 0.3, 5), Color("#c0c6d0"), p + Vector3(-0.5 + i * 0.5, 2.1, 0.47),
			Vector3.ONE, Vector3(-15, 0, 0))
	Art.label(root, "SPEARS", p + Vector3(0, 2.8, 0), 0.01, Ui.YELLOW)
