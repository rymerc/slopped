extends SceneTree
## Measures the lobby from a player-height camera (needs a GPU, no --headless):
##   godot --path . -s tests/perf_probe.gd -- --host --bots=3
## Prints world build time, then draw calls / primitives / frame time at each view.

const VIEWS := [["spawn", Vector3(0, 2.6, 16), Vector3(0, 3, -20)], ["street", Vector3(-20, 2.6, -10), Vector3(30, 3, -1)],
	["overview", Vector3(70, 95, 165), Vector3(0, 0, -10)], ["east", Vector3(60, 8, 24), Vector3(95, 4, -10)]]

var _start := 0
var _cam: Camera3D
var _i := 0
var _frames := 0
var _sum := 0.0
var _max := 0.0
var _built := false


func _initialize() -> void:
	_start = Time.get_ticks_msec()
	change_scene_to_file("res://src/main/main.tscn")


func _process(delta: float) -> bool:
	var w := root.get_node_or_null("Main/World")
	if w == null:
		return false
	if not _built:
		_built = true
		print("first world frame after %d ms" % (Time.get_ticks_msec() - _start))
		_cam = Camera3D.new()
		_cam.far = 900.0
		_cam.fov = 72.0
		w.add_child(_cam)
		_set_view()
		return false
	_cam.current = true
	_frames += 1
	if _frames < 30:
		return false
	_sum += delta
	_max = maxf(_max, delta)
	if _frames < 120:
		return false
	var rs := RenderingServer
	print("%-9s draws %5d  prims %7d  objects %5d  avg %.2f ms  max %.2f ms" % [VIEWS[_i][0],
		rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), _sum / 90.0 * 1000.0, _max * 1000.0])
	_i += 1
	if _i >= VIEWS.size():
		print("video mem %.0f MB" % (rs.get_rendering_info(rs.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0))
		quit(0)
		return false
	_frames = 0
	_sum = 0.0
	_max = 0.0
	_set_view()
	return false


func _set_view() -> void:
	_cam.current = true
	_cam.global_position = VIEWS[_i][1]
	_cam.look_at(VIEWS[_i][2])
