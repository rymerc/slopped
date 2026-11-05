extends SceneTree
## Two-process multiplayer check. Run a host, then this as the client:
##   godot --headless --path . -- --host --bots=1            (host)
##   godot --headless --path . -s tests/net_test.gd -- --join=127.0.0.1
## Verifies the client builds the identical world, gets props from the host, sees
## its own avatar, and can play a casino game through the host (including the
## new machine-animation broadcast).

var _start := 0
var _fail := false
var _stage := 0
var _result := ""


func _initialize() -> void:
	_start = Time.get_ticks_msec()
	change_scene_to_file("res://src/main/main.tscn")


func _check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		_fail = true


func _process(_d: float) -> bool:
	var t := (Time.get_ticks_msec() - _start) / 1000.0
	var w := root.get_node_or_null("Main/World")
	if t > 30.0:
		_check(false, "timed out at stage %d" % _stage)
		_stage = 9
	match _stage:
		0:
			if w and t > 3.0 and w.get("casino") != null:
				_check(not multiplayer_is_server(w), "running as a real client (peer %d)" % w.multiplayer.get_unique_id())
				_check(w.avatars.size() >= 2, "sees host + bot + self (%d avatars)" % w.avatars.size())
				_check(w.local_avatar() != null, "own avatar spawned")
				print("props on client: ", w.props.list.size())
				_check(w.props.list.size() > 90, "props built (%d)" % w.props.list.size())
				w.casino.result.connect(func(k: String, d: Dictionary) -> void:
					_result = k + ": " + str(d.get("msg", "")))
				w.casino.rpc_id(1, "req_roulette", "red")
				_stage = 1
		1:
			if _result != "":
				_check(_result.begins_with("roulette"), "roulette round trip: " + _result)
				_result = ""
				w.casino.rpc_id(1, "req_slots")
				_stage = 2
		2:
			if _result != "":
				_check(_result.begins_with("slots"), "slots round trip: " + _result)
				_check(not w._slot_spin.is_empty(), "slot machine animation reached this client")
				_stage = 9
		9:
			print("NET ", "FAILED" if _fail else "OK")
			quit(1 if _fail else 0)
	return false


func multiplayer_is_server(w: Node) -> bool:
	return w.multiplayer.is_server()
