class_name InputSetup
extends RefCounted
## Registers all input actions in code so project.godot stays readable.
## Every action has one rebindable keyboard/mouse slot (the first entry here),
## fixed alternates, and fixed gamepad bindings. Rebinds are stored by action in
## Settings as {action: {"key": physical_keycode} | {"mouse": button_index}}.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"dive": [KEY_C, KEY_CTRL],
	"interact": [KEY_E],
	"ability_1": [KEY_Q],
	"ability_2": [KEY_F],
	"god": [KEY_G],
	"scoreboard": [KEY_TAB],
	"menu": [KEY_ESCAPE],
}

const MOUSE := {
	"primary": MOUSE_BUTTON_LEFT,
	"secondary": MOUSE_BUTTON_RIGHT,
}

const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"dive": JOY_BUTTON_B,
	"interact": JOY_BUTTON_X,
	"ability_1": JOY_BUTTON_Y,
	"ability_2": JOY_BUTTON_LEFT_SHOULDER,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"god": JOY_BUTTON_RIGHT_SHOULDER,
	"scoreboard": JOY_BUTTON_BACK,
	"menu": JOY_BUTTON_START,
}

## action -> [axis, sign]
const PAD_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"primary": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"secondary": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}

## Display order + names for the Controls screen.
const REBINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
	["move_right", "Move right"], ["jump", "Jump"], ["sprint", "Sprint"], ["dive", "Dive / slide"],
	["interact", "Use / grab"], ["primary", "Shove / throw"], ["secondary", "Secondary"],
	["ability_1", "Ability 1"], ["ability_2", "Ability 2"], ["god", "Smite (leader)"],
	["scoreboard", "Scoreboard"],
]

static var _custom: Dictionary = {}


static func ensure() -> void:
	for action: String in KEYS:
		_rebuild(action)
	for action: String in MOUSE:
		_rebuild(action)
	for action: String in PAD_AXES:
		if not InputMap.has_action(action):
			_rebuild(action)


static func _rebuild(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.2)
	InputMap.action_add_event(action, _primary_event(action))
	var keys: Array = KEYS.get(action, [])
	for i in range(1, keys.size()):
		InputMap.action_add_event(action, _key(keys[i]))
	if PAD_BUTTONS.has(action):
		var b := InputEventJoypadButton.new()
		b.button_index = PAD_BUTTONS[action] as JoyButton
		InputMap.action_add_event(action, b)
	if PAD_AXES.has(action):
		var m := InputEventJoypadMotion.new()
		m.axis = PAD_AXES[action][0] as JoyAxis
		m.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, m)


static func _key(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k as Key
	return ev


static func _mouse(b: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = b as MouseButton
	return ev


static func _primary_event(action: String) -> InputEvent:
	if _custom.has(action):
		var c: Dictionary = _custom[action]
		return _mouse(int(c.mouse)) if c.has("mouse") else _key(int(c.key))
	if MOUSE.has(action):
		return _mouse(MOUSE[action])
	if KEYS.has(action):
		return _key(KEYS[action][0])
	return InputEventAction.new()


static func apply_binds(binds: Dictionary) -> void:
	_custom = binds.duplicate(true)
	for row: Array in REBINDABLE:
		_rebuild(row[0])


static func custom_binds() -> Dictionary:
	return _custom.duplicate(true)


## Rebinds `action` to `ev`. If another action already uses that input the two
## swap, so nothing is ever left unbound. Returns the swapped action, or "".
static func rebind(action: String, ev: InputEvent) -> String:
	var b := _encode(ev)
	if b.is_empty():
		return ""
	var old := _encode(_primary_event(action))
	var swapped := ""
	for row: Array in REBINDABLE:
		var other: String = row[0]
		if other != action and _encode(_primary_event(other)) == b:
			_custom[other] = old
			_rebuild(other)
			swapped = other
			break
	_custom[action] = b
	_rebuild(action)
	return swapped


static func _encode(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return {"key": code}
	if ev is InputEventMouseButton:
		return {"mouse": (ev as InputEventMouseButton).button_index}
	return {}


## Short, layout-aware name of the action's keyboard/mouse binding, for prompts.
static func label(action: String) -> String:
	var ev := _primary_event(action)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			var b: return "Mouse %d" % b
	if ev is InputEventKey:
		var phys := (ev as InputEventKey).physical_keycode
		var mapped := DisplayServer.keyboard_get_keycode_from_physical(phys) if DisplayServer.get_name() != "headless" else phys
		return OS.get_keycode_string(mapped).to_upper()
	return "?"
