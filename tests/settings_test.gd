extends SceneTree
## Settings persistence + rebinding, headless:
##   godot --headless --path . -s tests/settings_test.gd
## Backs up and restores the player's real settings file around the test.

const PATH := "user://settings.cfg"
var _fail := false
var _frame := 0


func _check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		_fail = true


func _process(_d: float) -> bool:
	_frame += 1
	if _frame != 3:
		return false
	var s: Node = root.get_node("Settings")
	var backup := FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()
	var is_: GDScript = load("res://src/core/input_setup.gd")

	# audio buses exist and sliders reach them
	for b: String in ["Music", "Effects", "Movement", "Ambience", "Interface"]:
		_check(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)
	s.s("audio", "movement", 0.25)
	var db_low := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Movement"))
	s.s("audio", "movement", 1.0)
	_check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Movement")) > db_low + 10.0, "movement slider changes its bus")
	s.s("audio", "movement", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Movement")), "slider at zero mutes")

	# presets + detection of Custom
	s.apply_preset("Low")
	_check(s.preset_name() == "Low", "Low preset applies")
	s.s("video", "msaa", 2)
	_check(s.preset_name() == "Custom", "manual change reads as Custom")

	# rebinding swaps instead of leaving an action unbound
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E  # currently "interact"
	var swapped: String = is_.rebind("jump", ev)
	_check(swapped == "interact", "binding jump to E swaps with interact (got %s)" % swapped)
	_check(InputMap.action_has_event("jump", ev), "jump now fires on E")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	_check(InputMap.action_has_event("interact", space), "interact took jump's old key")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	is_.rebind("dive", mb)
	_check(is_.label("dive") == "MMB", "mouse buttons bind and label")

	# defaults + round trip through disk
	s.s("controls", "sensitivity", 1.75)
	s.s("gameplay", "fov", 90.0)
	s.save()
	var cfg := ConfigFile.new()
	_check(cfg.load(PATH) == OK, "settings file written")
	_check(is_equal_approx(float(cfg.get_value("controls", "sensitivity")), 1.75), "sensitivity saved")
	_check(is_equal_approx(float(cfg.get_value("gameplay", "fov")), 90.0), "fov saved")
	_check((cfg.get_value("controls", "binds") as Dictionary).has("jump"), "rebinds saved")
	s.reset_section("controls")
	var space2 := InputEventKey.new()
	space2.physical_keycode = KEY_SPACE
	_check(InputMap.action_has_event("jump", space2), "reset restores default keys")
	_check(is_equal_approx(float(s.g("controls", "sensitivity")), 1.0), "reset restores sensitivity")

	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	else:
		FileAccess.open(PATH, FileAccess.WRITE).store_buffer(backup)
	print("SETTINGS ", "FAILED" if _fail else "OK")
	quit(1 if _fail else 0)
	return false
