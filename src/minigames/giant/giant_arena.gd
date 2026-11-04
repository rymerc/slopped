class_name GiantArena
extends RefCounted
## Arena for GIANT HUNT. Deterministic from the global RNG seed so every peer
## builds the same layout. Huts have doorways too small for the giant.

const HALF := 46.0
const RACK_RING := 24.0


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


static func build(root: Node3D, props: PropSystem = null) -> Array[Vector3]:
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
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var h := 60.0 + 25.0 * sin(i * 2.3)
		Art.part(root, Art.cyl(6.0, 45.0, h, 6), Color("#6f9fb0"), Vector3(cos(a) * 190.0, h * 0.5 - 4.0, sin(a) * 190.0))
		Art.part(root, Art.cyl(0.0, 10.0, h * 0.25, 6), Color.WHITE, Vector3(cos(a) * 190.0, h - 4.0 + h * 0.1, sin(a) * 190.0))
	# outside the fence: tree line for depth
	for i in 40:
		var a := TAU * i / 40.0
		var d := HALF + 8.0 + fmod(i * 7.3, 20.0)
		var px := cos(a) * d
		var pz := sin(a) * d
		Art.tree(root, Vector3(px, height(px, pz), pz), 1.4 + fmod(i * 0.37, 0.8))
	# Dirt patches
	for i in 10:
		var p := Vector3(randf_range(-40, 40), 0.02, randf_range(-40, 40))
		Art.part(root, Art.cyl(randf_range(3, 7), randf_range(3, 7), 0.04, 9), Art.P_DIRT, p,
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
		Art.solid_cyl(root, 0.8, h, Color("#d9cfb0"), Vector3(cos(a) * 9.0, h * 0.5, sin(a) * 9.0), 0.7, 8)
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


static func _hut(root: Node3D, pos: Vector3, yaw: float) -> void:
	var hut := Node3D.new()
	hut.position = pos
	hut.rotation.y = yaw
	root.add_child(hut)
	var wall := Color("#f0cf9a")
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
