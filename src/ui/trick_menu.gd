class_name TrickMenu
extends CenterContainer
## In-game "use a trick" panel: pick something from your bag, then a victim. The
## world keeps running while it's open, so opening it mid-fight is a real risk.

var tricks: TrickSystem
var _body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open() -> void:
	visible = true
	_show_items()


func _panel(title: String) -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(620, 0)
	add_child(p)
	_body = Ui.vbox(10)
	p.add_child(_body)
	_body.add_child(Ui.label(title, 38, Ui.ACCENT))


func _show_items() -> void:
	_panel("DIRTY BAG")
	var bag: Array = Net.profile(Net.me()).get("bag", [])
	if bag.is_empty():
		_body.add_child(Ui.label("Empty. Visit Dirty Deeds Dept. in the casino.", 22))
	var seen := {}
	for id: String in bag:
		seen[id] = int(seen.get(id, 0)) + 1
	var first: Button = null
	for id: String in seen:
		var it: Dictionary = Tricks.ITEMS[id]
		var c: Color = Tricks.TIER_COLORS[int(it.tier)]
		var b := Ui.button("%s x%d - %s" % [it.name, seen[id], it.desc], _pick.bind(id), c.darkened(0.45), 18)
		_body.add_child(b)
		if first == null:
			first = b
	_body.add_child(Ui.button("Never mind", func() -> void: tricks.game.close_ui(), Ui.PANEL.lightened(0.2), 18))
	if first:
		first.grab_focus()


func _pick(id: String) -> void:
	if not Tricks.needs_target(id):
		_fire(id, 0)
		return
	_panel(str(Tricks.ITEMS[id].name).to_upper())
	_body.add_child(Ui.label("Pick a victim", 22))
	var ids: Array = Net.players.keys().filter(func(k: int) -> bool: return k != Net.me())
	var me: Avatar = tricks.game.local_avatar()
	if me:  # nearest first: the person you're mad at is usually right there
		ids.sort_custom(func(a: int, b: int) -> bool:
			return _dist(me, a) < _dist(me, b))
	for pid: int in ids:
		_body.add_child(Ui.button(Net.pname(pid), _fire.bind(id, pid), Color("#e63946"), 22))
	_body.add_child(Ui.button("Back", _show_items, Ui.PANEL.lightened(0.2), 18))


func _dist(me: Avatar, id: int) -> float:
	var o: Avatar = tricks.game.avatars.get(id)
	return me.global_position.distance_to(o.global_position) if o else INF


func _fire(id: String, target: int) -> void:
	Net.to_server(tricks, "req_use", [id, target])
	tricks.game.close_ui()
