extends SceneTree
## Headless bot-vs-bot balance sim. Prints every announcement + final state.
##   godot --headless --path . -s tests/match_sim.gd -- --host --bots=5 --giant --bot-giant
## Optional: --sim-seconds=N (default 90)

var _start := 0
var _limit := 90.0
var _hooked := false


func _initialize() -> void:
	_start = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sim-seconds="):
			_limit = float(a.get_slice("=", 1))
	change_scene_to_file("res://src/main/main.tscn")


func _process(_d: float) -> bool:
	var t := (Time.get_ticks_msec() - _start) / 1000.0
	var net := root.get_node_or_null("Net")
	if net and not _hooked:
		_hooked = true
		net.announced.connect(func(m: String) -> void: print("[%5.1fs] %s" % [(Time.get_ticks_msec() - _start) / 1000.0, m]))
	var w := root.get_node_or_null("Main/World")
	var done: bool = w != null and w.get("rules") != null and w.rules.over
	if t > _limit or done:
		if w and w.get("rules"):
			var r: Node = w.rules
			print("END t=%.0fs over=%s bind=%.0f eyes=%s alive=%s" % [t, r.over, r.bind, r.eye_hp, r.alive])
		quit()
	return false
