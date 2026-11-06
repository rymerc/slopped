extends SceneTree
## Plays one new minigame with bots, headless, and checks its win path.
##   godot --headless --path . -s tests/games_test.gd -- --host --bots=4 --game=pocket [--bot-boss]
## Also exercises the Dirty Deeds system: buys, fires, wards, mirrors, hexes.

const LIMIT := 60.0

var _start := 0
var _fail := false
var _stage := 0
var _t0 := 0.0
var _game := ""
var _w: Node
var _log := -1
var _best := -99.0


func _initialize() -> void:
	_start = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--game="):
			_game = a.get_slice("=", 1)
	change_scene_to_file("res://src/main/main.tscn")


func _t() -> float:
	return (Time.get_ticks_msec() - _start) / 1000.0


func _check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		_fail = true


func _done() -> void:
	print("GAME ", _game, " ", "FAILED" if _fail else "OK")
	quit(1 if _fail else 0)


func _process(_d: float) -> bool:
	if _t() > LIMIT:
		_check(false, "timed out at stage %d" % _stage)
		_done()
		return false
	_w = root.get_node_or_null("Main/World")
	if _w == null or _t() < 2.0:
		return false
	var net: Node = root.get_node("Net")
	match _stage:
		0:
			_check(_w.active, "match running")
			_check(_w.mortals().size() >= 2, "roster (%d mortals)" % _w.mortals().size())
			_tricks(net)
			_blackjack()
			_t0 = _t()
			_stage = 1
		1:  # let the bots play
			if _game == "soup" and _w.get("soup_y") != null and int(_t()) % 3 == 0 and int(_t()) != _log:
				_log = int(_t())
				var ys: Array = _w.alive_mortals().map(func(a: Node3D) -> String: return "%.1f" % a.global_position.y)
				print("t=%d soup %.1f veg %s" % [_log, _w.soup_y, ys])
			if _game == "soup" and _w.has_method("alive_mortals"):
				for av: Node3D in _w.alive_mortals():
					_best = maxf(_best, av.global_position.y)
			if _w.get_script().get_global_name() == "Lobby":
				# soup can legitimately finish early: the last vegetable wins
				_check(_game == "soup" and _best > 5.0, "match ended early (best climb %.1f m)" % _best)
				_done()
				return false
			if _t() - _t0 > (28.0 if _game == "soup" else 10.0):
				_watch()
				_force_end()
				_stage = 2
		2:
			if _w.get_script().get_global_name() == "Lobby" or _w.over:
				_check(true, "match ended cleanly")
				_t0 = _t()
				_stage = 3
		3:
			if _w.get_script().get_global_name() == "Lobby":
				_check(true, "returned to the lobby")
				_done()
	return false


func _blackjack() -> void:
	var cas: GDScript = load("res://src/lobby/casino.gd")
	_check(cas.bj_total([0, 12]) == 21, "ace + king is 21")
	_check(cas.bj_total([0, 0, 8]) == 21, "soft aces count down (A A 9)")
	_check(cas.bj_total([12, 11, 1]) == 22, "K Q 2 busts")


func _tricks(net: Node) -> void:
	var ts: Node = _w.tricks
	var me: int = 1
	var victim: int = _w.mortals().filter(func(i: int) -> bool: return i != me)[0]
	var av: Node = _w.avatars[victim]
	net.players[me].bag = ["stuck_w", "cement", "audit"]
	ts.do_use(me, "stuck_w", victim)
	_check(av.hexed("no_w"), "stuck W lands")
	_check(not net.players[me].bag.has("stuck_w"), "item is spent")
	ts.do_use(me, "stuck_w", victim)
	_check(net.players[me].bag.size() == 2, "cannot fire what you don't own")
	net.players[victim].ward = 1
	ts.do_use(me, "cement", victim)
	_check(not av.hexed("no_jump") and int(net.players[victim].ward) == 0, "lawyer blocks and is used up")
	net.players[victim].mirror = 1
	net.players[victim].coins = 100
	net.players[me].coins = 1000
	ts.do_use(me, "audit", victim)
	_check(int(net.players[me].coins) == 700 and int(net.players[victim].coins) == 400, "uno reverse audits the sender")


func _watch() -> void:
	match _game:
		"pocket":
			_check(_w.rocket > 0 or _w.mutiny > 0.0, "bots built or prayed (rocket %d, mutiny %.0f)" % [_w.rocket, _w.mutiny])
		"soup":
			_check(_w.soup_y > -1.0, "soup is rising (%.1f)" % _w.soup_y)
			_check(_best > 5.0, "bots are climbing (%.1f m)" % _best)
		"cursed":
			var moved := false
			for id: int in _w.casino.chips:
				if int(_w.casino.chips[id]) != 100:
					moved = true
			_check(moved or _w.casino.house_bank > 0, "chips changed hands (bank %d)" % _w.casino.house_bank)


func _force_end() -> void:
	match _game:
		"pocket":
			_w.rocket = _w.need
		"soup":
			_w.soup_y = 60.0
		"cursed":
			_w.time_left = 0.0
