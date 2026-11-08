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
var _bj_w: Node


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
	if _stage == 0 and (w.get_script() as Script).get_global_name() != "Lobby" and t < 10.0:
		return false  # minigames: let the start banner fade first
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
				["island", Vector3(70, 95, 165), Vector3(0, 0, -10)],
				["square", Vector3(4, 3.2, 21), Vector3(0, 4.5, -20)],
				["mainst", Vector3(-3, 3.0, -22), Vector3(14, 3.5, -30)],
				["casino_front", Vector3(11, 2.6, 0), Vector3(30, 7.5, -1)],
				["casino_in", Vector3(31, 2.6, -1), Vector3(46, 1.8, -4)],
				["saloon_in", Vector3(-27, 2.6, -27), Vector3(-16, 1.5, -38)],
				["slide_hill", Vector3(5, 7, -22), Vector3(0, 18, -85)],
				["chasm", Vector3(-42, 12, 34), Vector3(-80, 2, 0)],
				["yard", Vector3(60, 8, 24), Vector3(95, 4, -10)],
				["meadow", Vector3(-14, 5, 52), Vector3(14, 1, 92)],
				["cove", Vector3(-62, 7, 70), Vector3(-104, 1.5, 96)],
				["pier", Vector3(-100, 4, 88), Vector3(-130, 5, 122)],
				["carnival", Vector3(64, 6, -62), Vector3(98, 9, -100)],
				["deeds", Vector3(36, 2.4, -14), Vector3(31, 2.6, -13.4)],
				["cannon", Vector3(100, 5, -18), Vector3(92, 3, -30)],
				["coaster", Vector3(50, 12, -30), Vector3(90, 6, -60)],
				["bank", Vector3(36, 3, 78), Vector3(45, 4, 92)],
				["cave_in", Vector3(-21, 2.2, 104), Vector3(-15, 1.2, 104)],
				["hotel_up", Vector3(9.2, 7.7, 39.2), Vector3(14, 7.0, 33)],
				["sign", Vector3(-1, 2.2, -41), Vector3(-5, 2, -46)],
				["gauntlet", Vector3(-46, 6, 20), Vector3(-75, 2, 12)],
				["gauntlet_far", Vector3(-80, 8, 24), Vector3(-100, 4, 12)],
				["kickers", Vector3(3, 3.5, 78), Vector3(3, 1.5, 92)],
				["lane", Vector3(-37, 2.2, 47), Vector3(-40, 0.6, 70)],
				["yard_close", Vector3(70, 5, 8), Vector3(84, 4, -20)],
				["props_close", Vector3(58, 2.2, 10), Vector3(62, 0.8, 14)],
				["plate_ledge", Vector3(-55, 3.5, 54), Vector3(-62, 1.5, 48)],
				["stalls", Vector3(92, 4, -66), Vector3(104, 2, -70)],
				["crane", Vector3(88, 10, -10), Vector3(102, 25, -28)],
				["trough", Vector3(-20, 2.2, -16), Vector3(-24, 0.6, -19)],
				["saloon_up", Vector3(-30, 7.4, -25.5), Vector3(-15, 3.0, -36)],
				["saloon_ext", Vector3(-50, 6, -12), Vector3(-30, 4, -30)],
				["hotel_bal", Vector3(26, 8.4, 17), Vector3(18, 6.8, 26)],
				["npc_props", Vector3(-21, 2.3, -31.5), Vector3(-22, 1.5, -39.5)],
				["npc_stare", Vector3(0, 2.0, 12), Vector3(-3, 1.6, 3)],
				["slot_view", Vector3(34, 1.95, -16.1), Vector3(34, 1.72, -18.4)],
				["slot_row", Vector3(40, 2.6, -13.5), Vector3(33, 2.0, -18.4)],
				["wheel_view", Vector3(42.8, 3.8, 7), Vector3(49.8, 4, 7)],
				["crash_view", Vector3(46.2, 2.7, -10.5), Vector3(51.8, 2.9, -10.5)],
				["bj_view", Vector3(41.5, 3.4, 3.2), Vector3(41.5, 0.9, 6.6)],
				["casino_wide", Vector3(30, 4.6, -3), Vector3(46, 1.0, 3)],
			]
			w.casino.req_slots(1)
			w.casino.req_wheel()
			w.casino.req_crash_start(10)
			w.casino.req_bj_bet(10, 2)
			_bj_w = w
		elif name == "PocketGod":
			_shots = [["pocket", Vector3(34, 24, 60), Vector3(0, 3, 0)], ["pocket_low", Vector3(14, 6, 26), Vector3(0, 7, 0)],
				["pocket_camp", Vector3(-9, 4.5, 24), Vector3(0, 1.5, 35)], ["pocket_camp2", Vector3(7, 3.0, 28), Vector3(-1, 1.2, 36)],
				["pocket_shrine", Vector3(29, 8.5, 7), Vector3(38, 6, 0)], ["pocket_pad", Vector3(11, 9, 14), Vector3(0, 8, -2)],
				["pocket_hand", Vector3(-30, 9, -14), Vector3(-40, 5, -20)]]
			_fx(w, "hand", Vector3(-40, 6, -20))
		elif name == "SoupGame":
			_shots = [["soup", Vector3(0, 46, 40), Vector3(0, 6, 0)], ["soup_low", Vector3(8, 3, 11), Vector3(-14, 6, -8)],
				["soup_raft", Vector3(10, 4, 10), Vector3(0, -0.5, 0)], ["soup_rim", Vector3(0, 30, 0), Vector3(-15, 40, -22)], ["soup_sign", Vector3(-6, 30, 0), Vector3(29, 34, 0)],
				["soup_rim2", Vector3(0, 30, 0), Vector3(20, 40, 18)], ["soup_ladle", Vector3(0, 46, 40), Vector3(-25, 30, 25)]]
			_fx(w, "ladle", Vector3(-25, 25, 25))
			w.set("soup_y", -1.2)  # just under the raft top, so nobody is cooked
			w.set("_grace", 999.0)
		elif name == "CursedCasino":
			_shots = [["cursed", Vector3(31, 3, -2), Vector3(46, 1.5, -4)], ["cursed_door", Vector3(34, 2.6, 0), Vector3(28.1, 2.4, -1)],
				["cursed_side", Vector3(40, 2.6, 10), Vector3(40, 2.0, 18)], ["cursed_floor", Vector3(40, 3.2, 4), Vector3(37, 0, 0.5)]]
		else:
			_shots = [["arena", Vector3(30, 26, 60), Vector3(0, 0, 0)], ["arena_low", Vector3(10, 3, 22), Vector3(0, 3, 0)],
				["arena_hut", Vector3(37, 2.4, 20.5), Vector3(29, 1.8, 15.8)], ["arena_fence", Vector3(28, 3, 28), Vector3(46, 2.5, 40)],
				["arena_pillars", Vector3(0, 4, -17), Vector3(0, 2, 0)], ["arena_rack", Vector3(17.5, 2.2, 15), Vector3(20.8, 1.2, 12)]]
	if _wait > 0:
		_wait -= 1
		return false
	if _stage > 1 and _stage < 100:
		var img := root.get_viewport().get_texture().get_image()
		var n: String = _shots[_stage - 2][0]
		img.save_png("%s/%s.png" % [_dir, n])
		print("saved ", n)
	if _stage - 1 >= _shots.size():
		if w.get("_settings") != null and _dir.length() > 0 and _stage < 100:
			_stage = 100
			w.set_mouse_captured(false)
			w._open_settings()
			_wait = 10
			return false
		if _stage >= 100:
			var tabs := ["Video", "Audio", "Controls", "Gameplay"]
			var i := _stage - 100
			if i > 0:
				root.get_viewport().get_texture().get_image().save_png("%s/settings_%s.png" % [_dir, tabs[i - 1]])
			if i < 4:
				w._settings._show_tab(i)
				_stage += 1
				_wait = 6
				return false
		quit(0)
		return false
	if _bj_w and _stage == _shots.size() - 1:  # hold the last shots until cards are out
		var st: String = str(_bj_w.casino.bj.state)
		if st == "betting" or st == "idle":
			_wait = 150  # then let the whole deal land
			return false
	var s: Array = _shots[_stage - 1]
	_cam.global_position = s[1]
	_cam.look_at(s[2])
	_cam.current = true
	_wait = 20
	_stage += 1
	return false


## Parks a copy of a transient effect mesh (god hand, tasting ladle) for a still.
func _fx(w: Node3D, part: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	# loaded at run time: naming these classes here would compile them before the autoloads exist
	mi.mesh = (load("res://src/art/kit.gd") as GDScript).call("part_mesh", "game_bits", part)
	mi.material_override = (load("res://src/art/art.gd") as GDScript).call("vcol_mat")
	w.add_child(mi)
	mi.global_position = pos


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
