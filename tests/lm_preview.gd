extends SceneTree
## Renders one landmark in the game's real lighting (needs a GPU, so no --headless):
##   godot --path . -s tests/lm_preview.gd -- --lm=saloon --shots=<dir> [--cams=x,y,z,tx,ty,tz;...]
## Default cameras: three-quarter front, player eye level at the door, inside.

var _frame := 0
var _dir := "user://shots"
var _id := "saloon"
var _cam: Camera3D
var _cams: Array = []
var _i := -1


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_dir = a.get_slice("=", 1)
		elif a.begins_with("--lm="):
			_id = a.get_slice("=", 1)
		elif a.begins_with("--cams="):
			for c: String in a.get_slice("=", 1).split(";"):
				var v := c.split_floats(",")
				_cams.append([Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5])])
	if _cams.is_empty():
		_cams = [[Vector3(-22, 8, 34), Vector3(0, 5, 0)], [Vector3(6, 1.9, 19), Vector3(-1, 3.5, 9)],
			[Vector3(-6, 2.6, 7), Vector3(3, 2.0, -6)], [Vector3(26, 6, -22), Vector3(0, 4, 0)]]
	DirAccess.make_dir_recursive_absolute(_dir)
	var w: Node = (load("res://tests/lm_stage.gd") as GDScript).new()
	w.set("lm_id", _id)
	w.name = "StageWorld"
	root.add_child(w)
	_cam = Camera3D.new()
	_cam.far = 900.0
	_cam.fov = 66.0
	root.add_child(_cam)
	_cam.current = true


func _process(_d: float) -> bool:
	_frame += 1
	var hud := root.get_node_or_null("StageWorld/Hud") as CanvasLayer
	if hud:
		hud.visible = false
	if _frame < 12 or _frame % 10 != 0:
		return false
	if _i >= 0:
		root.get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_dir, _id, _i])
	_i += 1
	if _i >= _cams.size():
		print("FPS ", Engine.get_frames_per_second(), " draws ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" prims ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		quit(0)
		return false
	_cam.current = true
	_cam.position = _cams[_i][0]
	_cam.look_at(_cams[_i][1])
	return false
