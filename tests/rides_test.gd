extends SceneTree
## Exercises the attractions through the same functions the E prompts call:
## coaster lap, Ferris wheel + jump off, cannon at every target, the toilet, the
## helter-skelter, the hotel ramp, and poker hand ranking.
##   godot --headless --path . -s tests/rides_test.gd -- --host --bots=1

const LIMIT := 170.0

var _start := 0
var _w: Node
var _me: Node3D
var _fail := false
var _stage := 0
var _t0 := 0.0
var _peak := 0.0
var _aim := 0
var _p0 := Vector3.ZERO
var _bot: Node3D


func _initialize() -> void:
	_start = Time.get_ticks_msec()
	change_scene_to_file("res://src/main/main.tscn")


func _t() -> float:
	return (Time.get_ticks_msec() - _start) / 1000.0


func _check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		_fail = true


func _go(s: int) -> void:
	_stage = s
	_t0 = _t()
	_peak = 0.0


func _end() -> void:
	print("RIDES ", "FAILED" if _fail else "OK")
	quit(1 if _fail else 0)


func _process(_d: float) -> bool:
	if _t() > LIMIT:
		_check(false, "timed out at stage %d" % _stage)
		_end()
		return false
	_w = root.get_node_or_null("Main/World")
	if _w == null or _t() < 2.0:
		return false
	_me = _w.local_avatar()
	var el := _t() - _t0
	match _stage:
		0:
			root.get_node("Net").players[1].coins = 500
			for a: Node3D in _w.avatars.values():
				if a.is_bot:
					_bot = a
					root.get_node("Net").players[a.pid].coins = 0
			_me.place(Playground_pos("CARNIVAL") + Vector3(-7, 3.4, 41))
			_go(1)
		1:  # wait for the train, then board through the real function
			if _w._play.coaster.boarding(_w.clock):
				_w._ride_coaster()
				_check(_me.ride.is_valid(), "boarded the coaster")
				_p0 = _me.global_position
				_go(2)
		2:
			_peak = maxf(_peak, _me.global_position.distance_to(_p0))
			if not _me.ride.is_valid():
				_check(_peak > 40.0, "coaster lap covered ground (%.0f m from station) in %.0fs" % [_peak, el])
				_check(_me.global_position.distance_to(Playground_pos("CARNIVAL") + Vector3(-7, 3.4, 41)) < 4.0, "lap ended back at the station")
				_me.place(Playground_pos("FERRIS") + Vector3(0, 0.6, 4))
				_go(3)
			elif el > 75.0:
				_check(false, "coaster lap never finished")
				_end()
		3:  # a gondola comes round, get on, ride up, jump off
			if el > 0.3 and not _me.ride.is_valid():
				_w._ride_ferris()
			if _me.ride.is_valid():
				_peak = maxf(_peak, _me.global_position.y)
				if el > 14.0:
					_check(_peak > 4.0, "ferris wheel lifts you (%.1f m)" % _peak)
					_me.end_ride()
					_me.place(Playground_pos("CANNON") + Vector3(0, 1.2, 7))
					_w._cannon_aim = 0
					_go(4)
			elif el > 40.0:
				_check(false, "never caught a gondola")
				_go(4)
		4:  # each cannon target, through enter / fuse / launch
			if el < 0.3:
				return false
			_w._enter_cannon()
			_check(_w._in_cannon, "climbed into the cannon")
			_w._cannon_aim = _aim
			_w._light_fuse()
			_go(5)
		5:
			if _me.ride.is_valid():
				return false
			var t: Array = _w.CANNON_TARGETS[_aim]
			var to: Vector3 = t[1]
			var off := Vector2(_me.global_position.x - to.x, _me.global_position.z - to.z).length()
			# judged on the way down, at target height: pads bounce you, water respawns you
			var arrived: bool = el > Lobby_fuse() + 0.6 and _me.velocity.y < 0.0 and _me.global_position.y < to.y + 2.5
			if arrived or el > 14.0:
				_check(arrived and off < 16.0, "cannon -> %s landed %.1f m off at %s" % [t[0], off, _me.global_position.snappedf(0.1)])
				_aim += 1
				_me.end_ride()
				_me.place(Playground_pos("CANNON") + Vector3(0, 1.2, 7))
				_me.velocity = Vector3.ZERO
				if _aim < _w.CANNON_TARGETS.size():
					_go(4)
				else:
					_w.req_flush()
					_p0 = _me.global_position
					_go(6)
		6:  # the toilet: spin, then out of somewhere else
			if el > 3.0:
				_check(_me.global_position.distance_to(_p0) > 8.0 or _me.velocity.y > 5.0, "flushed somewhere else (now %s)" % _me.global_position.snappedf(0.1))
				_check((_me.parts.root as Node3D).scale.x > 0.5, "body restored after the flush")
				_check(not _me.ride.is_valid(), "released from the toilet")
				_w.set_physics_process(false)  # bot brain off: this test steers
				_bot.place(Playground_pos("SPIRAL") + Vector3(4.3, 15.0, 0.0))
				_go(7)
		7:  # helter-skelter: the bot runs the spiral from the top, steering round it
			var c: Vector3 = Playground_pos("SPIRAL")
			var rel: Vector3 = _bot.global_position - c
			var a := atan2(rel.z, rel.x)
			var inward := -Vector2(rel.x, rel.z).normalized() * clampf(Vector2(rel.x, rel.z).length() - 4.3, -1.0, 1.0)
			_bot.bot_move = Vector3(-sin(a) + inward.x, 0, cos(a) + inward.y).normalized()
			_peak = maxf(_peak, _bot.global_position.y)
			if el > 16.0 or _bot.global_position.y < 2.0:
				_check(_bot.global_position.y < 3.0, "ran the helter-skelter top to bottom (from %.1f to %.1f m in %.0fs)" % [_peak, _bot.global_position.y, el])
				_poker()
				_end()
	return false


func _poker() -> void:
	var cas: GDScript = load("res://src/lobby/casino.gd")
	# ranks: c % 13, 0 = ace. suits: c / 13
	_check(int(cas.pk_rank([0, 13, 26])[0]) == 4, "three aces is trips")
	_check(int(cas.pk_rank([10, 11, 12])[0]) == 5, "J Q K suited is a straight flush")
	_check(int(cas.pk_rank([10, 24, 12])[0]) == 3, "J Q K offsuit is a straight")
	_check(int(cas.pk_rank([1, 5, 9])[0]) == 2, "same suit is a flush")
	_check(int(cas.pk_rank([1, 14, 9])[0]) == 1, "a pair")
	_w.casino.req_pk_ante(10, 0)
	_check(_w.casino._pk.size() == 1, "poker hand dealt")
	_w.casino.req_pk_fold()
	_check(_w.casino._pk.is_empty(), "fold ends the hand")


func Playground_pos(n: String) -> Vector3:
	return (load("res://src/lobby/playground.gd") as GDScript).get_script_constant_map()[n]


func Lobby_fuse() -> float:
	return _w.FUSE_SECS
