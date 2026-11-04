class_name Playground
extends RefCounted
## "Slop Island": the outdoor physics playground around the Slop Lounge.
## Every zone has its own visual identity + something to do / break / fall off:
##   NORTH  Slide Hill    giant hill, rainbow belly-slide lane, cliffs, duck statue + summit flag
##   WEST   The Chasm     goo pit crossed by THE GAUNTLET (obstacle course) and the
##                        Narrow Bridge (push your friends off), trophy plateau beyond
##   EAST   Construction  scaffolding, crane landmark, wrecking ball, crates, planks, TNT
##   SOUTH  The Meadow    open field: campfire hangout, kicker ramps, bowling, the
##                        two-player Vault, Friend Ledge (needs a boost), a cave, lighthouse
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
const LEDGE := Vector3(-70, 0.5, 82)
const CAVE := Vector3(-24, 0.5, 104)
const CAMPFIRE := Vector3(0, 0.5, 64)

# (centre xz, radius, height): spots flattened for buildings / play areas
const FLATS := [
	[Vector2(0, 64), 11.0, 0.5], [Vector2(-40, 66), 19.0, 0.5], [Vector2(45, 88), 21.0, 0.5],
	[Vector2(-70, 82), 8.0, 0.5], [Vector2(-24, 104), 12.0, 0.5], [Vector2(8, 96), 16.0, 0.5],
	[Vector2(100, 100), 7.0, 1.0],
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
		return -0.12  # under the lounge floor
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
	# island edge -> beach -> sea floor
	h = lerpf(h, -9.0, smoothstep(ISLAND - 20.0, ISLAND, r))
	return h


static func _hash(x: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)


static func color(x: float, z: float, h: float, n: Vector3) -> Color:
	var j := (_hash(x, z) - 0.5) * 0.06
	var c: Color
	var in_pad := x > 50.0 and absf(z) < 46.0 and x < 120.0
	if h < -6.0:
		c = Color("#6d5f86")  # chasm floor
	elif n.y < 0.74:
		c = Art.P_ROCK if _hash(z, x) > 0.4 else Art.P_ROCK_DARK
	elif h < SEA_Y + 1.6:
		c = Art.P_SAND
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
	if sq < 35.0 or Vector2(x, z).length() > ISLAND - 22.0:
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

static func build(root: Node3D, props: PropSystem) -> Dictionary:
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
	_backdrop(root)
	_trees(root)
	_slide_hill(root, out)
	_chasm(root, out, props)
	_construction(root, out, props)
	_meadow(root, out, props)
	_plaza(root, props)
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

static func _backdrop(root: Node3D) -> void:
	# far islands: pure silhouettes that the depth fog turns into atmospheric perspective
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		var d := rng.randf_range(300.0, 420.0)
		var h := rng.randf_range(40.0, 110.0)
		var p := Vector3(cos(a) * d, -10.0, sin(a) * d)
		Art.part(root, Art.cyl(rng.randf_range(4, 14), rng.randf_range(50, 90), h, 7), Color("#5f9f6a"), p + Vector3(0, h * 0.5, 0))
		Art.part(root, Art.cyl(0.0, rng.randf_range(20, 40), h * 0.5, 6), Color("#79b07a"), p + Vector3(rng.randf_range(-30, 30), h * 0.6, 0))


static func _trees(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var keep_clear := [Vector2(0, 64), Vector2(-40, 66), Vector2(45, 88), Vector2(-70, 82), Vector2(-24, 104),
		Vector2(8, 96), Vector2(0, -60), Vector2(100, 100), Vector2(30, 80), Vector2(60, 80)]
	var placed := 0
	var tries := 0
	while placed < 85 and tries < 2000:
		tries += 1
		var x := rng.randf_range(-130, 130)
		var z := rng.randf_range(-130, 130)
		if not _grassy(x, z) or absf(x) < 8.0 and z < -40.0:
			continue
		if x < -46.0 and x > -104.0 and absf(z) < 38.0:
			continue
		var ok := true
		for c: Vector2 in keep_clear:
			if Vector2(x, z).distance_to(c) < 14.0:
				ok = false
				break
		if not ok:
			continue
		Art.tree(root, _on_ground(x, z, -0.1), rng.randf_range(0.9, 1.7))
		placed += 1
	for i in 40:
		var x := rng.randf_range(-130, 130)
		var z := rng.randf_range(-130, 130)
		if maxf(absf(x), absf(z)) > 40.0 and Vector2(x, z).length() < ISLAND - 8.0:
			Art.rock(root, _on_ground(x, z, 0.1), rng.randf_range(0.5, 1.8))


static func _slide_hill(root: Node3D, out: Dictionary) -> void:
	# rainbow slide lane down the south face: smooth panels over the facets
	var stripes := [Art.P_PINK, Art.GOLD, Art.P_BLUE, Art.P_GRASS_LIGHT, Art.P_ORANGE, Art.P_PURPLE]
	var z := -90.0
	var i := 0
	while z < -46.0:
		var z2 := z + 3.0
		var a := Vector3(0, maxf(height(0, z), height(2.5, z)) + 0.45, z)
		var b := Vector3(0, maxf(height(0, z2), height(2.5, z2)) + 0.45, z2)
		ramp(root, a, b + (b - a).normalized() * 0.15, 6.0, 0.35, stripes[i % stripes.size()])
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
	var duck := Node3D.new()
	duck.position = top + Vector3(3.5, 0, -2)
	duck.rotation.y = PI * 0.15
	duck.scale = Vector3.ONE * 4.0
	root.add_child(duck)
	Art.solid_box(duck, Vector3(1.4, 1.2, 1.4), Ui.YELLOW, Vector3(0, 0.6, 0))
	Art.part(duck, Art.sphere(0.85, 8), Ui.YELLOW, Vector3(0, 0.75, 0), Vector3(1.2, 0.85, 1.05))
	Art.part(duck, Art.sphere(0.55, 8), Ui.YELLOW, Vector3(0, 1.65, -0.45))
	Art.part(duck, Art.bbox(Vector3(0.4, 0.14, 0.4), 0.3), Art.P_ORANGE, Vector3(0, 1.58, -1.0))
	for sx: float in [-1.0, 1.0]:
		Art.part(duck, Art.sphere(0.09, 5), Art.INK, Vector3(0.24 * sx, 1.82, -0.92))
	Art.part(duck, Art.sphere(0.4, 6), Ui.YELLOW.darkened(0.1), Vector3(0, 1.05, 0.95), Vector3(1, 0.6, 0.8))
	Art.label(root, "SLIDE HILL", top + Vector3(0, 13, 0), 0.06, Ui.YELLOW)


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


static func _construction(root: Node3D, out: Dictionary, props: PropSystem) -> void:
	var g := 0.3
	Art.label(root, "CONSTRUCTION ZONE", Vector3(52, 6.0, 0), 0.03, Art.P_HAZARD, false).rotation.y = -PI * 0.5
	for sz: float in [-1.0, 1.0]:  # striped barriers at the entrance
		for k in 3:
			var p := Vector3(52, g, sz * (6.0 + k * 3.2))
			Art.solid_box(root, Vector3(0.3, 1.0, 2.8), Art.P_HAZARD if k % 2 == 0 else Art.INK, p + Vector3(0, 0.5, 0))
	sign_post(root, Vector3(44, 0, -4), "CONSTRUCTION ->", -90.0)
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


static func _meadow(root: Node3D, out: Dictionary, props: PropSystem) -> void:
	sign_post(root, Vector3(8, 0, 40), "THE MEADOW: vault, ledge, cave, bowling", 180.0)
	# campfire hangout
	var cf := CAMPFIRE
	for i in 5:
		var a := TAU * i / 5.0
		Art.part(root, Art.cyl(0.12, 0.12, 1.2, 5), Art.P_BARK, cf + Vector3(cos(a) * 0.35, 0.2, sin(a) * 0.35),
			Vector3.ONE, Vector3(70, rad_to_deg(a), 0))
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
		var a := Vector3(x, 0.5, 86)
		var b := Vector3(x, 2.8, 93)
		ramp(root, a, b, 4.0, 0.4, [Art.P_PINK, Art.P_BLUE, Art.GOLD][k])
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
	var lh := Vector3(100, 1.0, 100)
	for k in 6:
		Art.solid_cyl(root, 2.6 - k * 0.22, 3.6, Color.WHITE if k % 2 == 0 else Art.P_RED, lh + Vector3(0, 1.8 + k * 3.6, 0), 2.6 - (k + 1) * 0.22, 9)
	Art.part(root, Art.cyl(1.2, 1.2, 1.6, 8), Ui.YELLOW, lh + Vector3(0, 23.0, 0), Vector3.ONE, Vector3.ZERO, false, 2.5)
	Art.part(root, Art.cyl(0.0, 1.8, 1.6, 8), Art.P_RED, lh + Vector3(0, 24.6, 0))
	var beam := Node3D.new()
	beam.position = lh + Vector3(0, 23.0, 0)
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
	for p: Vector3 in [Vector3(-12, 0, 44), Vector3(12, 0, 44), Vector3(-20, 0, 60), Vector3(20, 0, 60)]:
		lamp(root, _on_ground(p.x, p.z))


static func _plaza(root: Node3D, props: PropSystem) -> void:
	# lamp posts ringing the lounge, signposts at the doors
	for x: float in [-40.0, -20.0, 20.0, 40.0]:
		for z: float in [-38.0, 38.0]:
			lamp(root, Vector3(x, 0, z))
	for z: float in [-20.0, 0.0, 20.0]:
		for x: float in [-38.0, 38.0]:
			lamp(root, Vector3(x, 0, z))
	sign_post(root, Vector3(-22, 0, -36), "^ SLIDE HILL ^", 0.0)
	sign_post(root, Vector3(23, 0, -36), "^ SLIDE HILL ^", 0.0)
	sign_post(root, Vector3(-36, 0, 22), "<- CHASM / GAUNTLET", 90.0)
	sign_post(root, Vector3(36, 0, 22), "CONSTRUCTION ->", -90.0)
	for i in 4:
		props.spawn("ball", Vector3(-6 + i * 4.0, 2.0, 40))
