class_name SettingsMenu
extends Control
## Video / Audio / Controls / Gameplay screen, opened from the main and pause
## menus. Changes apply live and save automatically; only display-mode changes
## need confirming (a bad mode can leave you with no picture, so they auto-revert).

signal closed

const TABS := ["Video", "Audio", "Controls", "Gameplay"]
const REVERT_SECS := 10.0

var _tab := 0
var _tab_buttons: Array[Button] = []
var _body: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _listening := ""
var _listen_btn: Button
var _confirm: PanelContainer
var _confirm_label: Label
var _confirm_t := 0.0
var _revert: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.04, 0.1, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(900, 700)
	center.add_child(p)
	var v := Ui.vbox(12)
	p.add_child(v)
	v.add_child(Ui.label("SETTINGS", 44, Ui.YELLOW))
	var tabs := Ui.hbox(8)
	v.add_child(tabs)
	for i in TABS.size():
		var b := Ui.button(TABS[i], _show_tab.bind(i), Ui.PANEL.lightened(0.2), 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tab_buttons.append(b)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_body = Ui.vbox(8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_status = Ui.label("", 18, Ui.YELLOW)
	v.add_child(_status)
	var foot := Ui.hbox(8)
	v.add_child(foot)
	foot.add_child(Ui.button("Reset this tab", _reset_tab, Ui.PANEL.lightened(0.2), 22))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	foot.add_child(Ui.button("Done", close, Ui.ACCENT, 26))
	_build_confirm()
	visible = false


func open() -> void:
	visible = true
	_show_tab(_tab)
	_tab_buttons[_tab].grab_focus()


func close() -> void:
	if _confirm.visible:
		_finish_confirm(false)
	_cancel_listen()
	Settings.save()
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if _confirm == null or not _confirm.visible:
		return
	_confirm_t -= delta
	_confirm_label.text = "Keep these display settings?\nReverting in %d s" % ceili(_confirm_t)
	if _confirm_t <= 0.0:
		_finish_confirm(false)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening != "":
		_capture(event)
		return
	if event.is_action_pressed("menu"):
		accept_event()
		close()


func _capture(event: InputEvent) -> void:
	var usable := (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if not usable:
		return
	accept_event()
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_cancel_listen()
		return
	var action := _listening
	var swapped := InputSetup.rebind(action, event)
	_listening = ""
	Settings.save()
	_show_tab(_tab)
	_status.text = "Swapped with %s." % _action_name(swapped) if swapped != "" else ""


func _cancel_listen() -> void:
	_listening = ""
	if _listen_btn and is_instance_valid(_listen_btn):
		_show_tab(_tab)


func _action_name(action: String) -> String:
	for row: Array in InputSetup.REBINDABLE:
		if row[0] == action:
			return row[1]
	return action


func _show_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		var c := Ui.ACCENT if k == i else Ui.PANEL.lightened(0.2)
		_tab_buttons[k].add_theme_stylebox_override("normal", Ui.box_style(c, 12, 3))
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_status.text = ""
	match TABS[i]:
		"Video":
			_video()
		"Audio":
			_audio()
		"Controls":
			_controls()
		"Gameplay":
			_gameplay()


func _reset_tab() -> void:
	Settings.reset_section(TABS[_tab].to_lower())
	_show_tab(_tab)
	_status.text = "%s reset to defaults." % TABS[_tab]


# --- tabs ----------------------------------------------------------------------

func _video() -> void:
	var names: Array = (Settings.PRESETS as Dictionary).keys()
	var cur: String = Settings.preset_name()
	var items: Array = names.duplicate()
	if cur == "Custom":
		items.append("Custom")
	_options("Quality preset", items, items.find(cur), func(idx: int) -> void:
		if str(items[idx]) != "Custom":
			Settings.apply_preset(str(items[idx]))
			_show_tab(_tab))
	_heading("Display")
	_options("Display mode", ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"],
		int(Settings.g("video", "window_mode")), _display.bind("window_mode"))
	var res: Array = []
	for r: Vector2i in Settings.RESOLUTIONS:
		res.append("%d x %d" % [r.x, r.y])
	var opt := _options("Window size", res, int(Settings.g("video", "resolution")), _display.bind("resolution"))
	opt.disabled = int(Settings.g("video", "window_mode")) != 0
	_options("VSync", ["Off", "On", "Adaptive"], int(Settings.g("video", "vsync")), _setter("video", "vsync"))
	var caps: Array = []
	for f: int in Settings.FPS_CAPS:
		caps.append("Unlimited" if f == 0 else str(f))
	_options("Frame rate limit", caps, int(Settings.g("video", "fps_cap")), _setter("video", "fps_cap"))
	_heading("Graphics")
	_slider("Render scale", "video", "render_scale", 0.5, 1.0, 0.05, "%d %%", 100.0)
	_options("Anti-aliasing", ["Off", "MSAA 2x", "MSAA 4x"], int(Settings.g("video", "msaa")), _setter("video", "msaa"))
	_options("Shadows", ["Off", "Low", "Medium", "High"], int(Settings.g("video", "shadows")), _setter("video", "shadows"))
	_toggle("Glow (neon bloom)", "video", "glow")
	_options("Scenery draw distance", ["Near", "Medium", "Far"], int(Settings.g("video", "draw")), _setter("video", "draw"))


func _audio() -> void:
	_slider("Master", "audio", "master", 0.0, 1.0, 0.01, "%d %%", 100.0)
	_slider("Music", "audio", "music", 0.0, 1.0, 0.01, "%d %%", 100.0)
	_slider("Effects (hits, explosions, casino)", "audio", "effects", 0.0, 1.0, 0.01, "%d %%", 100.0, "boom")
	_slider("Movement (steps, jumps, sliding)", "audio", "movement", 0.0, 1.0, 0.01, "%d %%", 100.0, "step")
	_slider("Ambience (surf, wind, town)", "audio", "ambience", 0.0, 1.0, 0.01, "%d %%", 100.0)
	_slider("Interface", "audio", "interface", 0.0, 1.0, 0.01, "%d %%", 100.0, "coin")
	_toggle("Mute when the game is in the background", "audio", "mute_unfocused")


func _controls() -> void:
	_heading("Look")
	_slider("Mouse sensitivity", "controls", "sensitivity", 0.1, 3.0, 0.05, "%.2f x")
	_slider("Gamepad look speed", "controls", "pad_look", 0.3, 2.5, 0.05, "%.2f x")
	_toggle("Invert vertical look", "controls", "invert_y")
	_heading("Movement")
	_toggle("Toggle sprint (tap instead of hold)", "controls", "toggle_sprint")
	_heading("Key bindings (click one, then press a key or mouse button)")
	for row: Array in InputSetup.REBINDABLE:
		var r := _row(str(row[1]))
		var b := Ui.button(InputSetup.label(row[0]), Callable(), Ui.PANEL.lightened(0.2), 20)
		b.custom_minimum_size = Vector2(180, 0)
		b.pressed.connect(func() -> void:
			if _listening != "":
				return
			_listening = str(row[0])
			_listen_btn = b
			b.text = "press a key...")
		r.add_child(b)


func _gameplay() -> void:
	_slider("Field of view", "gameplay", "fov", 60.0, 100.0, 1.0, "%d")
	_slider("Camera shake", "gameplay", "shake", 0.0, 1.0, 0.05, "%d %%", 100.0)
	_slider("Head bob", "gameplay", "bob", 0.0, 1.0, 0.05, "%d %%", 100.0)
	_slider("Interface size", "gameplay", "ui_scale", 0.8, 1.4, 0.05, "%d %%", 100.0)


# --- display-mode confirmation ------------------------------------------------

func _display(idx: int, key: String) -> void:
	var was: Dictionary = (Settings.data.video as Dictionary).duplicate()
	if int(was[key]) == idx:
		return
	if not _confirm.visible:
		_revert = {"window_mode": was.window_mode, "resolution": was.resolution}
	Settings.s("video", key, idx)
	_confirm_t = REVERT_SECS
	_confirm.visible = true


func _finish_confirm(keep: bool) -> void:
	_confirm.visible = false
	if not keep:
		for k: String in _revert:
			Settings.data.video[k] = _revert[k]
		Settings.apply_video("window_mode")
	Settings.save()
	if visible:
		_show_tab(_tab)


func _build_confirm() -> void:
	_confirm = Ui.panel(Ui.BG)
	var v := Ui.vbox(14)
	_confirm.add_child(v)
	_confirm_label = Ui.label("", 28)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_confirm_label)
	var h := Ui.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(Ui.button("Keep", _finish_confirm.bind(true), Ui.ACCENT, 26))
	h.add_child(Ui.button("Revert", _finish_confirm.bind(false), Ui.PANEL.lightened(0.2), 26))
	Ui.anchor(_confirm, Control.PRESET_CENTER)
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm.visible = false
	add_child(_confirm)


# --- rows ------------------------------------------------------------------------

func _setter(section: String, key: String) -> Callable:
	return func(v: Variant) -> void:
		Settings.s(section, key, v)
		_status.text = ""
		if section == "video":
			_refresh_preset_row()


## Live control changes can make the preset read Custom; the row is cheap to redo.
func _refresh_preset_row() -> void:
	if TABS[_tab] != "Video" or _body.get_child_count() == 0:
		return
	var opt := (_body.get_child(0) as HBoxContainer).get_child(-1) as OptionButton
	var cur: String = Settings.preset_name()
	for i in opt.item_count:
		if opt.get_item_text(i) == cur:
			opt.select(i)
			return
	opt.add_item("Custom")
	opt.select(opt.item_count - 1)


func _heading(text: String) -> void:
	var l := Ui.label(text, 22, Ui.YELLOW)
	_body.add_child(l)


func _row(text: String) -> HBoxContainer:
	var h := Ui.hbox(12)
	var l := Ui.label(text, 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	_body.add_child(h)
	return h


func _options(text: String, items: Array, selected: int, cb: Callable) -> OptionButton:
	var r := _row(text)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(300, 38)
	o.add_theme_font_size_override("font_size", 20)
	for it: Variant in items:
		o.add_item(str(it))
	o.select(clampi(selected, 0, items.size() - 1))
	o.item_selected.connect(cb)
	r.add_child(o)
	return o


func _toggle(text: String, section: String, key: String) -> void:
	var r := _row(text)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.g(section, key))
	c.toggled.connect(_setter(section, key))
	r.add_child(c)


func _slider(text: String, section: String, key: String, lo: float, hi: float, step: float,
		fmt: String, display_scale := 1.0, preview := "") -> void:
	var r := _row(text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.g(section, key))
	s.custom_minimum_size = Vector2(240, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Ui.label("", 20, Ui.YELLOW)
	val.custom_minimum_size = Vector2(90, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var show_value := func(x: float) -> void:
		val.text = fmt % (int(round(x * display_scale)) if fmt.contains("%d") else x)
	show_value.call(s.value)
	s.value_changed.connect(func(x: float) -> void:
		show_value.call(x)
		Settings.s(section, key, x)
		if section == "video":
			_refresh_preset_row())
	if preview != "":
		s.drag_ended.connect(func(_c: bool) -> void:
			if is_inside_tree():
				var p := AudioStreamPlayer.new()
				p.stream = Sfx.stream(preview)
				p.bus = Sfx.bus_for(preview)
				add_child(p)
				p.finished.connect(p.queue_free)
				p.play())
	r.add_child(s)
	r.add_child(val)
