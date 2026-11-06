extends SceneTree
## Headless walk-through: a real Avatar physically walks from the square to every
## station, through the doors, using the normal movement code. If a collider
## blocks a doorway or a station is out of reach, this fails.
##   godot --headless --path . -s tests/town_test.gd -- --host --bots=1

const REACH := 2.6
const STUCK_SECS := 6.0

var _routes: Array = []
var _i := -1
var _leg := 0
var _av: Node3D
var _w: Node
var _start := 0
var _t := 0.0
var _fail := 0
var _last_pos := Vector3.ZERO
var _stall := 0.0
var _cannon_stage := 0
var _cannon_t := 0.0
var _peak := 0.0


func _initialize() -> void:
	_start = Time.get_ticks_msec()
	change_scene_to_file("res://src/main/main.tscn")


func _pb(p: Vector3) -> Vector3:
	return p


func _build_routes() -> void:
	var lb: GDScript = load("res://src/lobby/lobby_builder.gd")
	var pg: GDScript = load("res://src/lobby/playground.gd")
	var saloon_door := Vector3(-21, 0.4, -22)
	var sheriff_door := Vector3(17, 0.4, -22.5)
	var store_door := Vector3(-17, 0.4, 23)
	var hotel_door := Vector3(19, 0.4, 22)
	var casino_door := Vector3(26, 0, -1)
	var c: Dictionary = lb.get_script_constant_map()
	var p: Dictionary = pg.get_script_constant_map()
	_routes = [
		["start button", [c.START_BTN + Vector3(0, 0, 3)]],
		["bar", [saloon_door, Vector3(-21, 0.4, -30), c.BAR + Vector3(0, 0, 3)]],
		["sheriff jail", [Vector3(-21, 0.4, -30), saloon_door, Vector3(5, 0, -16), sheriff_door, Vector3(19, 0.4, -29.5), c.KENNEL + Vector3(-3, 0, -0.9)]],
		["adopt -> release", [Vector3(19, 0.4, -33.5), c.KENNEL + Vector3(5, 0, -0.9)]],
		["store", [Vector3(19, 0.4, -29), sheriff_door, store_door, Vector3(-17, 0.4, 29), c.SHOP]],
		["hotel", [Vector3(-17, 0.4, 29), store_door, hotel_door, Vector3(19, 0.4, 28), c.BODY]],
		["paint", [c.PAINT]],
		["casino", [Vector3(19, 0.4, 28), hotel_door, casino_door, Vector3(31, 0, -1), Vector3(40, 0, -3), c.CRASH + Vector3(-1.4, 0, 0)]],
		["slots", [Vector3(47.5, 0, -14), c.SLOTS[3] + Vector3(0, 0, 1.2)]],
		["ducks", [Vector3(40, 0, -2), c.DUCKS + Vector3(2.4, 0, 0)]],
		["blackjack seat", [Vector3(37.8, 0, 5.0), Vector3(38.2, 0, 1.2), Vector3(41.5, 0, 1.5), c.BJ_TABLE + Vector3(0, 0, -3.0)]],
		["wheel", [Vector3(45.8, 0, 3.5), c.MINIWHEEL + Vector3(-3.6, -0.6, 0)]],
		["casino side door", [Vector3(46.4, 0, 11.5), Vector3(44, 0, 13), Vector3(40, 0, 15), Vector3(40, 0, 21)]],
		["chaos yard", [Vector3(60, 0.3, 21)]],
		["run along the storefronts", [Vector3(26, 0, 21), Vector3(-30, 0, 21)]],
		["outhouse", [c.TOILET]],
		["meadow via arch", [Vector3(-3, 0, 21), Vector3(0, 0, 40), Vector3(0, 0.5, 56)]],
		["cove bar", [Vector3(-14, 0.5, 50), Vector3(-60, 0.5, 70), p.BAR2 + Vector3(0, 0, 9)]],
		["pier", [p.PIER_START - p.PIER_DIR * 8.0, p.PIER_START + Vector3(0, 0.6, 0), p.PIER_START + p.PIER_DIR * 44.0 + Vector3(0, 0.6, 0)]],
	]


