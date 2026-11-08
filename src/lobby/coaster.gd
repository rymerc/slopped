class_name Coaster
extends Node3D
## THE SLOPPER: a closed wooden coaster around the Carnival. The track is generated
## from one curve, and the train's position comes from the shared clock, so every
## peer sees the same train with nothing sent over the network. Speed comes from
## height (energy), so it crawls up the lift and screams down the drops.

const CARS := 3
const CAR_GAP := 3.2
const DWELL := 7.0   # seconds in the station each lap
const STEP := 0.05
const LIFT := 5.5    # never slower than this
## Relative to Playground.CARNIVAL. Starts at the station, runs clockwise.
const POINTS := [Vector3(-24, 3.2, 35), Vector3(-6, 3.2, 37), Vector3(12, 3.2, 37), Vector3(27, 12, 36),
	Vector3(36, 19, 24), Vector3(38, 6, 6), Vector3(37, 11, -10), Vector3(31, 16, -26), Vector3(14, 6, -36),
	Vector3(-6, 13, -38), Vector3(-26, 5, -34), Vector3(-38, 10, -18), Vector3(-40, 4, 4), Vector3(-37, 4, 24)]

var curve := Curve3D.new()
var length := 0.0
var period := 1.0
var _table := PackedFloat32Array()  # offset at each STEP of the lap
var _cars: Array[Node3D] = []


## Track goes straight into the batch; the train stays live.
func build(root: Node3D, b: Batch) -> void:
	var n := POINTS.size()
	for i in n:
		var p: Vector3 = POINTS[i] + Playground.CARNIVAL
		var prev: Vector3 = POINTS[(i + n - 1) % n]
		var next: Vector3 = POINTS[(i + 1) % n]
		var t := (next - prev) / 5.0
		curve.add_point(p, -t, t)
	curve.add_point(POINTS[0] + Playground.CARNIVAL, -(POINTS[1] - POINTS[n - 1]) / 5.0, (POINTS[1] - POINTS[n - 1]) / 5.0)
	curve.bake_interval = 0.4
	length = curve.get_baked_length()
	_integrate()
	var rail := Art.box(Vector3(0.14, 0.14, 1.3))
	var tie := Art.box(Vector3(1.9, 0.12, 0.3))
	var post := Art.cyl(0.13, 0.17, 1.0, 5)
	var brace := Art.box(Vector3(2.0, 0.1, 0.1))
	var red := Color("#b5402f").srgb_to_linear()
	var wood := Color("#8f5a35").srgb_to_linear()
	var steel := Color("#d5dae3").srgb_to_linear()
	var o := 0.0
	var k := 0
	while o < length:
		var xf := _frame(o)
		var side := xf.basis.x
		b.add(tie, xf, false, wood)
		b.add(rail, Transform3D(xf.basis, xf.origin + side * 0.72 + xf.basis.y * 0.12), false, steel)
		b.add(rail, Transform3D(xf.basis, xf.origin - side * 0.72 + xf.basis.y * 0.12), false, steel)
		if k % 6 == 0:
			var ground := Playground.height(xf.origin.x, xf.origin.z)
			var h := xf.origin.y - ground
			if h > 0.6:
				for sgn: float in [-1.0, 1.0]:
					var at := xf.origin + side * 0.72 * sgn
					b.add(post, Transform3D(Basis.IDENTITY.scaled(Vector3(1, h, 1)), Vector3(at.x, ground + h * 0.5, at.z)), false, red)
				b.add(brace, Transform3D(xf.basis, xf.origin - Vector3.UP * h * 0.5), false, wood)
		o += 1.2
		k += 1
	_station(root, b)
	for i in CARS:
		_cars.append(_car(i))
		add_child(_cars[i])


func _frame(o: float) -> Transform3D:
	var at := curve.sample_baked(o, true)
	var ahead := curve.sample_baked(fposmod(o + 0.6, length), true)
	var fwd := (ahead - at).normalized()
	if fwd.length() < 0.5:
		fwd = Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	return Transform3D(Basis(right, up, -fwd), at)


## Walks the track once with energy conservation and records offset against time.
func _integrate() -> void:
	var top := -INF
	for p: Vector3 in POINTS:
		top = maxf(top, p.y + Playground.CARNIVAL.y)
	var o := 0.0
	var list: Array[float] = []
	while o < length:
		list.append(o)
		var y := curve.sample_baked(o).y
		o += maxf(LIFT, sqrt(maxf(0.0, 2.0 * 9.8 * (top - y)) * 0.8)) * STEP
	_table = PackedFloat32Array(list)
	period = _table.size() * STEP + DWELL


## Offset along the track of car 0 at clock time t.
func offset_at(t: float) -> float:
	var lap := fposmod(t, period)
	if lap < DWELL:
		return 0.0
	return _table[mini(int((lap - DWELL) / STEP), _table.size() - 1)]


func boarding(t: float) -> bool:
	return fposmod(t, period) < DWELL - 1.0


func lap_left(t: float) -> float:
	return period - fposmod(t, period)


## Seat in car i, for Avatar.ride.
func seat(i: int, t: float) -> Transform3D:
	var xf := _frame(fposmod(offset_at(t) - i * CAR_GAP + CAR_GAP * CARS, length))
	xf.origin += xf.basis.y * 0.42
	return xf


func animate(t: float) -> void:
	for i in CARS:
		_cars[i].global_transform = seat(i, t)


func _car(i: int) -> Node3D:
	var n := Node3D.new()
	Playground.live(n, "car%d" % (i % 3), Vector3.ZERO)  # modelled in art_src/blender/street.py
	return n


func _station(root: Node3D, b: Batch) -> void:
	var c := Playground.CARNIVAL
	var y := 2.9
	Art.col_box(root, Vector3(26, 0.4, 6), c + Vector3(-7, y - 0.2, 40.2))
	Kit.landmark(root, b, "c_station", c + Vector3(-7, y, 40.2))
	Playground.ramp(root, c + Vector3(-7, 0.0, 47.5) + Vector3.UP * (Playground.height(c.x - 7, c.z + 47.5) - c.y + 0.2), c + Vector3(-7, y, 43.2) , 5.0, 0.3, Color("#9c6238"))
	for x: float in [-19.0, -7.0, 5.0]:
		for z: float in [37.8, 42.6]:
			Art.col_cyl(root, 0.18, 5.0, c + Vector3(x, y + 2.5, z))
	Art.label(root, "THE SLOPPER", c + Vector3(-7, y + 6.2, 43.6), 0.02, Ui.YELLOW, false)
	Art.label(root, "keep your limbs inside the concept of a ride", c + Vector3(-7, y + 4.3, 43.6), 0.007, Color.WHITE, false)
