class_name GiantArena
extends RefCounted
## Arena for GIANT HUNT. Deterministic from the global RNG seed so every peer
## builds the same layout. Huts have doorways too small for the giant.

const HALF := 46.0
const RACK_RING := 24.0
const TREES := ["nature_tree_oak", "nature_tree_fat", "nature_tree_pineTallA_detailed", "nature_tree_default"]


static var _noise: FastNoiseLite


## Flat playing field inside the fence, rolling hills rising outside it
## (scenery only: the fence keeps everyone in).
static func height(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 4242
		_noise.frequency = 0.02
	var sq := maxf(absf(x), absf(z))
	var out := smoothstep(HALF + 2.0, HALF + 40.0, sq)
	return -0.02 + out * (14.0 + _noise.get_noise_2d(x, z) * 10.0)


static func color(x: float, z: float, h: float, n: Vector3) -> Color:
	var j := (fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0) - 0.5) * 0.06
	var c: Color
	if n.y < 0.75:
		c = Art.P_ROCK
	elif h > 16.0:
		c = Art.P_GRASS_LIGHT
	else:
		var patch := _noise.get_noise_2d(x * 1.7 + 300.0, z * 1.7)
		c = Art.P_GRASS.lerp(Art.P_GRASS_DARK if patch < 0.0 else Art.P_GRASS_LIGHT, absf(patch) * 1.5)
	return Color(c.r + j, c.g + j, c.b + j)


static func _inside(x: float, z: float) -> bool:
	return maxf(absf(x), absf(z)) < HALF - 1.0 and Vector2(x, z).length() > 3.0


## Scenery is modelled (art_src/blender/arenas.py) and goes into `b`; every
## collider is made here, at the same size and place as the old primitives.
static func build(root: Node3D, props: PropSystem, b: Batch) -> Array[Vector3]:
	# collision: one flat slab (gameplay assumes y = 0); visuals: faceted terrain
	var floor_body := StaticBody3D.new()
	floor_body.collision_mask = 0
	root.add_child(floor_body)
	var fcs := CollisionShape3D.new()
	var fsh := BoxShape3D.new()
	fsh.size = Vector3(HALF * 2 + 4, 1, HALF * 2 + 4)
	fcs.shape = fsh
	fcs.position.y = -0.5
	floor_body.add_child(fcs)
	var hf := Callable(GiantArena, "height")
	Terrain.build(root, hf, Callable(GiantArena, "color"), 130.0, 3.0, false)
	Terrain.scatter(root, Terrain.tuft_mesh(), 2200, HALF, hf, Callable(GiantArena, "_inside"),
		[Art.P_GRASS_DARK, Art.P_GRASS, Art.P_GRASS_LIGHT], 21)
	Terrain.scatter(root, Terrain.flower_mesh(), 350, HALF, hf, Callable(GiantArena, "_inside"),
		[Color.WHITE, Art.P_PINK, Art.GOLD], 22)
	# far mountains (landmarks for orientation, fogged into the horizon)
	var mountain := Kit.part_mesh("game_bits", "mountain")
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var h := 60.0 + 25.0 * sin(i * 2.3)
		b.add(mountain, Transform3D(Basis(Vector3.UP, a * 2.0).scaled(Vector3(1.0, h / 64.0, 1.0)), Vector3(cos(a) * 190.0, 0.0, sin(a) * 190.0)))
	# outside the fence: tree line for depth
	for i in 40:
		var a := TAU * i / 40.0
		var d := HALF + 8.0 + fmod(i * 7.3, 20.0)
		var px := cos(a) * d
		var pz := sin(a) * d
		_tree(root, b, Vector3(px, height(px, pz), pz), 1.4 + fmod(i * 0.37, 0.8))
	# Dirt patches
	var dirt := Kit.part_mesh("game_bits", "dirt")
	for i in 10:
		var p := Vector3(randf_range(-40, 40), 0.02, randf_range(-40, 40))
		var rx := randf_range(3, 7)
		var rz := randf_range(3, 7)
		b.add(dirt, Transform3D(Basis(Vector3.UP, float(i) * 1.7).scaled(Vector3(rx, 1.0, rz)), p))
	# Fence: a palisade, inside face toward the middle
	for s: float in [-1.0, 1.0]:
		Art.col_box(root, Vector3(HALF * 2, 3, 0.6), Vector3(0, 1.5, HALF * s))
		Art.col_box(root, Vector3(0.6, 3, HALF * 2), Vector3(HALF * s, 1.5, 0))
		Kit.landmark(root, b, "gh_fence", Vector3(0, 0, HALF * s), 180.0 if s > 0.0 else 0.0)
		Kit.landmark(root, b, "gh_fence", Vector3(HALF * s, 0, 0), -90.0 if s > 0.0 else 90.0)
	# Huts (little-only shelters)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		_hut(root, b, Vector3(cos(a), 0, sin(a)) * 33.0, -a + PI * 0.5)
	# Ruined pillars round the worn flagstones where the giant starts
	Kit.landmark(root, b, "gh_plaza", Vector3.ZERO)
	for i in 6:
		var a := TAU * i / 6.0
		var h := randf_range(1.5, 5.0)
		var pos := Vector3(cos(a) * 9.0, 0.0, sin(a) * 9.0)
		Art.col_cyl(root, 0.8, h, pos + Vector3.UP * h * 0.5)
		var col := Kit.part_mesh("game_bits", "pillar%d" % (0 if h < 2.75 else (1 if h < 4.25 else 2)))
		b.add(col, Transform3D(Basis(Vector3.UP, a * 3.0).scaled(Vector3(1.0, h / col.get_aabb().end.y, 1.0)), pos))
	# Trees + rocks, kept away from centre and huts
	var placed := 0
	while placed < 26:
		var p := Vector3(randf_range(-42, 42), 0, randf_range(-42, 42))
		if p.length() < 12.0 or absf(p.length() - 33.0) < 5.0:
			continue
		_tree(root, b, p, randf_range(0.9, 1.6))
		placed += 1
	for i in 14:
		var p := Vector3(randf_range(-42, 42), 0.3, randf_range(-42, 42))
		if p.length() > 12.0:
			_rock(root, b, p, randf_range(0.6, 1.3))
	# Spear racks
	var racks: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		var p := Vector3(cos(a), 0, sin(a)) * RACK_RING
		_rack(root, b, p)
		racks.append(p)
	# a few toys for the giant to fling (and littles to hide behind)
	if props:
		for i in 3:
			var a := TAU * i / 3.0 + 0.5
			var hp := Vector3(cos(a), 0, sin(a)) * 33.0
			var side := Vector3(-sin(a), 0, cos(a))
			props.spawn("crate", hp + side * 5.0 + Vector3.UP * 0.5)
			props.spawn("barrel", hp - side * 5.0 + Vector3.UP * 0.6)
			props.spawn("ball", hp * 0.6 + Vector3.UP * 0.6)
	return racks


