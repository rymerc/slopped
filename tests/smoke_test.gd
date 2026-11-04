extends SceneTree
## Headless smoke test. Boots the real game as host with bots and checks that
## worlds load and the core loop runs. Duck-typed on purpose (no class_name
## refs) so it compiles before the Net autoload is registered.
##   godot --headless --path . -s tests/smoke_test.gd -- --host --bots=4 --giant
##   godot --headless --path . -s tests/smoke_test.gd -- --host --bots=3

const TIMEOUT_MS := 40000

var _fail := false
var _start_ms := 0
var _stage := 0
var _t0 := 0.0


func _initialize() -> void:
	_start_ms = Time.get_ticks_msec()
	change_scene_to_file("res://src/main/main.tscn")


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fail = true


func _world() -> Node:
	return root.get_node_or_null("Main/World")


func _world_name() -> String:
	var w := _world()
	return (w.get_script() as Script).get_global_name() if w else ""


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


func _process(_delta: float) -> bool:
	var w := _world()
	if Time.get_ticks_msec() - _start_ms > TIMEOUT_MS:
		_check(false, "timed out at stage %d (world=%s)" % [_stage, _world_name()])
		_finish()
		return false
	match _stage:
		0:
			if w and _elapsed() > 1.0:
				print("world: ", _world_name())
				_check(w.avatars.size() >= 2, "avatars spawned (%d)" % w.avatars.size())
				_t0 = _elapsed()
				_stage = 1 if _world_name() == "GiantGame" else 10
		1:  # giant game: let bots play for 12s
			if w.rules.active and _t0 == 0.0:
				_t0 = _elapsed()
			if _elapsed() - _t0 > 12.0:
				var r: Node = w.rules
				print("time_left=%.1f bind=%.1f eyes=%s alive=%s spears=%s" % [
					r.time_left, r.bind, r.eye_hp, r.alive, r.spears])
				_check(r.active, "rules active")
				_check(r.time_left < 329.0, "clock ticking")
				var thrown := 0
				for id: int in r.spears:
					thrown += r.max_spears(id) - int(r.spears[id])
				_check(thrown > 0 or r.eye_hp != [3, 3], "bots threw spears")
				var moved := false
				for av: Node3D in w.avatars.values():
					if av.global_position.distance_to(w.spawn_for(av, 0)) > 3.0:
						moved = true
				_check(moved, "avatars moved")
				_finish()
		10:  # lobby: press start, expect the wheel to launch the minigame
			if _elapsed() - _t0 > 2.0:
				w.req_start()
				_stage = 11
		11:
			if _world_name() == "GiantGame":
				_check(true, "wheel launched GIANT HUNT (modifier=%s)" % w.modifier)
				_finish()
	return false


func _finish() -> void:
	print("SMOKE ", "FAILED" if _fail else "OK")
	quit(1 if _fail else 0)
