extends SceneTree
## Renders review screenshots (needs a GPU, so run WITHOUT --headless):
##   godot --path . -s tests/screenshot.gd -- --host --bots=3 [--giant] --shots=<dir>
## Lobby: costume lineup + one shot per island zone. Giant: arena overview.

var _start := 0
var _dir := "user://shots"
var _stage := 0
var _wait := 0
var _cam: Camera3D
var _shots: Array = []


func _initialize() -> void:
	_start = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_dir)
	change_scene_to_file("res://src/main/main.tscn")


func _process(_d: float) -> bool:
	var w := root.get_node_or_null("Main/World")
	var t := (Time.get_ticks_msec() - _start) / 1000.0
	if t > 90.0:
		quit(1)
	if w == null or t < 4.0:
		return false
	if _stage == 0:
		_stage = 1
		_cam = Camera3D.new()
		_cam.far = 900.0
		_cam.fov = 60.0
		w.add_child(_cam)
		_cam.current = true
		var name := (w.get_script() as Script).get_global_name()
		if name == "Lobby":
			_lineup(w)
			var me: Node = w.local_avatar()
			me.place(Vector3(1.5, 0.5, 11.5))
			me.start_ragdoll(Vector3(-3, 7, 0))
			_shots = [
				["ragdoll", Vector3(0, 1.7, 15.2), Vector3(0, 1.0, 9.0)],
				["lineup", Vector3(0, 1.7, 15.2), Vector3(0, 1.0, 9.0)],
				["island", Vector3(60, 85, 150), Vector3(0, 0, -10)],
				["slide_hill", Vector3(30, 14, -30), Vector3(0, 18, -85)],
				["chasm", Vector3(-42, 12, 34), Vector3(-80, 2, 0)],
				["construction", Vector3(48, 10, 30), Vector3(85, 4, -10)],
				["meadow", Vector3(-10, 9, 40), Vector3(20, 1, 85)],
				["lounge", Vector3(18, 9, 22), Vector3(0, 1, 0)],
			]
		else:
			_shots = [["arena", Vector3(30, 26, 60), Vector3(0, 0, 0)], ["arena_low", Vector3(10, 3, 22), Vector3(0, 3, 0)]]
	if _wait > 0:
		_wait -= 1
		return false
	if _stage > 1:
		var img := root.get_viewport().get_texture().get_image()
		var n: String = _shots[_stage - 2][0]
		img.save_png("%s/%s.png" % [_dir, n])
		print("saved ", n)
	if _stage - 1 >= _shots.size():
		quit(0)
		return false
	var s: Array = _shots[_stage - 1]
	_cam.global_position = s[1]
	_cam.look_at(s[2])
	_cam.current = true
	_wait = 20
	_stage += 1
	return false


func _lineup(w: Node3D) -> void:
	var chars_script: GDScript = load("res://src/art/chars.gd")
	var kinds: Array = chars_script.KINDS
	var cols := [Color("#3ec1ff"), Color("#7ccf4e"), Color("#ff8a3d"), Color("#3ec1ff"), Color("#8b5cf6"), Color("#ffd23f")]
	for i in kinds.size():
		var p: Dictionary = chars_script.build({"body": kinds[i], "color": cols[i], "hat": "none"})
		var r: Node3D = p.root
		w.add_child(r)
		r.global_position = Vector3(-3.75 + i * 1.5, 0.0, 9.0)
		r.rotation.y = PI + (0.25 if i < 3 else -0.25)
