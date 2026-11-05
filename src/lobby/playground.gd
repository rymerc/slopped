class_name Playground
extends RefCounted
## "Slop Island": the outdoor physics playground around the town of Slopsville.
## Every district has its own visual identity + something to do / break / fall off:
##   CENTRE Slopsville    western town: see LobbyBuilder
##   NORTH  Slide Hill    giant hill, rainbow belly-slide lane, cliffs, duck statue + summit flag
##   WEST   The Chasm     goo pit crossed by THE GAUNTLET (obstacle course) and the
##                        Narrow Bridge (push your friends off), trophy plateau beyond
##   EAST   Chaos Yard    scaffolding, crane landmark, wrecking ball, crates, planks, TNT
##   NE     The Carnival  ferris wheel, carousel, spiral slide, human cannon landing zone
##   SOUTH  The Meadow    campsite, kicker ramps, bowling, the two-player Vault, cave
##   SW     Slop Cove     beach district on the sunset side: bilge bar, tiki huts, boardwalk
##                        pier, boats, the diving tower
## Deterministic (fixed seeds) so every peer builds the identical island.

const HALF := 150.0
const CELL := 2.5
const ISLAND := 138.0
const SEA_Y := -4.0
const GOO_Y := -3.3
const KILL_Y := -4.4

const GAUNTLET_Z := 14.0
const BRIDGE_Z := -14.0
const GAUNTLET_START := Vector3(-48.5, 0.6, GAUNTLET_Z)
const BRIDGE_START := Vector3(-48.5, 0.6, BRIDGE_Z)
const TROPHY := Vector3(-110, 7.0, GAUNTLET_Z)
const SUMMIT := Vector3(0, 30.0, -98)
const VAULT := Vector3(45, 0.5, 96)
const PLATE_A := Vector3(30, 0.5, 80)
const PLATE_B := Vector3(60, 0.5, 80)
const LEDGE := Vector3(-62, 0.5, 48)
const CAVE := Vector3(-24, 0.5, 104)
const CAMPFIRE := Vector3(0, 0.5, 64)
const BEACH_DIR := Vector2(-0.75, 0.66)
const BAR2 := Vector3(-82, 0.3, 80)
const PIER_START := Vector3(-97, 1.6, 95)
const PIER_DIR := Vector3(-0.72, 0, 0.69)
const PIER_LEN := 4
const DIVE := PIER_START + PIER_DIR * (12.0 * PIER_LEN + 6.0) + Vector3(0, -1.6, 0)
const CANNON := Vector3(92, 0.3, -34)
const CARNIVAL := Vector3(80, 0.5, -80)
const NE_DIR := Vector2(0.707, -0.707)
const FERRIS := CARNIVAL + Vector3(16, 0, -16)
const CAROUSEL := CARNIVAL + Vector3(-14, 0, 14)
const SPIRAL := CARNIVAL + Vector3(-18, 0, -16)
const LANDING := CARNIVAL + Vector3(2, 0, 2)

# (centre xz, radius, height): spots flattened for buildings / play areas
const FLATS := [
	[Vector2(0, 64), 11.0, 0.5], [Vector2(-40, 66), 19.0, 0.5], [Vector2(45, 88), 21.0, 0.5],
	[Vector2(-62, 48), 8.0, 0.5], [Vector2(-24, 104), 12.0, 0.5], [Vector2(8, 96), 16.0, 0.5],
	[Vector2(84, 84), 9.0, 1.0], [Vector2(80, -80), 40.0, 0.5], [Vector2(-82, 80), 14.0, 0.0],
]

static var _noise: FastNoiseLite


static func _n(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1337
		_noise.frequency = 0.018
		_noise.fractal_octaves = 2
	return _noise.get_noise_2d(x, z)


static func height(x: float, z: float) -> float:
	var sq := maxf(absf(x), absf(z))
	var r := Vector2(x, z).length()
	if sq < 33.0:
		return 0.0  # town square
	var amp := 4.0 if z < 44.0 else 2.2
	var h := smoothstep(44.0, 72.0, sq) * (_n(x, z) * amp + amp * 0.5)
	# Slide Hill: gentle south face (the slide), cliffs on the north side
	var hz := z + 98.0
	var d := Vector2(x, hz * (1.9 if hz < 0.0 else 1.0)).length()
	h = maxf(h, 30.0 * (1.0 - smoothstep(8.0, 58.0, d)))
	# West chasm + plateau
	var plat := 7.0 * clampf((-98.0 - x) / 4.0, 0.0, 1.0)
	if x < -96.0:
		h = maxf(h, plat + _n(x, z) * 1.5 * clampf((-104.0 - x) / 6.0, 0.0, 1.0))
	var cx := smoothstep(-52.0, -56.0, x) * smoothstep(-100.0, -96.0, x)
	var cz := 1.0 - smoothstep(30.0, 34.0, absf(z))
	h = lerpf(h, -10.0, cx * cz)
	# East construction pad
	var pad := smoothstep(46.0, 52.0, x) * (1.0 - smoothstep(44.0, 50.0, absf(z))) * (1.0 - smoothstep(118.0, 124.0, x))
	h = lerpf(h, 0.3, pad)
	for f: Array in FLATS:
		var k := 1.0 - smoothstep(float(f[1]) * 0.7, float(f[1]), Vector2(x, z).distance_to(f[0]))
		h = lerpf(h, float(f[2]), k)
	if sq < 44.0:
		h = lerpf(0.0, h, smoothstep(36.0, 44.0, sq))
	# the casino block runs out past the town square
	var ck := (1.0 - smoothstep(56.0, 61.0, x)) * (1.0 - smoothstep(26.0, 33.0, absf(z + 1.0))) * smoothstep(20.0, 26.0, x)
	h = lerpf(h, 0.0, ck)
	# island edge -> beach -> sea floor
	# (the north-east shore bulges out to make room for the Carnival)
	var bulge := 26.0 * smoothstep(0.75, 0.95, Vector2(x, z).normalized().dot(NE_DIR)) if r > 1.0 else 0.0
	h = lerpf(h, -9.0, smoothstep(ISLAND + bulge - 20.0, ISLAND + bulge, r))
	# Slop Cove: a wide, gentle sand shelf on the sunset side
	var cove := _cove(x, z, r)
	if cove > 0.0:
		var sand := lerpf(0.2, -6.5, smoothstep(92.0, 134.0, r)) + sin(x * 0.11 + z * 0.07) * 0.25
		h = lerpf(h, sand, cove)
		for f: Array in [FLATS[-1]]:
			var k := 1.0 - smoothstep(float(f[1]) * 0.7, float(f[1]), Vector2(x, z).distance_to(f[0]))
			h = lerpf(h, float(f[2]), k)
	return h


## 0..1 weight of the beach district at this point.
static func _cove(x: float, z: float, r: float) -> float:
	if r < 70.0:
		return 0.0
	return smoothstep(0.82, 0.93, Vector2(x, z).normalized().dot(BEACH_DIR)) * smoothstep(72.0, 88.0, r)


static func _hash(x: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)


static func color(x: float, z: float, h: float, n: Vector3) -> Color:
	var j := (_hash(x, z) - 0.5) * 0.06
	var c: Color
	var in_pad := x > 50.0 and absf(z) < 46.0 and x < 120.0
	var r := Vector2(x, z).length()
	var cove := _cove(x, z, r)
	var sq := maxf(absf(x), absf(z))
	if h < -6.0:
		c = Color("#6d5f86")  # chasm floor
	elif n.y < 0.74:
		c = Art.P_ROCK if _hash(z, x) > 0.4 else Art.P_ROCK_DARK
	elif cove > 0.35 or h < SEA_Y + 2.4 + _n(x * 3.0, z * 3.0) * 1.2:
		c = Art.P_SAND if h > SEA_Y - 0.6 else Art.P_SAND.lerp(Color("#5fc9c0"), 0.5)
	elif sq < 46.0 or (absf(x) < 7.0 and z > 0.0 and z < 62.0) or (absf(z) < 5.0 + absf(x + 46.0) * 0.08 and x < -40.0 and x > -52.0):
		# packed town dirt with cart ruts down Main Street and worn patches
		c = Color("#b39a78").lerp(Color("#c0a884"), _hash(floorf(x * 0.16), floorf(z * 0.16)))
		if absf(x) < 7.0 and z < 44.0:  # Main Street, a shade darker from all the wagons
			c = c.darkened(0.08)
		return c
	elif in_pad:
		c = Art.P_DIRT if _hash(x * 0.3, z * 0.3) > 0.25 else Art.P_DIRT.darkened(0.08)
	elif h > 25.0:
		c = Art.P_GRASS_LIGHT
	else:
		var patch := _n(x * 0.6 + 400.0, z * 0.6)
		c = Art.P_GRASS.lerp(Art.P_GRASS_DARK if patch < 0.0 else Art.P_GRASS_LIGHT, absf(patch) * 1.6)
	return Color(c.r + j, c.g + j, c.b + j)


static func ground(x: float, z: float) -> float:
	return height(x, z)


static func _grassy(x: float, z: float) -> bool:
	var sq := maxf(absf(x), absf(z))
	var r := Vector2(x, z).length()
	if sq < 47.0 or r > ISLAND - 22.0 or _cove(x, z, r) > 0.15:
		return false
	if x > 20.0 and x < 62.0 and absf(z + 1.0) < 34.0:
		return false
	if absf(x) < 7.5 and z > 0.0 and z < 62.0:
		return false
	if x > 48.0 and absf(z) < 48.0 and x < 120.0:
		return false
	var h := height(x, z)
	if h < SEA_Y + 2.0:
		return false
	var e := 1.0
	var gx := height(x + e, z) - h
	var gz := height(x, z + e) - h
	return gx * gx + gz * gz < 0.5


# --- build ------------------------------------------------------------------

static func build(root: Node3D, props: PropSystem, b: Batch) -> Dictionary:
	var out := {"hazards": [], "pads": []}
	var hf := Callable(Playground, "height")
	Terrain.build(root, hf, Callable(Playground, "color"), HALF, CELL)
	Terrain.water(root, SEA_Y, 900.0)
	var goo := ShaderMaterial.new()
	goo.shader = Art.WATER
	goo.set_shader_parameter("shallow", Color("#ffa3dc"))
	goo.set_shader_parameter("deep", Color("#e04fa8"))
	goo.set_shader_parameter("wave", 0.15)
	var gm := Terrain.water(root, GOO_Y, 60.0, goo)
	gm.position = Vector3(-76, GOO_Y, 0)
	gm.scale = Vector3(0.85, 1, 1.2)
	Terrain.scatter(root, Terrain.tuft_mesh(), 3200, HALF, hf, Callable(Playground, "_grassy"),
		[Art.P_GRASS_DARK, Art.P_GRASS, Art.P_GRASS_LIGHT, Color("#6fb84a")], 11)
	Terrain.scatter(root, Terrain.flower_mesh(), 500, HALF, hf, Callable(Playground, "_grassy"),
		[Color.WHITE, Art.P_PINK, Art.GOLD, Color("#b59cff")], 12)
	_backdrop(root, b)
	_trees(root, b)
	_slide_hill(root, out, b)
	_chasm(root, out, props)
	_construction(root, out, props, b)
	_meadow(root, out, props, b)
	_plaza(root, props)
	_cove_district(root, out, props, b)
	_carnival(root, out, props, b)
	return out


static func _on_ground(x: float, z: float, dy := 0.0) -> Vector3:
	return Vector3(x, height(x, z) + dy, z)


## Solid box from a to b (ramps, planks, beams), `w` wide, `t` thick; top surface along a-b.
static func ramp(root: Node3D, a: Vector3, b: Vector3, w: float, t: float, color: Color) -> StaticBody3D:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	body.transform = Transform3D(basis, (a + b) * 0.5 - basis.y * t * 0.5)
	Art.part(body, Art.bbox(Vector3(w, t, d.length()), 0.15), color)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, t, d.length())
	cs.shape = sh
	body.add_child(cs)
	return body