func _process(delta: float) -> bool:
	if (Time.get_ticks_msec() - _start) / 1000.0 > 170.0:
		print("TIMEOUT at route ", _i, " leg ", _leg, " pos ", _av.global_position, " goal ", _routes[_i][1][_leg], " hexes ", _av.hexes, " perks ", root.get_node("Net").perks_of(_av.pid), " stall ", _stall)
		quit(1)
		return false
	_w = root.get_node_or_null("Main/World")
	if _w == null or (Time.get_ticks_msec() - _start) < 1500:
		return false
	if _av == null:
		_w.set_physics_process(false)  # stop the bot brain; we steer
		for a: Node3D in _w.avatars.values():
			if a.is_bot:
				_av = a
				root.get_node("Net").players[a.pid].coins = 0  # no bot tricks: same walk every run
		_build_routes()
		_next_route()
		return false
	if _cannon_stage > 0:
		_cannon(delta)
		return false
	var r: Array = _routes[_i]
	var pts: Array = r[1]
	var goal: Vector3 = pts[_leg]
	var to: Vector3 = goal - _av.global_position
	to.y = 0.0
	if to.length() < REACH if _leg == pts.size() - 1 else to.length() < 1.6:
		_leg += 1
		_t = 0.0
		if _leg >= pts.size():
			print("PASS ", r[0])
			_next_route()
		return false
	_av.bot_move = to.normalized()
	_t += delta
	if _av.global_position.distance_to(_last_pos) > 0.5:
		_last_pos = _av.global_position
		_stall = 0.0
	else:
		_stall += delta
	if _stall > STUCK_SECS:
		var hit: KinematicCollision3D = _av.get_last_slide_collision()
		print("FAIL ", r[0], " stuck at ", _av.global_position.snappedf(0.1), " heading to ", goal,
			" against ", hit.get_collider() if hit else "nothing", " at ", hit.get_position().snappedf(0.1) if hit else Vector3.ZERO)
		_fail += 1
		_stall = 0.0
		_av.place(pts[-1] + Vector3(0, 0.5, 0))
		_next_route()
	return false


func _next_route() -> void:
	_i += 1
	_leg = 0
	_stall = 0.0
	if _i >= _routes.size():
		_cannon_stage = 1
		return
	# carry on from wherever we are: routes chain together


func _cannon(delta: float) -> void:
	var p: GDScript = load("res://src/lobby/playground.gd")
	var c: Dictionary = p.get_script_constant_map()
	match _cannon_stage:
		1:
			_av.bot_move = Vector3.ZERO
			_av.place(c.CANNON + Vector3(0, 1.0, 7.0))
			_cannon_t = 0.0
			_cannon_stage = 2
		2:
			_cannon_t += delta
			if _cannon_t > 0.5:
				_av.global_position = c.CANNON + _w.CANNON_MOUTH
				_av.velocity = _w.CANNON_VEL
				_av.floor_vis = false
				_cannon_t = 0.0
				_peak = 0.0
				_cannon_stage = 3
		3:
			_cannon_t += delta
			_peak = maxf(_peak, _av.global_position.y)
			if _cannon_t > 0.5 and _av.is_on_floor():
				var d := Vector2(_av.global_position.x - c.LANDING.x, _av.global_position.z - c.LANDING.z).length()
				print("cannon flight %.1fs, peak %.1f m, landed %.1f m from target at %s" % [_cannon_t, _peak, d, _av.global_position.snappedf(0.1)])
				if d > 7.0:
					print("FAIL cannon misses the landing zone")
					_fail += 1
				else:
					print("PASS cannon")
				print("TOWN ", "FAILED %d" % _fail if _fail > 0 else "OK")
				quit(1 if _fail > 0 else 0)
			elif _cannon_t > 12.0:
				print("FAIL cannon never landed")
				quit(1)
