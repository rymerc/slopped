class_name ResultsPanel
extends CenterContainer
## End-of-match table, and the session standings (hold the scoreboard key).

var _box: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _fill(title: String, sub: String, rows: Array) -> void:
	if _box:
		_box.queue_free()
	_box = Ui.panel()
	_box.custom_minimum_size = Vector2(640, 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var v := Ui.vbox(8)
	_box.add_child(v)
	v.add_child(Ui.label(title, 34, Ui.YELLOW))
	if sub != "":
		v.add_child(Ui.label(sub, 18))
	for r: Dictionary in rows:
		var h := Ui.hbox(14)
		var n := Ui.label(str(r.name), 22, Ui.YELLOW if r.get("win", false) else Ui.TEXT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(Ui.label(str(r.a), 22, Ui.ACCENT))
		var b := Ui.label(str(r.b), 22)
		b.custom_minimum_size = Vector2(120, 0)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(b)
		v.add_child(h)


func show_match(title: String, rows: Array) -> void:
	_fill(title, "this match", rows)
	visible = true
	get_tree().create_timer(6.6).timeout.connect(hide)


func show_standings() -> void:
	var ids: Array = Net.players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(Net.players[a].score) > int(Net.players[b].score))
	var rows: Array = []
	for id: int in ids:
		rows.append({"name": Net.pname(id), "a": "%d pts" % int(Net.players[id].score), "b": "%dc" % int(Net.players[id].coins)})
	var last: String = "; ".join(PackedStringArray(Net.history.slice(-3)))
	_fill("STANDINGS", last, rows)
	visible = true
