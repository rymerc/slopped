class_name Ui
extends RefCounted
## Tiny UI kit: chunky, outlined, saturated — matches the 3D toon look.

const BG := Color("#2b1d3a")
const PANEL := Color("#3d2a55")
const ACCENT := Color("#ff5fa2")
const YELLOW := Color("#ffd23f")
const TEXT := Color("#fff6e8")


static func box_style(color: Color, radius := 14, border := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = Art.INK
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 4)
	return s


static func label(text: String, size := 22, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Art.INK)
	l.add_theme_constant_override("outline_size", maxi(3, size / 7))
	return l


static func button(text: String, cb: Callable, color := ACCENT, size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_outline_color", Art.INK)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_stylebox_override("normal", box_style(color, 12, 3))
	b.add_theme_stylebox_override("hover", box_style(color.lightened(0.15), 12, 3))
	b.add_theme_stylebox_override("pressed", box_style(color.darkened(0.2), 12, 3))
	b.add_theme_stylebox_override("disabled", box_style(color.darkened(0.5), 12, 3))
	var focus := StyleBoxFlat.new()  # visible focus ring: gamepads and Tab navigate these
	focus.draw_center = false
	focus.set_corner_radius_all(14)
	focus.set_border_width_all(3)
	focus.border_color = YELLOW
	focus.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", focus)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func panel(color := PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(color, 18, 5))
	return p


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(320, 22)
	b.add_theme_stylebox_override("background", box_style(Color(0, 0, 0, 0.5), 8, 3))
	var fill := box_style(color, 8, 0)
	fill.shadow_size = 0
	b.add_theme_stylebox_override("fill", fill)
	return b


## Anchors a control to the full rect / a preset.
static func anchor(c: Control, preset: Control.LayoutPreset, margin := 0) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
