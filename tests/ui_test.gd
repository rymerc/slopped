extends SceneTree
## Gamepad bindings and the display-mode revert dialog, headless:
##   godot --headless --path . -s tests/ui_test.gd
## Scripts are loaded at run time (after the autoloads exist). Backs up and
## restores the player's real settings file.

const PATH := "user://settings.cfg"
var _fail := false
var _frame := 0
var _menu: Node
var _orig := 0
var _other := 0
var _backup := PackedByteArray()


func _check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		_fail = true


func _pad_button(b: int, down: bool) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = down
	return e


func _pad_axis(a: int, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a
	e.axis_value = v
	return e


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		_gamepad()
		_backup = FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()
		var s: Node = root.get_node("Settings")
		_menu = (load("res://src/ui/settings_menu.gd") as GDScript).new()
		root.add_child(_menu)
		_orig = int(s.g("video", "window_mode"))
		_other = 1 if _orig == 0 else 0
		_menu.call("_display", _other, "window_mode")
		_check(bool(_menu.get("_confirm").visible), "changing the display mode asks to confirm")
		_check(int(s.g("video", "window_mode")) == _other, "the new mode is applied while asking")
		_menu.set("_confirm_t", 0.01)  # let the countdown run out on its own
	elif _frame == 6:
		var s: Node = root.get_node("Settings")
		_check(not bool(_menu.get("_confirm").visible), "the dialog closes when the countdown ends")
		_check(int(s.g("video", "window_mode")) == _orig, "an unanswered change reverts")
		_menu.call("_display", _other, "window_mode")
		_menu.call("_finish_confirm", true)
		_check(int(s.g("video", "window_mode")) == _other, "Keep keeps the new mode")
		_menu.call("_display", _orig, "window_mode")
		_menu.call("_finish_confirm", true)
		_check(int(s.g("video", "window_mode")) == _orig, "and it can be changed back")
		if _backup.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		else:
			FileAccess.open(PATH, FileAccess.WRITE).store_buffer(_backup)
		print("UI ", "FAILED" if _fail else "OK")
		quit(1 if _fail else 0)
	return false


## Every gameplay action has a pad binding, and pad input drives the actions.
func _gamepad() -> void:
	var is_: GDScript = load("res://src/core/input_setup.gd")
	is_.call("ensure")
	var buttons: Dictionary = is_.get("PAD_BUTTONS")
	var axes: Dictionary = is_.get("PAD_AXES")
	for action: String in buttons:
		_check(InputMap.event_is_action(_pad_button(int(buttons[action]), true), action), "pad button drives %s" % action)
	for action: String in axes:
		var ax: Array = axes[action]
		_check(InputMap.event_is_action(_pad_axis(int(ax[0]), float(ax[1])), action), "pad axis drives %s" % action)
	for action: String in ["jump", "dive", "interact", "sprint", "menu", "primary", "secondary", "move_forward", "look_left"]:
		_check(buttons.has(action) or axes.has(action), "%s has a pad binding" % action)
	# through the real Input singleton: press, read, release
	Input.parse_input_event(_pad_button(JOY_BUTTON_A, true))
	Input.parse_input_event(_pad_axis(JOY_AXIS_LEFT_X, 1.0))
	Input.parse_input_event(_pad_axis(JOY_AXIS_RIGHT_Y, -1.0))
	Input.flush_buffered_events()
	_check(Input.is_action_pressed("jump"), "A press reads as jump")
	_check(Input.get_vector("move_left", "move_right", "move_forward", "move_back").x > 0.5, "left stick moves right")
	_check(Input.get_vector("look_left", "look_right", "look_up", "look_down").y < -0.5, "right stick looks up")
	Input.parse_input_event(_pad_button(JOY_BUTTON_A, false))
	Input.parse_input_event(_pad_axis(JOY_AXIS_LEFT_X, 0.0))
	Input.parse_input_event(_pad_axis(JOY_AXIS_RIGHT_Y, 0.0))
	Input.flush_buffered_events()
	_check(not Input.is_action_pressed("jump"), "release clears jump")
	var label: String = is_.call("label", "jump")
	_check(label.length() > 0, "jump has a prompt label (%s)" % label)
