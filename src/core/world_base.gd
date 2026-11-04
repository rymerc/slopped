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
var props: PropSystem
var water_y := -1000.0
var allow_shove := false  # LMB shoves when not holding anything
var _shove_cd: Dictionary = {}
var _xp_label: Label
var _xp_bar: ProgressBar
var _xp_cb: Callable

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
	props = PropSystem.new()
	props.name = "Props"
	props.game = self
	add_child(props)
	build_world()
	Net.players_changed.connect(_reconcile)
	Net.announced.connect(toast)
	_reconcile()
	world_started()
	set_mouse_captured(true)
	Progress.ensure_loaded()
	_xp_cb = _on_xp
	Progress.listeners.append(_xp_cb)
	_refresh_xp()


func _exit_tree() -> void:
	Progress.listeners.erase(_xp_cb)


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


## Where a fallen (water / pit / void) avatar comes back. Owner-side.
func respawn_for(av: Avatar) -> Vector3:
	return av._spawn


## Owner-side: an avatar just fell off the world. Host credits whoever
## knocked them off in the last few seconds.
func on_avatar_fell(av: Avatar) -> void:
	Net.to_server(self, "req_fell", [av.pid])


@rpc("any_peer", "reliable")
func req_fell(pid: int) -> void:
	if not multiplayer.is_server():
		return
	if Net.sender() != pid and not (Net.sender() == 1 and Net.is_bot(pid)):
		return
	var h: Dictionary = props.last_hit.get(pid, {})
	props.last_hit.erase(pid)
	if h.is_empty() or Time.get_ticks_msec() - int(h.t) > 5000 or int(h.by) == pid or int(h.by) == 0:
		return
	var by := int(h.by)
	Net.announce("%s YEETED %s into oblivion" % [Net.pname(by), Net.pname(pid)])
	Net.award(by, 0, "", "yeet")


@rpc("any_peer", "reliable")
func req_shove(dir: Vector3) -> void:
	if not multiplayer.is_server() or not allow_shove:
		return
	do_shove(Net.sender(), dir)


func do_shove(pid: int, dir: Vector3) -> void:
	var av: Avatar = avatars.get(pid)
	var now := Time.get_ticks_msec()
	if av == null or av.dead or av.ragdolled() or now - int(_shove_cd.get(pid, 0)) < 600:
		return
	_shove_cd[pid] = now
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else av.forward()
	var spd := Vector2(av.net_velocity.x, av.net_velocity.z).length()
	var power := (9.0 + clampf(spd - 5.0, 0.0, 6.0) * 0.9) * sqrt(av.size)
	_ev_shove.rpc(pid)
	for o: Avatar in avatars.values():
		if o == av or o.dead:
			continue
		var d := o.global_position - av.global_position
		if d.length() < 1.4 * av.size + 0.6 and Vector3(d.x, 0, d.z).normalized().dot(dir) > 0.3:
			o.push.rpc(dir * power + Vector3.UP * 3.5)
			props.last_hit[o.pid] = {"by": pid, "t": now}
	for p: Prop in props.list:
		var d := p.global_position - av.global_position
		if p.holder == 0 and d.length() < 1.4 * av.size + p.radius + 0.4 and Vector3(d.x, 0, d.z).normalized().dot(dir) > 0.2:
			props.bump(p, (dir * power + Vector3.UP * 3.0) * minf(p.mass, 4.0) * 0.6, p.global_position)


@rpc("authority", "call_local", "reliable")
func _ev_shove(pid: int) -> void:
	var av: Avatar = avatars.get(pid)
	if av:
		av.play_shove()


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
	if me and me.holding and can_act():
		_prompt.text = "[LMB] throw   [E] drop"
		_prompt.visible = true
		if Input.is_action_just_pressed("interact"):
			props.release(false, Vector3.ZERO)
		return
	var grab: Prop = props.nearest_grabbable(me) if me and not me.dead and not me.ragdolled() and can_act() else null
	if me and not me.dead and can_act():
		for it: Dictionary in _interacts:
			var p: Vector3 = (it.pos as Callable).call() if it.pos is Callable else it.pos
			var d := me.global_position.distance_to(p)
			var cond: Callable = it.cond
			if d < float(it.r) and d < best_d and (not cond.is_valid() or cond.call()):
				best = it
				best_d = d
	if grab and (best.is_empty() or me.global_position.distance_to(grab.global_position) < best_d):
		_prompt.text = "[E] grab %s" % grab.kind.replace("_s", "").replace("_", " ")
		_prompt.visible = true
		if Input.is_action_just_pressed("interact"):
			props.grab(grab)
		return
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
		var me := local_avatar()
		if me and event.is_action_pressed("primary"):
			if me.holding:
				props.release(true, cam.aim_dir())
				return
			if allow_shove and not me.dead:
				Net.to_server(self, "req_shove", [cam.aim_dir()])
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
	var xp_box := Ui.hbox(8)
	_xp_label = Ui.label("LV 1", 22, Ui.YELLOW)
	xp_box.add_child(_xp_label)
	_xp_bar = Ui.bar(Ui.YELLOW)
	_xp_bar.custom_minimum_size = Vector2(220, 18)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_box.add_child(_xp_bar)
	Ui.anchor(xp_box, Control.PRESET_BOTTOM_RIGHT, 14)
	xp_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	xp_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	xp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(xp_box)


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


## Clean cartoon look: saturated gradient sky, no filmic tonemap / bloom haze,
## hemispheric ambient via shader globals, and only *distant* depth fog in the
## horizon colour (atmospheric perspective for landmarks; nearby stays crisp).
func make_environment(sky_top: Color, horizon: Color, ambient := 0.55, sun_energy := 1.3,
		fog_from := 90.0, fog_to := 320.0) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = Art.SKY
	sm.set_shader_parameter("top_color", sky_top)
	sm.set_shader_parameter("horizon_color", horizon)
	sm.set_shader_parameter("bottom_color", horizon.darkened(0.15))
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = horizon
	env.fog_density = 1.0
	env.fog_depth_begin = fog_from
	env.fog_depth_end = fog_to
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# hemispheric ambient: sky tint from above, warm bounce from below
	RenderingServer.global_shader_parameter_set("sky_ambient", sky_top.lerp(Color.WHITE, 0.55) * ambient)
	RenderingServer.global_shader_parameter_set("ground_ambient", Color("#c9a27a") * ambient * 0.7)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 38, 0)
	sun.light_color = Color("#fff4dc")
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.75
	sun.shadow_blur = 0.6
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


# --- progression HUD ---------------------------------------------------------

func _on_xp(amount: int, reason: String, leveled: bool, unlocked: Array[String]) -> void:
	_refresh_xp()
	if reason != "":
		toast("+%d XP  %s" % [amount, reason])
	Sfx.ui(self, "coin", -6.0)
	if leveled:
		banner("LEVEL UP!  LV %d" % Progress.level, 3.0)
		Sfx.ui(self, "ding", -2.0)
		var me := local_avatar()
		if me:
			Fx.confetti(self, me.global_position + Vector3.UP * 2.0, 40)
		for u: String in unlocked:
			toast("UNLOCKED: %s (wardrobe)" % u)
		Net.to_server(Net, "request_look", [{"level": Progress.level}])


func _refresh_xp() -> void:
	if _xp_label == null:
		return
	_xp_label.text = "LV %d" % Progress.level
	_xp_bar.max_value = Progress.need(Progress.level)
	_xp_bar.value = Progress.xp