static func sign_post(root: Node3D, pos: Vector3, text: String, yaw_deg := 0.0, color := Ui.YELLOW) -> void:
	var n := Node3D.new()
	root.add_child(n)
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	Art.solid_cyl(n, 0.09, 2.2, Art.WOOD, Vector3(0, 1.1, 0), -1.0, 5)
	Art.part(n, Art.bbox(Vector3(2.4, 0.6, 0.12), 0.2), Color("#d9a865"), Vector3(0, 2.0, 0))
	var l := Art.label(n, text, Vector3(0, 2.0, -0.08), 0.0085, color, false)
	l.rotation.y = PI
	var l2 := Art.label(n, text, Vector3(0, 2.0, 0.08), 0.0085, color, false)
	l2.rotation.y = 0.0


static func lamp(root: Node3D, pos: Vector3, color := Color("#fff1b8")) -> void:
	Art.solid_cyl(root, 0.1, 3.6, Color("#3d3550"), pos + Vector3(0, 1.8, 0), 0.07, 6)
	Art.part(root, Art.sphere(0.28, 6), color, pos + Vector3(0, 3.75, 0), Vector3.ONE, Vector3.ZERO, false, 1.6)
	Art.part(root, Art.cyl(0.0, 0.34, 0.22, 6), Color("#3d3550"), pos + Vector3(0, 4.05, 0))


static func chest(root: Node3D, pos: Vector3, yaw := 0.0, gold := true) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	n.position = pos
	n.rotation.y = yaw
	Art.solid_box(n, Vector3(1.2, 0.7, 0.8), Color("#a0612f"), Vector3(0, 0.35, 0))
	Art.part(n, Art.bbox(Vector3(1.24, 0.3, 0.84), 0.3), Color("#7a4520"), Vector3(0, 0.82, 0))
	Art.part(n, Art.box(Vector3(0.2, 0.26, 0.06)), Art.GOLD, Vector3(0, 0.6, -0.42), Vector3.ONE, Vector3.ZERO, false, 0.4)
	if gold:
		for i in 5:
			Art.part(n, Art.cyl(0.12, 0.12, 0.04, 8), Art.GOLD, Vector3(-0.4 + i * 0.2, 1.0 + (i % 2) * 0.05, 0.1),
				Vector3.ONE, Vector3(70, 0, 0), false, 0.6)
	return n


# --- zones ------------------------------------------------------------------

static func _backdrop(root: Node3D, b: Batch) -> void:
	# far islands: pure silhouettes that the depth fog turns into atmospheric perspective
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		var d := rng.randf_range(300.0, 420.0)
		var h := rng.randf_range(40.0, 110.0)
		var p := Vector3(cos(a) * d, -10.0, sin(a) * d)
		Art.part(root, Art.cyl(rng.randf_range(4, 14), rng.randf_range(50, 90), h, 7), Color("#7fa98e"), p + Vector3(0, h * 0.5, 0))
		Art.part(root, Art.cyl(0.0, rng.randf_range(20, 40), h * 0.5, 6), Color("#9ab89a"), p + Vector3(rng.randf_range(-30, 30), h * 0.6, 0))
	# boats out at sea, a wreck on the reef
	Dress.put(root, b, "pirate_ship_wreck", Vector3(-150, SEA_Y - 1.2, 118), 40.0, 2.0)
	Dress.put(root, b, "pirate_ship_medium", Vector3(70, SEA_Y + 0.3, 190), 120.0, 3.0)
	Dress.put(root, b, "watercraft_ship_small", Vector3(-30, SEA_Y + 0.3, -190), 200.0, 3.0)
	Dress.put(root, b, "watercraft_boat_sail_a", Vector3(180, SEA_Y + 0.1, 40), 60.0, 2.4)


