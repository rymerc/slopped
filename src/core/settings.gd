extends Node
## Player settings (autoload "Settings"). One source of truth, saved to
## user://settings.cfg, applied at boot and live as sliders move.
##   video    display mode, resolution, vsync, fps cap, render scale, MSAA,
##            shadows, glow, draw distance, plus Low/Medium/High presets
##   audio    Master > Music / Effects / Movement / Ambience / Interface buses
##   controls sensitivity, invert Y, toggle sprint, gamepad look, rebinds
##   gameplay FOV, camera shake, head bob, UI scale
## Anything that lives in a world (sun, environment, cameras, detail chunks)
## joins a group and is refreshed by apply_world().

signal changed

const PATH := "user://settings.cfg"
const VERSION := 1
const GROUP_SUN := "settings_sun"
const GROUP_ENV := "settings_env"
const BUSES := ["Music", "Effects", "Movement", "Ambience", "Interface"]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const FPS_CAPS := [0, 30, 60, 120, 144, 165, 240]
const SHADOW_SIZE := [0, 1024, 2048, 4096]
const SHADOW_DIST := [0.0, 60.0, 90.0, 130.0]
const DRAW_SCALE := [0.65, 1.0, 1.5]
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
## render_scale, msaa, shadows, glow, draw
const PRESETS := {
	"Low": [0.75, 0, 1, false, 0],
	"Medium": [1.0, 1, 2, true, 1],
	"High": [1.0, 2, 3, true, 2],
}

const DEFAULTS := {
	"video": {
		"window_mode": 0,  # 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen
		"resolution": 1,
		"vsync": 1,  # 0 off, 1 on, 2 adaptive
		"fps_cap": 0,
		"render_scale": 1.0,
		"msaa": 1,
		"shadows": 2,
		"glow": true,
		"draw": 1,
	},
	"audio": {
		"master": 0.8,
		"music": 0.55,
		"effects": 0.8,
		"movement": 0.6,
		"ambience": 0.7,
		"interface": 0.7,
		"mute_unfocused": false,
	},
	"controls": {
		"sensitivity": 1.0,
		"invert_y": false,
		"toggle_sprint": false,
		"pad_look": 1.0,
		"binds": {},
	},
	"gameplay": {
		"fov": 72.0,
		"shake": 1.0,
		"bob": 1.0,
		"ui_scale": 1.0,
	},
}

var data: Dictionary = {}
var sprint_latched := false
var _save_t := -1.0
var _unfocused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = DEFAULTS.duplicate(true)
	_make_buses()
	_load()
	InputSetup.ensure()
	InputSetup.apply_binds(data.controls.binds)
	apply_all()


func _process(delta: float) -> void:
	if _save_t > 0.0:
		_save_t -= delta
		if _save_t <= 0.0:
			save()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_unfocused = true
			_apply_audio()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_unfocused = false
			_apply_audio()
		NOTIFICATION_WM_CLOSE_REQUEST:
			if _save_t > 0.0:
				save()


# --- access --------------------------------------------------------------------

func g(section: String, key: String) -> Variant:
	return data[section][key]


## Sets a value, applies it, and saves shortly after (sliders fire many times).
func s(section: String, key: String, value: Variant) -> void:
	data[section][key] = value
	match section:
		"audio":
			_apply_audio()
		"video":
			apply_video(key)
		"gameplay":
			_apply_gameplay()
	changed.emit()
	_save_t = 0.4


func reset_section(section: String) -> void:
	data[section] = (DEFAULTS[section] as Dictionary).duplicate(true)
	if section == "controls":
		InputSetup.apply_binds({})
	apply_all()
	changed.emit()
	save()


func apply_preset(name: String) -> void:
	var p: Array = PRESETS[name]
	var v: Dictionary = data.video
	v.render_scale = p[0]
	v.msaa = p[1]
	v.shadows = p[2]
	v.glow = p[3]
	v.draw = p[4]
	apply_all()
	changed.emit()
	save()


