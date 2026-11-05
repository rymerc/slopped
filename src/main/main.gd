extends Node
## Root scene: main menu + world switching. Worlds are always named "World" so
## RPC node paths (/root/Main/World/...) match on every peer.
##
## Command line (after `--`):  --host [--bots=N] [--giant[=modifier]]  |  --join=IP  |  --name=Bob
## --giant skips the lobby and starts GIANT HUNT immediately (dev shortcut);
## add --bot-giant to play as a little against a bot giant.

const SAVE_PATH := "user://profile.cfg"

var _world: Node
var _menu: Control
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _bots: SpinBox
var _status: Label
var _color: Color = Art.SWATCHES[0]
var _hat := "party"
var _body := "kid"


func _ready() -> void:
	Net.world_requested.connect(_on_world)
	Net.status.connect(func(m: String) -> void: _status.text = m)
	_load_profile()
	_build_menu()
	_handle_cmdline()


func _on_world(w: String, args: Dictionary) -> void:
	if _world:
		remove_child(_world)
		_world.queue_free()
		_world = null
	_menu.visible = w == "menu"
	if w == "menu":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	var node: WorldBase
	match w:
		"lobby":
			node = Lobby.new()
		"giant":
			node = GiantGame.new()
		_:
			push_error("Unknown world %s" % w)
			return
	node.name = "World"
	node.args = args
	_world = node
	add_child(node)


func _profile() -> Dictionary:
	Progress.ensure_loaded()
	return {"name": _name_edit.text, "color": _color, "hat": _hat, "body": _body, "level": Progress.level}


func _join() -> void:
	_save_profile()
	var err := Net.join(_ip_edit.text, _profile())
	if err != OK:
		_status.text = "Could not start client (error %d)" % err


func _handle_cmdline() -> void:
	var host := false
	for a: String in OS.get_cmdline_user_args():
		if a == "--host":
			host = true
		elif a == "--bot-giant":
			_dev_bot_giant = true
		elif a.begins_with("--giant"):
			_dev_giant = a.get_slice("=", 1) if a.contains("=") else "none"
		elif a.begins_with("--bots="):
			_bots.value = int(a.get_slice("=", 1))
		elif a.begins_with("--name="):
			_name_edit.text = a.get_slice("=", 1)
		elif a.begins_with("--join="):
			_ip_edit.text = a.get_slice("=", 1)
			_join.call_deferred()
	if host:
		_host.call_deferred()


var _dev_giant := ""
var _dev_bot_giant := false


func _host() -> void:
	_save_profile()
	var err := Net.host(_profile(), int(_bots.value))
	if err != OK:
		_status.text = "Could not host (error %d). Port %d busy?" % [err, Net.PORT]
		return
	if _dev_giant != "":
		var ids: Array = Net.players.keys()
		var giant: int = ids[-1] if _dev_bot_giant and ids.size() > 1 else 1
		ids.erase(giant)
		Net.request_world("giant", {"giant": giant, "littles": ids, "modifier": _dev_giant, "seed": randi()})


# --- persistence -----------------------------------------------------------

func _load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_color = cfg.get_value("p", "color", _color)
		_hat = cfg.get_value("p", "hat", _hat)
		_body = cfg.get_value("p", "body", _body)
		_saved_name = cfg.get_value("p", "name", "")
		_saved_ip = cfg.get_value("p", "ip", "127.0.0.1")


var _saved_name := ""
var _saved_ip := "127.0.0.1"


func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "name", _name_edit.text)
	cfg.set_value("p", "color", _color)
	cfg.set_value("p", "hat", _hat)
	cfg.set_value("p", "body", _body)
	cfg.set_value("p", "ip", _ip_edit.text)
	cfg.save(SAVE_PATH)


# --- menu UI ---------------------------------------------------------------

func _build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_menu)
	var bg := ColorRect.new()
	bg.color = Ui.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var v := Ui.vbox(14)
	p.add_child(v)

	var title := Ui.label("SLOPPED", 96, Ui.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Ui.label("a friendship-ending party game", 22, Ui.ACCENT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = 16
	_name_edit.text = _saved_name if _saved_name != "" else "Slopper%d" % (randi() % 100)
	_name_edit.add_theme_font_size_override("font_size", 24)
	v.add_child(_name_edit)

	var swatches := Ui.hbox(6)
	v.add_child(swatches)
	for c: Color in Art.SWATCHES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 40)
		b.add_theme_stylebox_override("normal", Ui.box_style(c, 8, 3))
		b.add_theme_stylebox_override("hover", Ui.box_style(c.lightened(0.2), 8, 3))
		b.add_theme_stylebox_override("pressed", Ui.box_style(c.darkened(0.2), 8, 3))
		b.pressed.connect(func() -> void: _color = c)
		swatches.add_child(b)

	var host_row := Ui.hbox()
	v.add_child(host_row)
	host_row.add_child(Ui.button("HOST", _host, Ui.ACCENT, 30))
	host_row.add_child(Ui.label("bots:", 22))
	_bots = SpinBox.new()
	_bots.min_value = 0
	_bots.max_value = 7
	_bots.value = 3
	host_row.add_child(_bots)

	var join_row := Ui.hbox()
	v.add_child(join_row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = _saved_ip
	_ip_edit.custom_minimum_size = Vector2(260, 0)
	_ip_edit.add_theme_font_size_override("font_size", 22)
	join_row.add_child(_ip_edit)
	join_row.add_child(Ui.button("JOIN", _join, Color("#3ec1ff"), 30))

	_status = Ui.label("Host with bots to play solo. Friends join your IP (port %d UDP)." % Net.PORT, 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var settings := SettingsMenu.new()
	layer.add_child(settings)
	var foot := Ui.hbox()
	v.add_child(foot)
	var sb := Ui.button("Settings", settings.open, Ui.PANEL.lightened(0.2), 20)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sb)
	var qb := Ui.button("Quit", func() -> void: get_tree().quit(), Ui.PANEL.lightened(0.2), 20)
	qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(qb)