## Kit tree, same trunk collider as the old Art.tree (r 0.3 s, 2.2 s tall).
static func _tree(root: Node3D, b: Batch, pos: Vector3, s: float) -> void:
	var h := absf(sin(pos.x * 12.9898 + pos.z * 78.233))
	var id: String = TREES[int(h * 7.0) % TREES.size()]
	var k := 3.9 * s / maxf(Kit.aabb(id).size.y, 0.01)
	b.add(Kit.mesh(id), Dress.xf(pos, h * 360.0, k))
	Art.col_cyl(root, 0.3 * s, 2.2 * s, pos + Vector3(0, 1.1 * s, 0))


## Modelled boulder; same sphere collider as the old Art.rock.
static func _rock(root: Node3D, b: Batch, pos: Vector3, s: float) -> void:
	var h := absf(sin(pos.x * 3.1 + pos.z * 7.7))
	var rot := Basis.from_euler(Vector3(deg_to_rad(h * 40.0), deg_to_rad(h * 360.0), 0.0))
	b.add(Kit.part_mesh("game_bits", "rock%d" % (int(h * 5.0) % 3)), Transform3D(rot * Basis.from_scale(Vector3(1.25, 0.75, 1.0) * s), pos))
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_mask = 0
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.85 * s
	cs.shape = sh
	body.add_child(cs)


static func _hut(root: Node3D, b: Batch, pos: Vector3, yaw: float) -> void:
	var hut := Node3D.new()
	hut.position = pos
	hut.rotation.y = yaw
	root.add_child(hut)
	Art.col_box(hut, Vector3(6, 3, 0.4), Vector3(0, 1.5, -3))
	Art.col_box(hut, Vector3(0.4, 3, 6), Vector3(-3, 1.5, 0))
	Art.col_box(hut, Vector3(0.4, 3, 6), Vector3(3, 1.5, 0))
	# Front wall with a small doorway (1.6 wide, 1.4 tall)
	Art.col_box(hut, Vector3(2.2, 3, 0.4), Vector3(-1.9, 1.5, 3))
	Art.col_box(hut, Vector3(2.2, 3, 0.4), Vector3(1.9, 1.5, 3))
	Art.col_box(hut, Vector3(1.6, 1.6, 0.4), Vector3(0, 2.2, 3))
	Art.col_box(hut, Vector3(7, 0.5, 7), Vector3(0, 3.25, 0))
	Kit.landmark(hut, b, "gh_hut", Vector3.ZERO)


static func _rack(root: Node3D, b: Batch, p: Vector3) -> void:
	Kit.landmark(root, b, "gh_rack", p)
	Art.label(root, "SPEARS", p + Vector3(0, 2.8, 0), 0.01, Ui.YELLOW)
