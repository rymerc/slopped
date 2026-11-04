class_name WorldBase
extends Node3D
## Shared plumbing for every world (lobby, minigames): avatar spawning from the
## Net player list, camera, HUD basics (prompt, toasts, banner, pause menu),
## proximity interactables and mouse capture.
## Subclasses override the build_world / configure_avatar / world_* hooks.

var args: Dictionary = {}
var avatars: Dictionary = {}  # peer id -> Avatar
var avatar_root: Node3D
var cam: CamRig
var hud: CanvasLayer
var ui_open := false

var _interacts: Array[Dictionary] = []
var _prompt: Label
var _toasts: VBoxContainer
var _banner: Label
var _banner_t := 0.0
var _pause: Control


func _ready() -> void:
	avatar_root = Node3D.new()
	avatar_root.name = "Avatars"
	add_child(avatar_root)
	cam = CamRig.new()
	cam.name = "Cam"
	add_child(cam)
	hud = CanvasLayer.new()
	hud.name = "Hud"
	add_child(hud)
	_build_hud_base()
	build_world()
	Net.players_changed.connect(_reconcile)
	Net.announced.connect(toast)
	_reconcile()
	world_started()
	set_mouse_captured(true)


# --- hooks -----------------------------------------------------------------

func build_world() -> void:
	pass


func world_started() -> void:
	pass


func configure_avatar(_av: Avatar) -> void:
	pass


func spawn_for(_av: Avatar, index: int) -> Vector3:
	var a := index * 2.4
	return Vector3(cos(a) * 3.0, 0.5, sin(a) * 3.0)


func on_avatar_added(_av: Avatar) -> void:
	pass


func world_process(_delta: float) -> void:
	pass


func world_physics(_delta: float) -> void:
	pass


func world_input(_event: InputEvent) -> void:
	pass


# --- avatars ---------------------------------------------------------------

func local_avatar() -> Avatar:
	return avatars.get(multiplayer.get_unique_id())


func _reconcile() -> void:
	for id: int in Net.players:
		var data: Dictionary = Net.players[id]
		var av: Avatar = avatars.get(id)
		if av == null:
			av = Avatar.new()
			av.setup(id, data)
			avatar_root.add_child(av)
			avatars[id] = av
			configure_avatar(av)
			av.place(spawn_for(av, avatars.size() - 1))
			if av.is_local():
				av.cam = cam
				cam.set_target(av)
			on_avatar_added(av)
		else:
			av.apply_look(data)
			configure_avatar(av)
	for id: int in avatars.keys():
		if not Net.players.has(id):
			(avatars[id] as Avatar).queue_free()
			avatars.erase(id)


# --- interactables ---------------------------------------------------------

## pos / text may be Callables for moving targets or dynamic labels.
func add_interact(pos: Variant, radius: float, text: Variant, action: Callable,
		cond: Callable = Callable()) -> void:
	_interacts.append({"pos": pos, "r": radius, "text": text, "action": action, "cond": cond})


func can_act() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not ui_open


func _process(delta: float) -> void:
	var me := local_avatar()
	if me:
		me.input_locked = not can_act()
	_update_prompt(me)
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t * 2.0, 0.0, 1.0)
	world_process(delta)


func _physics_process(delta: float) -> void:
	world_physics(delta)


func _update_prompt(me: Avatar) -> void:
	var best: Dictionary = {}
	var best_d := INF
	if me and not me.dead and can_act():
		for it: Dictionary in _interacts:
			var p: Vector3 = (it.pos as Callable).call() if it.pos is Callable else it.pos
			var d := me.global_position.distance_to(p)
			var cond: Callable = it.cond
			if d < float(it.r) and d < best_d and (not cond.is_valid() or cond.call()):
				best = it
				best_d = d
	if best.is_empty():
		_prompt.visible = false
		return
	var t: Variant = best.text
	if t is Callable:
		t = (t as Callable).call()
	_prompt.text = "[E] %s" % t
	_prompt.visible = true
	if Input.is_action_just_pressed("interact"):
		(best.action as Callable).call()


# --- input / mouse ---------------------------------------------------------

func set_mouse_captured(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
	if _pause:
		_pause.visible = not on and not ui_open


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if ui_open:
			close_ui()
		else:
			set_mouse_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and not ui_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		set_mouse_captured(true)
		get_viewport().set_input_as_handled()
		return
	if can_act():
		world_input(event)


## Subclasses with modal UIs override this and call super.
func close_ui() -> void:
	ui_open = false
	set_mouse_captured(true)


func open_ui() -> void:
	ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _pause:
		_pause.visible = false


# --- HUD -------------------------------------------------------------------

func _build_hud_base() -> void:
	_prompt = Ui.label("", 28, Ui.YELLOW)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.anchor(_prompt, Control.PRESET_CENTER_BOTTOM, 150)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_prompt)
	_toasts = Ui.vbox(4)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	Ui.anchor(_toasts, Control.PRESET_TOP_RIGHT, 16)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_toasts)
	_banner = Ui.label("", 56, Ui.YELLOW)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 150
	_banner.offset_bottom = 400
	_banner.modulate.a = 0.0
	hud.add_child(_banner)
	_build_pause()


func _build_pause() -> void:
	_pause = Ui.panel()
	var v := Ui.vbox(12)
	_pause.add_child(v)
	v.add_child(Ui.label("Paused-ish (game keeps running)", 26))
	v.add_child(Ui.button("Resume", func() -> void: set_mouse_captured(true)))
	v.add_child(Ui.button("Leave to Menu", func() -> void: Net.leave(), Ui.PANEL.lightened(0.2)))
	v.add_child(Ui.button("Quit Game", func() -> void: get_tree().quit(), Color("#e63946")))
	Ui.anchor(_pause, Control.PRESET_CENTER)
	_pause.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.visible = false
	hud.add_child(_pause)


func toast(msg: String) -> void:
	var l := Ui.label(msg, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toasts.add_child(l)
	if _toasts.get_child_count() > 7:
		_toasts.get_child(0).queue_free()
	get_tree().create_timer(5.0).timeout.connect(_expire.bind(l))


func _expire(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()


func banner(msg: String, secs := 3.0) -> void:
	_banner.text = msg
	_banner_t = secs
	_banner.modulate.a = 1.0


func make_environment(sky_top: Color, horizon: Color, ambient := 0.55, sun_energy := 1.3) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = sky_top
	sm.sky_horizon_color = horizon
	sm.ground_horizon_color = horizon
	sm.ground_bottom_color = horizon.darkened(0.4)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.92)
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