const TREES := [["survival_tree", 1.0, 0.35], ["survival_tree_tall", 1.0, 0.35], ["nature_tree_oak", 3.4, 0.3],
	["nature_tree_fat", 3.4, 0.35], ["nature_tree_default", 3.4, 0.3], ["nature_tree_detailed", 3.4, 0.3],
	["fantasytown_tree", 2.6, 0.3], ["fantasytown_tree_high", 2.6, 0.3]]
const PINES := [["nature_tree_pineTallA_detailed", 3.6, 0.35], ["nature_tree_pineTallC_detailed", 3.6, 0.35], ["nature_tree_pineRoundA", 3.4, 0.35]]
const AUTUMN := [["survival_tree_autumn", 1.0, 0.35], ["survival_tree_autumn_tall", 1.0, 0.35]]


static func _trees(root: Node3D, b: Batch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var keep_clear := [Vector2(0, 64), Vector2(-40, 66), Vector2(45, 88), Vector2(-62, 48), Vector2(-24, 104),
		Vector2(8, 96), Vector2(0, -60), Vector2(84, 84), Vector2(30, 80), Vector2(60, 80), Vector2(80, -80)]
	var placed := 0
	var tries := 0
	while placed < 190 and tries < 5000:
		tries += 1
		var x := rng.randf_range(-130, 130)
		var z := rng.randf_range(-130, 130)
		if not _grassy(x, z) or absf(x) < 8.0 and z < -40.0:
			continue
		if x < -46.0 and x > -104.0 and absf(z) < 38.0:
			continue
		var ok := true
		for c: Vector2 in keep_clear:
			if Vector2(x, z).distance_to(c) < (44.0 if c.y == -80.0 else 14.0):
				ok = false
				break
		if not ok:
			continue
		# clumps read as groves, and each region has its own species mix
		var patch := _n(x * 0.7 + 90.0, z * 0.7 - 40.0)
		if patch < -0.12 and rng.randf() < 0.75:
			continue
		var table: Array = PINES if z < -30.0 and x < 40.0 else (AUTUMN if patch > 0.22 else TREES)
		var t: Array = table[rng.randi() % table.size()]
		Dress.tree(root, b, t[0], _on_ground(x, z, -0.1), rng.randf() * 360.0, float(t[1]) * rng.randf_range(0.8, 1.35), t[2])
		placed += 1
	var bushes := ["nature_plant_bush", "nature_plant_bushLarge", "nature_plant_bushDetailed", "nature_mushroom_redGroup", "nature_log", "nature_stump_round"]
	for i in 110:
		var x := rng.randf_range(-126, 126)
		var z := rng.randf_range(-126, 126)
		if _grassy(x, z):
			Dress.put(root, b, bushes[i % bushes.size()], _on_ground(x, z), rng.randf() * 360.0, rng.randf_range(2.0, 3.6), Dress.COL_NONE, true)
	var rocks := ["nature_rock_largeA", "nature_rock_largeD", "nature_rock_largeE", "survival_rock_a", "survival_rock_b", "survival_rock_c"]
	for i in 54:
		var x := rng.randf_range(-130, 130)
		var z := rng.randf_range(-130, 130)
		if maxf(absf(x), absf(z)) > 48.0 and Vector2(x, z).length() < ISLAND - 8.0 and _cove(x, z, Vector2(x, z).length()) < 0.1:
			var s := rng.randf_range(1.8, 4.2) * (1.0 if i % 6 < 3 else 1.7)
			Dress.put(root, b, rocks[i % rocks.size()], _on_ground(x, z, -0.15), rng.randf() * 360.0, s, Dress.COL_BOX)


static func _slide_hill(root: Node3D, out: Dictionary, b: Batch) -> void:
	# rainbow slide lane down the south face: smooth panels over the facets
	var stripes := [Art.P_PINK, Art.GOLD, Art.P_BLUE, Art.P_GRASS_LIGHT, Art.P_ORANGE, Art.P_PURPLE]
	var z := -90.0
	var i := 0
	while z < -46.0:
		var z2 := z + 3.0
		var ra := Vector3(0, maxf(height(0, z), height(2.5, z)) + 0.45, z)
		var rb := Vector3(0, maxf(height(0, z2), height(2.5, z2)) + 0.45, z2)
		ramp(root, ra, rb + (rb - ra).normalized() * 0.15, 6.0, 0.35, stripes[i % stripes.size()])
		i += 1
		z = z2
	for sx: float in [-1.0, 1.0]:  # rails
		for k in 8:
			var zz := -88.0 + k * 5.5
			Art.part(root, Art.cyl(0.08, 0.08, 1.0, 5), Color.WHITE, Vector3(3.3 * sx, height(3.3 * sx, zz) + 0.9, zz))
	sign_post(root, Vector3(-5, height(-5, -47) , -47), "SLIDE HILL  [C] to belly-slide", 0.0)
	# summit: flag + giant rubber duck landmark (visible from everywhere)
	var top := SUMMIT
	Art.solid_box(root, Vector3(14, 0.6, 14), Color("#d9cfb0"), top + Vector3(0, -0.25, 0))
	Art.solid_cyl(root, 0.12, 9.0, Art.P_STEEL, top + Vector3(-4, 4.5, 3), -1.0, 6)
	var flag := Node3D.new()
	flag.position = top + Vector3(-4, 8.0, 3)
	root.add_child(flag)
	Art.part(flag, Art.box(Vector3(2.6, 1.6, 0.06)), Art.P_PINK, Vector3(1.3, 0, 0))
	Art.part(flag, Art.box(Vector3(0.6, 0.6, 0.07)), Ui.YELLOW, Vector3(1.3, 0, 0), Vector3.ONE, Vector3.ZERO, false, 0.3)
	out.flag = flag
	Kit.landmark(root, b, "giant_duck", top + Vector3(3.0, 0.1, -3.0), 165.0)
	# hay bales at the bottom of the run, picnic spots up the flanks
	for k in 8:
		Dress.put(root, b, "pirate_flag_pennant", _on_ground(5.0 * (1 if k % 2 == 0 else -1), -82.0 + k * 5.0), 0.0, 1.2, Dress.COL_NONE, true)


static func _chasm(root: Node3D, out: Dictionary, props: PropSystem) -> void:
	var z := GAUNTLET_Z
	# start pad + arch
	Art.solid_box(root, Vector3(6, 0.6, 6), Color("#5a4a78"), Vector3(-48.5, 0.0, z))
	for sz: float in [-1.0, 1.0]:
		Art.solid_box(root, Vector3(0.6, 5, 0.6), Art.P_RED, Vector3(-51, 2.5, z + 2.6 * sz))
	Art.part(root, Art.bbox(Vector3(0.8, 0.9, 6.2), 0.2), Ui.YELLOW, Vector3(-51, 5.2, z))
	var gl := Art.label(root, "THE GAUNTLET", Vector3(-50.5, 5.2, z), 0.02, Art.P_RED, false)
	gl.rotation.y = PI * 0.5
	# 1. stepping stones
	var stones := [[-55.0, 0.5, 1.2], [-59.5, 1.0, -1.0], [-64.0, 1.5, 1.4], [-68.5, 2.0, -0.6]]
	for st: Array in stones:
		Art.solid_cyl(root, 1.25, 12.0, Color("#8b7fb0"), Vector3(float(st[0]), float(st[1]) - 6.0, z + float(st[2])), 1.15, 7)
	# 2. sweeper platform
	var sp := Vector3(-75, 2.5, z)
	Art.solid_cyl(root, 5.0, 14.0, Color("#6a5c90"), sp - Vector3(0, 7.0, 0), 4.8, 12)
	Art.part(root, Art.cyl(5.02, 5.02, 0.06, 12), Art.P_HAZARD, sp + Vector3(0, 0.0, 0), Vector3(1, 1, 1))
	var sweeper := Node3D.new()
	sweeper.position = sp + Vector3(0, 0.75, 0)
	root.add_child(sweeper)
	Art.part(sweeper, Art.cyl(0.4, 0.5, 1.5, 8), Art.INK, Vector3(0, 0.0, 0))
	Art.part(sweeper, Art.bbox(Vector3(9.6, 0.5, 0.5), 0.3), Art.P_RED, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		Art.part(sweeper, Art.bbox(Vector3(0.5, 0.52, 0.52), 0.3), Color.WHITE, Vector3(4.2 * sx, 0, 0))
	(out.hazards as Array).append({"type": "sweeper", "node": sweeper, "center": sp, "r": 4.8, "y": sp.y, "speed": 1.7})
	# 3. balance beam + pendulum
	Art.solid_box(root, Vector3(9.5, 0.4, 0.6), Color("#d9a865"), Vector3(-85.25, 3.0, z))
	for x: float in [-80.5, -90.0]:
		Art.solid_cyl(root, 0.5, 14.0, Color("#6a5c90"), Vector3(x, -4.0, z), -1.0, 6)
	var piv := Vector3(-85.25, 12.5, z)
	Art.part(root, Art.box(Vector3(0.5, 0.5, 6.0)), Art.INK, piv)
	for sz: float in [-1.0, 1.0]:
		Art.part(root, Art.box(Vector3(0.4, 14.0, 0.4)), Art.INK, Vector3(piv.x, 5.5, z + 3.0 * sz))
	var ball := Node3D.new()
	root.add_child(ball)
	Art.part(ball, Art.sphere(1.1, 8), Color("#4a4e69"), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, true, 0.0).material_override = Art.mat(Color("#4a4e69"), false, 0.0, 0.8)
	var cable := Node3D.new()
	root.add_child(cable)
	Art.part(cable, Art.cyl(0.05, 0.05, 1.0, 4), Art.INK, Vector3(0, -0.5, 0))
	(out.hazards as Array).append({"type": "pendulum", "ball": ball, "cable": cable, "pivot": piv, "len": 8.4,
		"amp": 1.05, "period": 3.4, "axis": Vector3(0, 0, 1), "r": 1.1})
	# 4. bounce pad up to the plateau
	Art.solid_box(root, Vector3(4, 0.5, 4), Color("#6a5c90"), Vector3(-92.5, 2.95, z))
	Art.solid_cyl(root, 0.6, 12.0, Color("#6a5c90"), Vector3(-92.5, -3.0, z), -1.0, 6)
	_pad(root, out, Vector3(-92.5, 3.2, z), Vector3(-9.5, 16.0, 0))
	# 5. trophy
	Art.solid_cyl(root, 1.2, 1.2, Color("#d9cfb0"), TROPHY + Vector3(0, 0.6, 0), 1.0, 8)
	var cup := Node3D.new()
	cup.name = "Trophy"
	cup.position = TROPHY + Vector3(0, 1.2, 0)
	root.add_child(cup)
	Art.part(cup, Art.cyl(0.45, 0.2, 0.7, 8), Art.GOLD, Vector3(0, 0.75, 0), Vector3.ONE, Vector3.ZERO, false, 0.5).material_override = Art.mat(Art.GOLD, false, 0.5, 1.0)
	Art.part(cup, Art.cyl(0.08, 0.08, 0.4, 6), Art.GOLD, Vector3(0, 0.25, 0))
	Art.part(cup, Art.cyl(0.3, 0.3, 0.08, 8), Art.GOLD, Vector3(0, 0.04, 0))
	out.trophy = cup
	Art.label(root, "FINISH", TROPHY + Vector3(0, 3.6, 0), 0.02, Art.GOLD)
	sign_post(root, Vector3(-44, 0, z - 4.0), "<- THE GAUNTLET", 90.0)
	# Narrow Bridge: wobbly planks with a deep sag and nothing to stop a shove
	var a := BRIDGE_START + Vector3(-0.5, -0.4, 0)
	var b := Vector3(-102, 6.8, BRIDGE_Z)
	var segs := 24
	var prev := a
	for k in range(1, segs + 1):
		var t := float(k) / segs
		var p := a.lerp(b, t) - Vector3.UP * 3.2 * sin(PI * t)
		ramp(root, prev, p, 1.0, 0.18, Color("#c9965a") if k % 2 == 0 else Color("#b5814a"))
		if k % 4 == 0:
			for sz: float in [-1.0, 1.0]:
				Art.part(root, Art.cyl(0.05, 0.05, 1.0, 4), Art.WOOD, p + Vector3(0, 0.5, 0.55 * sz))
		prev = p
	Art.solid_box(root, Vector3(6, 0.6, 6), Color("#5a4a78"), Vector3(-48.5, 0.0, BRIDGE_Z))
	Art.label(root, "NARROW BRIDGE", BRIDGE_START + Vector3(-2, 3.0, 0), 0.016, Ui.YELLOW)
	sign_post(root, Vector3(-44, 0, BRIDGE_Z + 4.0), "<- NARROW BRIDGE (no railings lol)", 90.0)
	# plateau dressing
	for i in 4:
		props.spawn("cone", Vector3(-106 - i * 1.5, 7.6, GAUNTLET_Z - 4.0))
	lamp(root, Vector3(-106, 7.0, GAUNTLET_Z + 4.0))
	lamp(root, Vector3(-106, 7.0, BRIDGE_Z - 3.0))


static func _pad(root: Node3D, out: Dictionary, pos: Vector3, vel: Vector3) -> void:
	Art.part(root, Art.cyl(1.2, 1.3, 0.22, 10), Art.INK, pos + Vector3(0, 0.11, 0))
	var top := Art.part(root, Art.cyl(1.0, 1.0, 0.08, 10), Art.P_PINK, pos + Vector3(0, 0.25, 0), Vector3.ONE,
		Vector3.ZERO, false, 0.8)
	(out.pads as Array).append({"pos": pos, "r": 1.25, "vel": vel, "node": top})


static func _construction(root: Node3D, out: Dictionary, props: PropSystem, b: Batch) -> void:
	var g := 0.3
	Art.label(root, "CHAOS YARD", Vector3(56, 7.0, 24), 0.03, Art.P_HAZARD, true)
	for p: Vector3 in [Vector3(54, g, 18), Vector3(54, g, 30), Vector3(54, g, -24), Vector3(54, g, -32)]:
		Art.solid_box(root, Vector3(0.3, 1.0, 2.8), Art.P_HAZARD, p + Vector3(0, 0.5, 0))
		Art.solid_box(root, Vector3(0.32, 0.4, 2.82), Art.INK, p + Vector3(0, 0.5, 0))
	sign_post(root, Vector3(46, 0, 24), "CHAOS YARD ->", -90.0)
	# working-yard clutter: containers, trucks, pallets, a dumpster with ambitions
	Dress.put(root, b, "watercraft_cargo_container_a", Vector3(60, g, -38), 90.0, 2.4, Dress.COL_BOX)
	Dress.put(root, b, "watercraft_cargo_container_b", Vector3(66, g, -38.5), 86.0, 2.4, Dress.COL_BOX)
	Dress.put(root, b, "watercraft_cargo_pile_a", Vector3(116, g, 32), 0.0, 2.0, Dress.COL_BOX)
	Dress.put(root, b, "retrourban_truck_green_cargo", Vector3(106, g, -12), 30.0, 3.4, Dress.COL_BOX)
	Dress.put(root, b, "retrourban_truck_flat", Vector3(58, g, 40), -70.0, 3.4, Dress.COL_BOX)
	Dress.put(root, b, "kk_city_dumpster", Vector3(72, g, 40), 10.0, 3.2, Dress.COL_BOX)
	for p: Vector3 in [Vector3(80, g, 24), Vector3(84, g, 25), Vector3(74, g, -6), Vector3(112, g, 8)]:
		Dress.put(root, b, "retrourban_pallet", p, p.x * 13.0, 1.8, Dress.COL_NONE, true)
	for p: Vector3 in [Vector3(96, g, -30), Vector3(98, g, 4)]:
		Dress.put(root, b, "survival_box_large", p, p.z * 21.0, 1.6, Dress.COL_BOX, true)
	# crane landmark
	var cb := Vector3(102, g, -28)
	Art.solid_box(root, Vector3(4, 1, 4), Color("#8a8a96"), cb + Vector3(0, 0.5, 0))
	Art.solid_box(root, Vector3(1.6, 38, 1.6), Art.P_HAZARD, cb + Vector3(0, 19.5, 0))
	for k in 12:
		Art.part(root, Art.box(Vector3(1.7, 0.15, 0.15)), Art.INK, cb + Vector3(0, 2.0 + k * 3.0, -0.82), Vector3.ONE, Vector3(0, 0, 40))
	var jib := Node3D.new()
	jib.position = cb + Vector3(0, 39, 0)
	root.add_child(jib)
	Art.part(jib, Art.box(Vector3(2.4, 2.0, 2.4)), Art.P_HAZARD, Vector3(0, 0, 0))
	Art.part(jib, Art.box(Vector3(1.2, 1.0, 34)), Art.P_HAZARD, Vector3(0, 1.2, -13))
	Art.part(jib, Art.box(Vector3(1.6, 1.6, 4)), Color("#5a5a66"), Vector3(0, 0.8, 7))
	Art.part(jib, Art.cyl(0.05, 0.05, 16, 4), Art.INK, Vector3(0, -7.0, -26))
	Art.part(jib, Art.bbox(Vector3(0.8, 0.6, 0.8), 0.3), Art.P_RED, Vector3(0, -15.2, -26))
	Art.part(jib, Art.sphere(0.4, 5), Art.P_RED, Vector3(0, 2.2, -29), Vector3.ONE, Vector3.ZERO, false, 2.0)
	out.jib = jib
	# wrecking ball across the yard
	var wpiv := Vector3(78, 16.5, 0)
	for sx: float in [-1.0, 1.0]:
		Art.solid_box(root, Vector3(0.8, 16.5, 0.8), Art.P_RED.darkened(0.15), Vector3(wpiv.x, 8.25 + g, sx * 4.0))
	Art.part(root, Art.box(Vector3(0.8, 0.8, 8.8)), Art.P_RED.darkened(0.15), wpiv)
	var wb := Node3D.new()
	root.add_child(wb)
	Art.part(wb, Art.sphere(1.5, 9), Color("#3d3d4a"), Vector3.ZERO).material_override = Art.mat(Color("#3d3d4a"), false, 0.0, 0.9)
	var wc := Node3D.new()
	root.add_child(wc)
	Art.part(wc, Art.cyl(0.07, 0.07, 1.0, 4), Art.INK, Vector3(0, -0.5, 0))
	(out.hazards as Array).append({"type": "pendulum", "ball": wb, "cable": wc, "pivot": wpiv, "len": 14.6,
		"amp": 0.95, "period": 5.6, "axis": Vector3(1, 0, 0), "r": 1.5})
	Art.label(root, "WRECKING BALL\n(stand here, it's fine)", Vector3(78, 3.0, 5.5), 0.01, Ui.YELLOW)
	# scaffolding towers (jump the gap between them)
	for tz: float in [-26.0, -14.0]:
		var base := Vector3(66, g, tz)
		for lvl in 3:
			var y := g + 3.0 * (lvl + 1)
			Art.solid_box(root, Vector3(6, 0.35, 6), Color("#c9a26a"), Vector3(base.x, y, tz))
			for cx: float in [-2.8, 2.8]:
				for cz: float in [-2.8, 2.8]:
					Art.part(root, Art.cyl(0.08, 0.08, 3.0, 5), Art.P_STEEL, Vector3(base.x + cx, y - 1.5, tz + cz))
			var side := 1.0 if lvl % 2 == 0 else -1.0
			var from := Vector3(base.x + 3.2 * side + 5.5 * side, y - 3.0 + 0.0, tz)
			var to := Vector3(base.x + 3.0 * side, y, tz)
			if lvl == 0:
				from.y = g
			ramp(root, from, to, 1.6, 0.25, Color("#b88a4a"))
		props.spawn("crate", Vector3(66, g + 9.9, tz))
	Art.label(root, "JUMP IT", Vector3(66, 11.5, -20), 0.015, Art.P_HAZARD)
	# steel frame tower, TNT on top
	var tb := Vector3(100, g, 18)
	for cx: float in [-3.0, 3.0]:
		for cz: float in [-3.0, 3.0]:
			Art.solid_box(root, Vector3(0.5, 10, 0.5), Art.P_RED.darkened(0.1), tb + Vector3(cx, 5, cz))
	for lvl in 2:
		Art.solid_box(root, Vector3(6.6, 0.35, 6.6), Color("#9a9aa6"), tb + Vector3(0, 5.0 + lvl * 5.0, 0))
	ramp(root, tb + Vector3(-9.5, 0, 0), tb + Vector3(-3.3, 5.0, 0), 1.6, 0.3, Color("#9a9aa6"))
	ramp(root, tb + Vector3(3.3, 5.0, -2.0), tb + Vector3(-1.0, 10.0, -2.0), 1.2, 0.3, Color("#9a9aa6"))
	for k in 3:
		props.spawn("tnt", tb + Vector3(-1.5 + k * 1.2, 10.8, 1.5))
	Art.label(root, "DO NOT\nTHROW THE TNT", tb + Vector3(0, 13.0, 0), 0.012, Art.P_RED)
	# loose stuff everywhere
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for row in 4:  # crate pyramid
		for k in 4 - row:
			props.spawn("crate", Vector3(60 + k * 1.05 + row * 0.52, g + 0.5 + row * 1.0, 14))
	for i in 6:
		props.spawn("barrel", Vector3(rng.randf_range(56, 112), g + 0.6, rng.randf_range(-40, 40)))
	for i in 10:
		props.spawn("cone", Vector3(rng.randf_range(54, 112), g + 0.4, rng.randf_range(-40, 40)))
	for i in 5:
		props.spawn("plank", Vector3(rng.randf_range(58, 110), g + 0.2 + i * 0.16, rng.randf_range(-36, 36)), rng.randf() * 180.0)
	for i in 3:
		props.spawn("beam", Vector3(88, g + 0.2 + i * 0.32, -8 + i * 0.1), 10.0 * i)
	for i in 6:
		props.spawn("crate_s", Vector3(rng.randf_range(56, 110), g + 0.35, rng.randf_range(-36, 36)))
	for i in 4:
		props.spawn("tnt", Vector3(90 + i * 1.3, g + 0.55, 30))
	# cement mixer (drum spins)
	var mixer := Vector3(84, g, -38)
	Art.solid_box(root, Vector3(3, 2.2, 7), Color("#e8e2d0"), mixer + Vector3(0, 1.5, 0))
	Art.solid_box(root, Vector3(3, 1.6, 2), Art.P_BLUE, mixer + Vector3(0, 3.3, -2.6))
	var drum := Node3D.new()
	drum.position = mixer + Vector3(0, 4.0, 1.0)
	drum.rotation_degrees.x = 70.0
	root.add_child(drum)
	Art.part(drum, Art.cyl(0.9, 1.4, 3.6, 8), Art.P_ORANGE)
	Art.part(drum, Art.box(Vector3(0.2, 3.6, 2.9)), Color.WHITE, Vector3.ZERO, Vector3.ONE, Vector3(0, 0, 0))
	out.drum = drum
	# port-a-potty (of course)
	Art.solid_box(root, Vector3(1.4, 2.4, 1.4), Art.P_BLUE, Vector3(112, g + 1.2, -6))
	Art.part(root, Art.box(Vector3(1.5, 0.15, 1.5)), Art.P_BLUE.lightened(0.2), Vector3(112, g + 2.5, -6))
	for p: Vector3 in [Vector3(56, g, -40), Vector3(56, g, 40), Vector3(116, g, -40), Vector3(116, g, 40)]:
		lamp(root, p, Color("#ffd08a"))


static func _meadow(root: Node3D, out: Dictionary, props: PropSystem, b: Batch) -> void:
	sign_post(root, Vector3(9, 0, 48), "THE MEADOW / SLOP COVE ->", 180.0)
	# campfire hangout: a proper campsite
	var cf := CAMPFIRE
	Dress.put(root, b, "survival_campfire_pit", cf + Vector3(0, -0.02, 0), 0.0, 2.2, Dress.COL_NONE, true)
	Dress.put(root, b, "nature_tent_detailedOpen", cf + Vector3(-8.0, -0.05, -3.0), 110.0, 4.2, Dress.COL_BOX)
	Dress.put(root, b, "survival_tent", cf + Vector3(7.5, -0.05, -4.0), -120.0, 1.7, Dress.COL_BOX)
	Dress.put(root, b, "survival_bedroll", cf + Vector3(3.2, 0.02, 5.0), 40.0, 1.5, Dress.COL_NONE, true)
	Dress.put(root, b, "nature_log_stack", cf + Vector3(-5.0, -0.05, 6.0), 20.0, 2.6, Dress.COL_BOX, true)
	Dress.put(root, b, "survival_signpost", cf + Vector3(6.0, 0, 7.0), -20.0, 1.6, Dress.COL_NONE, true)
	var fire := Node3D.new()
	fire.position = cf + Vector3(0, 0.5, 0)
	root.add_child(fire)
	Art.part(fire, Art.cyl(0.0, 0.5, 1.1, 5), Art.P_ORANGE, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false, 2.2)
	Art.part(fire, Art.cyl(0.0, 0.3, 0.8, 5), Ui.YELLOW, Vector3(0, -0.1, 0), Vector3.ONE, Vector3.ZERO, false, 2.5)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffb060")
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 1.0, 0)
	fire.add_child(light)
	out.fire = fire
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var lp := cf + Vector3(cos(a) * 3.6, 0.35, sin(a) * 3.6)
		var log_body := Art.solid_cyl(root, 0.38, 2.4, Art.P_BARK, lp, -1.0, 6)
		log_body.rotation = Vector3(0, -a, PI * 0.5)
	# kicker ramps (sprint + dive off these)
	for k in 3:
		var x := -6.0 + k * 9.0
		ramp(root, Vector3(x, 0.5, 86), Vector3(x, 2.8, 93), 4.0, 0.4, [Art.P_PINK, Art.P_BLUE, Art.GOLD][k])
		Art.solid_box(root, Vector3(4, 2.3, 0.4), Color("#5a4a78"), Vector3(x, 1.65, 93.0))
	props.spawn("big_ball", Vector3(10, 1.9, 104))
	# bowling lane
	var lane := Vector3(-40, 0.5, 50)
	Art.part(root, Art.box(Vector3(4.0, 0.08, 32)), Color("#e0b47a"), lane + Vector3(0, 0.04, 16))
	for sx: float in [-1.0, 1.0]:
		Art.part(root, Art.box(Vector3(0.2, 0.2, 32)), Color("#7a4520"), lane + Vector3(2.1 * sx, 0.1, 16))
	var row := 0
	for r in 4:
		for k in r + 1:
			props.spawn("pin", lane + Vector3((k - r * 0.5) * 0.7, 0.5, 28 + r * 0.6))
			row += 1
	props.spawn("big_ball", lane + Vector3(0, 1.4, 2))
	Art.label(root, "BOWL A FRIEND", lane + Vector3(0, 3.0, 0), 0.016, Ui.YELLOW)
	# co-op vault: needs two plates held at once (players or heavy crates!)
	var v := VAULT
	for sx: float in [-1.0, 1.0]:
		Art.solid_box(root, Vector3(3.5, 6, 0.8), Color("#8a8a96"), v + Vector3(3.25 * sx, 3, -3.6))
	Art.solid_box(root, Vector3(3.0, 2.0, 0.8), Color("#8a8a96"), v + Vector3(0, 5.0, -3.6))
	Art.solid_box(root, Vector3(0.8, 6, 8), Color("#8a8a96"), v + Vector3(-4.6, 3, 0.4))
	Art.solid_box(root, Vector3(0.8, 6, 8), Color("#8a8a96"), v + Vector3(4.6, 3, 0.4))
	Art.solid_box(root, Vector3(10, 6, 0.8), Color("#8a8a96"), v + Vector3(0, 3, 4.4))
	Art.solid_box(root, Vector3(10.4, 0.6, 9.2), Color("#6e6e7a"), v + Vector3(0, 6.3, 0.4))
	var door := Art.solid_box(root, Vector3(3.0, 4.0, 0.4), Art.GOLD.darkened(0.2), v + Vector3(0, 2.0, -4.1))
	out.vault_door = door
	Art.label(root, "THE VAULT\n(needs 2 plates)", v + Vector3(0, 7.6, -4.2), 0.016, Art.GOLD, false).rotation.y = PI
	chest(root, v + Vector3(0, 0, 1.5), PI)
	var plates: Array = []
	for pp: Vector3 in [PLATE_A, PLATE_B]:
		Art.part(root, Art.cyl(1.7, 1.8, 0.2, 10), Color("#5a4a78"), pp + Vector3(0, 0.1, 0))
		var top := Art.part(root, Art.cyl(1.4, 1.4, 0.12, 10), Art.P_RED, pp + Vector3(0, 0.25, 0), Vector3.ONE,
			Vector3.ZERO, false, 0.5)
		plates.append(top)
		props.spawn("crate", pp + Vector3(0, 0.5, -6.0))
	out.plates = plates
	# Friend Ledge: too tall to jump, fine if you stand on a buddy (or stack 2 crates)
	Art.solid_box(root, Vector3(3, 3.0, 3), Color("#a39cb3"), LEDGE + Vector3(0, 1.5, 0))
	chest(root, LEDGE + Vector3(0, 3.0, 0), 0.0, true)
	Art.label(root, "FRIEND LEDGE\n(too tall? stand on a friend)", LEDGE + Vector3(0, 5.2, 0), 0.012, Ui.YELLOW)
	for i in 2:
		props.spawn("crate", LEDGE + Vector3(8.0 + i * 3.0, 0.5, 6.0))
	# cave: rock tunnel with glowing mushrooms + loot
	var c := CAVE
	var rock := Art.P_ROCK_DARK
	for sz: float in [-1.0, 1.0]:
		Art.solid_box(root, Vector3(14, 3.6, 1.6), rock, c + Vector3(0, 1.8, 2.8 * sz))
	Art.solid_box(root, Vector3(14, 1.6, 7.2), rock, c + Vector3(0, 4.3, 0))
	Art.solid_box(root, Vector3(1.6, 3.6, 4.0), rock, c + Vector3(7.8, 1.8, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 14:
		var p := c + Vector3(rng.randf_range(-7, 7), rng.randf_range(2.5, 5.2), rng.randf_range(-4, 4))
		Art.part(root, Art.sphere(rng.randf_range(1.4, 2.4), 5), Art.P_ROCK.lerp(rock, rng.randf()), p,
			Vector3(1.2, 0.8, 1.0), Vector3(0, rng.randf() * 360.0, 0))
	for i in 6:
		var p := c + Vector3(rng.randf_range(-5, 6), 0.0, rng.randf_range(-1.6, 1.6))
		Art.part(root, Art.cyl(0.05, 0.06, 0.3, 5), Color.WHITE, p + Vector3(0, 0.15, 0))
		Art.part(root, Art.sphere(0.2, 6), Color("#7af0ff"), p + Vector3(0, 0.35, 0), Vector3(1, 0.5, 1), Vector3.ZERO, false, 2.0)
	var cl := OmniLight3D.new()
	cl.light_color = Color("#7af0ff")
	cl.light_energy = 1.2
	cl.omni_range = 7.0
	cl.position = c + Vector3(3, 1.5, 0)
	root.add_child(cl)
	chest(root, c + Vector3(6.2, 0, 0), -PI * 0.5)
	Art.label(root, "SPOOKY CAVE", c + Vector3(-7.5, 4.5, 0), 0.014, Color("#7af0ff"))
	# lighthouse landmark
	var lh := Vector3(84, 1.0, 84)
	Kit.landmark(root, b, "lighthouse", lh, 225.0)
	var beam := Node3D.new()
	beam.position = lh + Vector3(0, 27.0, 0)
	root.add_child(beam)
	var bm := Art.part(beam, Art.cyl(0.3, 2.5, 26, 6), Color("#fff6b0"), Vector3(0, 0, -13), Vector3.ONE, Vector3(90, 0, 0), false, 1.2)
	bm.transparency = 0.7
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out.beam = beam
	# toys scattered around the meadow
	rng.seed = 21
	for i in 8:
		props.spawn("ball", Vector3(rng.randf_range(-30, 60), 0, rng.randf_range(48, 110)).lerp(Vector3.ZERO, 0.0) + Vector3(0, 3.0, 0))
	for i in 6:
		var x := rng.randf_range(-60, 60)
		var z := rng.randf_range(46, 115)
		props.spawn("duck", Vector3(x, height(x, z) + 0.6, z))
	for p: Vector3 in [Vector3(-9, 0, 52), Vector3(9, 0, 60), Vector3(-20, 0, 60), Vector3(20, 0, 60)]:
		lamp(root, _on_ground(p.x, p.z))
	# fence + farm patch on the way to the vault
	for i in 12:
		Dress.put(root, b, "survival_fence", _on_ground(24.0 + i * 3.6, 66.0), 0.0, 7.0, Dress.COL_NONE, true)
	for i in 14:
		Dress.put(root, b, "nature_crop_pumpkin", _on_ground(26.0 + i * 2.4 + rng.randf() * 1.2, 70.0 + (i % 3) * 1.6), rng.randf() * 360.0, 2.2, Dress.COL_NONE, true)


static func _plaza(root: Node3D, props: PropSystem) -> void:
	# signposts at the edges of town
	sign_post(root, Vector3(-4, 0, -44), "^ SLIDE HILL ^", 0.0)
	sign_post(root, Vector3(-44, 0, 9), "<- CHASM / GAUNTLET", 90.0)
	sign_post(root, Vector3(29, 0, -22), "THE CARNIVAL ^", 40.0)
	for i in 4:
		props.spawn("ball", Vector3(-3 + i * 2.0, 2.0, 52))


# --- Slop Cove -----------------------------------------------------------------

static func _cove_district(root: Node3D, out: Dictionary, props: PropSystem, b: Batch) -> void:
	Kit.landmark(root, b, "beach_bar", BAR2, 40.0)
	Art.label(root, "MYSTERY SLOP", BAR2 + Vector3(0, 4.4, 0), 0.01, Ui.YELLOW)
	var bt: Node3D = Art.build_character({"color": Color("#ff5fa2"), "hat": "party", "body": "frog"}).root
	bt.position = BAR2 + Vector3(1.0, 0, 1.0)
	bt.rotation.y = -0.7
	root.add_child(bt)
	sign_post(root, _on_ground(-66, 62), "SLOP COVE ->", 130.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var fwd := Vector3(BEACH_DIR.x, 0, BEACH_DIR.y)
	var side := Vector3(-fwd.z, 0, fwd.x)
	var c := Vector3(BEACH_DIR.x, 0, BEACH_DIR.y) * 104.0
	# tiki huts along the sand
	for o: float in [-30.0, -19.0, 18.0, 30.0]:
		var p := c + side * o + fwd * rng.randf_range(-6, 2)
		Kit.landmark(root, b, "tiki_hut", _on_ground(p.x, p.z), rad_to_deg(atan2(fwd.x, fwd.z)) + rng.randf_range(-20, 20))
	# umbrellas + loungers
	var umbrella_cols := [Art.P_RED, Art.P_BLUE, Art.GOLD, Art.P_PINK]
	for i in 7:
		var p := c + side * (-13.0 + i * 4.4 + (6.0 if i > 2 else 0.0)) + fwd * 8.0
		p = _on_ground(p.x, p.z)
		Art.part(root, Art.cyl(0.05, 0.05, 3.2, 5), Color.WHITE, p + Vector3(0, 1.6, 0))
		Art.part(root, Art.cyl(0.0, 2.1, 0.75, 8), umbrella_cols[i % 4], p + Vector3(0, 3.2, 0))
		Art.part(root, Art.cyl(0.0, 2.15, 0.1, 8), Color.WHITE if i % 2 == 0 else umbrella_cols[(i + 2) % 4], p + Vector3(0, 2.84, 0))
		for sx: float in [-1.0, 1.0]:
			var q := p + side * sx * 1.5 - fwd * 0.6
			Art.part(root, Art.bbox(Vector3(0.75, 0.14, 2.0), 0.2), Art.P_CREAM, q + Vector3(0, 0.32, 0), Vector3.ONE, Vector3(0, rad_to_deg(atan2(fwd.x, fwd.z)), 0))
	# palms: the district's silhouette
	var palms := [["pirate_palm_detailed_straight", 1.5], ["pirate_palm_detailed_bend", 1.5], ["pirate_palm_bend", 1.6], ["pirate_palm_straight", 1.5]]
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 900:
		tries += 1
		var a := rng.randf_range(-0.72, 0.72)
		var d := rng.randf_range(78.0, 118.0)
		var dir := Vector2(BEACH_DIR).rotated(a)
		var x := dir.x * d
		var z := dir.y * d
		if Vector2(x, z).distance_to(Vector2(BAR2.x, BAR2.z)) < 13.0:
			continue
		if height(x, z) < SEA_Y + 1.2:
			continue
		var t: Array = palms[rng.randi() % palms.size()]
		Dress.tree(root, b, t[0], _on_ground(x, z, -0.1), rng.randf() * 360.0, float(t[1]) * rng.randf_range(0.9, 1.7), 0.35)
		placed += 1
	for i in 40:
		var a := rng.randf_range(-0.7, 0.7)
		var d := rng.randf_range(90.0, 126.0)
		var dir := Vector2(BEACH_DIR).rotated(a)
		var id: String = ["pirate_rocks_sand_a", "pirate_rocks_sand_b", "pirate_patch_sand_foliage", "survival_rock_sand_a", "pirate_grass_plant"][i % 5]
		Dress.put(root, b, id, _on_ground(dir.x * d, dir.y * d), rng.randf() * 360.0, rng.randf_range(1.2, 2.2), Dress.COL_NONE, true)
	# beach bits to throw at people
	for i in 6:
		var p := c + side * rng.randf_range(-22, 22) + fwd * rng.randf_range(2, 14)
		props.spawn("beachball", _on_ground(p.x, p.z, 0.8))
	# boardwalk pier, stepped out to sea, then the diving tower
	var yaw := rad_to_deg(atan2(PIER_DIR.x, PIER_DIR.z))
	for i in PIER_LEN:
		Kit.landmark(root, b, "dock_section", PIER_START + PIER_DIR * (6.0 + 12.0 * i) + Vector3(0, -1.6, 0), yaw)
	var ramp_top := PIER_START
	var ramp_bot := PIER_START - PIER_DIR * 7.0
	ramp_bot.y = height(ramp_bot.x, ramp_bot.z) + 0.1
	ramp(root, ramp_bot, ramp_top, 5.0, 0.3, Color("#b0845a"))
	Kit.landmark(root, b, "dive_tower", DIVE, yaw + 180.0)
	_pad(root, out, DIVE + Vector3(0, 0.0, 0) + Vector3(0, 1.6, 0) - PIER_DIR * 5.0, PIER_DIR * 2.8 + Vector3(0, 22.0, 0))
	Art.label(root, "BOUNCE UP, DIVE IN", DIVE - PIER_DIR * 5.0 + Vector3(0, 4.2, 0), 0.012, Ui.YELLOW)
	var side2 := Vector3(-PIER_DIR.z, 0, PIER_DIR.x)
	Dress.put(root, b, "watercraft_boat_fishing_small", PIER_START + PIER_DIR * 12.0 + side2 * 7.0 + Vector3(0, SEA_Y - 1.5, 0), yaw + 90.0, 2.2)
	Dress.put(root, b, "watercraft_boat_speed_a", PIER_START + PIER_DIR * 26.0 - side2 * 7.0 + Vector3(0, SEA_Y - 1.5, 0), yaw + 80.0, 2.2)
	Dress.put(root, b, "watercraft_boat_sail_b", PIER_START + PIER_DIR * 36.0 + side2 * 16.0 + Vector3(0, SEA_Y - 1.5, 0), yaw - 40.0, 2.6)
	Dress.put(root, b, "pirate_boat_row_large", c + side * 8.0 + fwd * 15.0 + Vector3(0, 0.0, 0) + Vector3.UP * (height(c.x + side.x * 8.0 + fwd.x * 15.0, c.z + side.z * 8.0 + fwd.z * 15.0) + 0.1), 70.0, 1.4)
	for i in 5:
		Dress.put(root, b, "watercraft_buoy", PIER_START + PIER_DIR * (24.0 + i * 12.0) + side2 * (22.0 - i * 3.0) + Vector3(0, SEA_Y - 1.5, 0), 0.0, 1.6, Dress.COL_NONE, true)
	for s: float in [-1.0, 1.0]:
		lamp(root, PIER_START + PIER_DIR * 1.0 + side2 * s * 2.0)
		lamp(root, _on_ground(BAR2.x + s * 10.0, BAR2.z + 10.0), Color("#ffb45e"))


# --- The Carnival ---------------------------------------------------------------

static func _carnival(root: Node3D, out: Dictionary, props: PropSystem, b: Batch) -> void:
	var c := CARNIVAL
	var fw := Kit.landmark(root, b, "ferris_wheel", FERRIS, 30.0)
	out.ferris = (fw as Dictionary).dyn
	out.carousel = ((Kit.landmark(root, b, "carousel", CAROUSEL, 0.0) as Dictionary).dyn as Dictionary).get("top")
	Kit.landmark(root, b, "spiral_slide", SPIRAL, 0.0)
	_pad(root, out, SPIRAL + Vector3(0, 0.1, 7.2), Vector3(0, 21.0, -3.2))
	Art.label(root, "HELTER SKELTER\n(bounce up, slide down)", SPIRAL + Vector3(0, 4.4, 8.4), 0.012, Ui.YELLOW)
	Kit.landmark(root, b, "ticket_booth", c + Vector3(-30, 0, 24), 200.0)
	Dress.put(root, b, "coaster_park_entrance", _on_ground(50, -50), -45.0, 5.0, Dress.COL_NONE)
	Art.label(root, "THE CARNIVAL", _on_ground(50, -50) + Vector3(0, 8.5, 0), 0.022, Ui.ACCENT)
	Dress.put(root, b, "coaster_stall_food", c + Vector3(24, 0, 6), -90.0, 3.2, Dress.COL_BOX)
	Dress.put(root, b, "coaster_stall_drinks", c + Vector3(24, 0, 14), -90.0, 3.2, Dress.COL_BOX)
	Dress.put(root, b, "coaster_stall_information", c + Vector3(-4, 0, -30), 20.0, 3.2, Dress.COL_BOX)
	Dress.put(root, b, "coaster_stall_toilets", c + Vector3(30, 0, -6), -90.0, 3.2, Dress.COL_BOX)
	# the human cannon lives at the north end of the Chaos Yard and fires up here
	Kit.landmark(root, b, "big_cannon", CANNON, 180.0)
	Art.label(root, "WARNING: LAUNCHES NORTH", CANNON + Vector3(0, 5.6, 5.4), 0.012, Art.P_RED)
	# wooden coaster sculpture: runs along the back of the fairground
	var seg := 8.0
	var track_y := 5.0
	for i in 8:
		var p := c + Vector3(-34.0 + i * seg, track_y, 34.0)
		Dress.put(root, b, "coaster_coaster_wood_straight", p, 90.0, 2.0)
		Dress.put(root, b, "coaster_support_large", p + Vector3(0, -track_y, 0), 0.0, 2.0)
		Dress.put(root, b, "coaster_support_large_bottom", p + Vector3(0, -track_y - 0.1, 0), 0.0, 2.0)
	Dress.put(root, b, "coaster_coaster_wood_looping", c + Vector3(30.0, track_y - 0.2, 34.0), 90.0, 2.2)
	Dress.put(root, b, "coaster_coaster_train", c + Vector3(-18.0, track_y + 0.3, 34.0), 90.0, 2.0)
	# the cannon landing pad: a giant bouncy target
	var l := LANDING
	Art.part(root, Art.cyl(7.0, 7.4, 0.5, 20), Art.P_RED, l + Vector3(0, 0.25, 0))
	Art.part(root, Art.cyl(5.2, 5.2, 0.52, 20), Color.WHITE, l + Vector3(0, 0.26, 0))
	Art.part(root, Art.cyl(3.4, 3.4, 0.54, 20), Art.P_RED, l + Vector3(0, 0.27, 0))
	Art.part(root, Art.cyl(1.6, 1.6, 0.56, 20), Art.GOLD, l + Vector3(0, 0.28, 0))
	var top := Art.part(root, Art.cyl(7.0, 7.0, 0.04, 20), Art.GOLD, l + Vector3(0, 0.02, 0))
	(out.pads as Array).append({"pos": l + Vector3(0, 0.2, 0), "r": 7.2, "vel": Vector3(0, 13.0, 0), "node": top})
	Art.label(root, "CANNON LANDING ZONE\n(probably)", l + Vector3(0, 6.5, 0), 0.016, Art.P_RED)
	# bunting + lights between the rides
	var warm := [Color("#ffe6a8"), Color("#ff9fc9"), Color("#9fe6ff")]
	Dress.bulbs(b, c + Vector3(-22, 7, 20), c + Vector3(4, 7, 34), 18, 1.4, warm)
	Dress.bulbs(b, c + Vector3(4, 7, -2), c + Vector3(24, 7, 10), 18, 1.4, warm)
	Dress.bulbs(b, c + Vector3(-22, 7, 20), c + Vector3(4, 7, -2), 18, 1.4, warm)
	for p: Vector3 in [c + Vector3(-22, 0, 20), c + Vector3(4, 0, 34), c + Vector3(4, 0, -2), c + Vector3(24, 0, 10)]:
		Art.solid_cyl(root, 0.14, 7.0, Art.P_RED, p + Vector3(0, 3.5, 0), 0.1, 6)
		Art.part(root, Art.cyl(0.0, 0.3, 0.5, 6), Art.GOLD, p + Vector3(0, 7.3, 0))
	# prizes
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 8:
		props.spawn("ball", c + Vector3(rng.randf_range(-14, 14), 1.0, rng.randf_range(-6, 22)))
	for i in 6:
		props.spawn("duck", c + Vector3(rng.randf_range(-14, 14), 1.0, rng.randf_range(-6, 22)))