func preset_name() -> String:
	var v: Dictionary = data.video
	for n: String in PRESETS:
		var p: Array = PRESETS[n]
		if is_equal_approx(float(v.render_scale), p[0]) and v.msaa == p[1] and v.shadows == p[2] and v.glow == p[3] and v.draw == p[4]:
			return n
	return "Custom"


func sensitivity() -> float:
	return 0.0025 * float(data.controls.sensitivity)


func draw_distance_scale() -> float:
	return DRAW_SCALE[int(data.video.draw)] if not data.is_empty() else 1.0


func shake_scale() -> float:
	return float(data.gameplay.shake)


func bob_scale() -> float:
	return float(data.gameplay.bob)


func fov() -> float:
	return float(data.gameplay.fov)


# --- applying --------------------------------------------------------------------

func apply_all() -> void:
	_apply_window()
	apply_video("")
	_apply_audio()
	_apply_gameplay()


func apply_video(key: String) -> void:
	var v: Dictionary = data.video
	if key in ["window_mode", "resolution"]:
		_apply_window()
	DisplayServer.window_set_vsync_mode([DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED,
		DisplayServer.VSYNC_ADAPTIVE][int(v.vsync)])
	Engine.max_fps = int(FPS_CAPS[int(v.fps_cap)])
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = float(v.render_scale)
	vp.msaa_3d = MSAA[int(v.msaa)]
	apply_world()


## Pushes video settings into whatever world is loaded (safe with none).
func apply_world() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var v: Dictionary = data.video
	var level := int(v.shadows)
	if level > 0:
		RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZE[level], true)
	for n: Node in tree.get_nodes_in_group(GROUP_SUN):
		var sun := n as DirectionalLight3D
		sun.shadow_enabled = level > 0
		sun.directional_shadow_max_distance = SHADOW_DIST[level]
		# fewer cascades means fewer passes over the whole town
		sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_ORTHOGONAL,
			DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][level]
	for n: Node in tree.get_nodes_in_group(GROUP_ENV):
		var env: Environment = (n as WorldEnvironment).environment
		env.glow_enabled = bool(v.glow)
	for n: Node in tree.get_nodes_in_group(Batch.GROUP_DETAIL):
		(n as GeometryInstance3D).visibility_range_end = Batch.DETAIL_END * draw_distance_scale()


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var v: Dictionary = data.video
	match int(v.window_mode):
		1:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size: Vector2i = RESOLUTIONS[int(v.resolution)]
			var screen := DisplayServer.screen_get_usable_rect()
			size = size.min(screen.size)
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func _apply_gameplay() -> void:
	get_window().content_scale_factor = float(data.gameplay.ui_scale)


func _make_buses() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	# a safety limiter: forty overlapping explosions must not hurt anyone
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, lim)


## Sliders are perceptual: 0..1 maps through a cubic curve so 50 % sounds like half.
func _apply_audio() -> void:
	var a: Dictionary = data.audio
	_set_bus("Master", float(a.master) * (0.0 if _unfocused and bool(a.mute_unfocused) else 1.0))
	for b: String in BUSES:
		_set_bus(b, float(a[b.to_lower()]))


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v * v, 0.00001)) + 6.0 if bus != "Master" else linear_to_db(maxf(v * v * v, 0.00001)) + 3.0)


# --- persistence -----------------------------------------------------------------

func save() -> void:
	_save_t = -1.0
	data.controls.binds = InputSetup.custom_binds()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for section: String in data:
		for key: String in data[section]:
			cfg.set_value(section, key, data[section][key])
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for section: String in data:
		for key: String in data[section]:
			if cfg.has_section_key(section, key):
				var val: Variant = cfg.get_value(section, key)
				if typeof(val) == typeof(data[section][key]) or (val is int and data[section][key] is float):
					data[section][key] = val
