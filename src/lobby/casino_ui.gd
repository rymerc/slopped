class_name CasinoUI
extends CenterContainer
## Counter menus only: the General Store perk shop and Dirty Deeds Dept. Games are
## played on the machines themselves (CasinoTables). Every purchase is decided by
## the host via Casino.result.

signal closed

var casino: Casino
var _body: VBoxContainer
var _msg: Label
var _deed_tier := 0
var _deed_list: VBoxContainer
var _deed_info: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	casino.result.connect(_on_result)


func open(kind: String) -> void:
	for c in get_children():
		c.queue_free()
	_deed_info = null
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(820 if kind == "deeds" else 620, 380)
	add_child(p)
	_body = Ui.vbox(12)
	p.add_child(_body)
	if kind == "deeds":
		_build_deeds()
	else:
		_build_shop()
	_msg = Ui.label("", 22, Ui.YELLOW)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(580, 0)
	_body.add_child(_msg)
	_body.add_child(Ui.button("Walk away (Esc)", func() -> void: closed.emit(), Ui.PANEL.lightened(0.2), 18))
	visible = true


func _title(t: String, sub: String) -> void:
	_body.add_child(Ui.label(t, 44, Ui.ACCENT))
	_body.add_child(Ui.label(sub, 18))


func _build_shop() -> void:
	_title("PERK SHOP", "Perks last one match and stack. %dc each." % PerkDB.SHOP_PRICE)
	var grid := GridContainer.new()
	grid.columns = 2
	_body.add_child(grid)
	for id: String in PerkDB.good_ids():
		var info := PerkDB.info(id)
		grid.add_child(Ui.button("%s - %s" % [info.name, info.desc], _send.bind("req_buy", [id]), Color("#3ec1ff"), 16))
	_body.add_child(Ui.label("Curse a friend (%dc, anonymous*):" % PerkDB.CURSE_PRICE, 20, Ui.ACCENT))
	var row := HFlowContainer.new()
	_body.add_child(row)
	for pid: int in Net.players:
		if pid != Net.me():
			row.add_child(Ui.button(Net.pname(pid), _send.bind("req_curse", [pid]), Color("#e63946"), 16))


func _build_deeds() -> void:
	_title("DIRTY DEEDS DEPT.", "All sales final. We never met.")
	_deed_info = Ui.label("", 20, Ui.YELLOW)
	_body.add_child(_deed_info)
	var tabs := Ui.hbox(6)
	_body.add_child(tabs)
	for i in Tricks.TIERS.size():
		tabs.add_child(Ui.button(str(Tricks.TIERS[i]), _show_tier.bind(i), (Tricks.TIER_COLORS[i] as Color).darkened(0.35), 16))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	_deed_list = Ui.vbox(6)
	_deed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_deed_list)
	_show_tier(_deed_tier)


func _show_tier(t: int) -> void:
	_deed_tier = t
	for c: Node in _deed_list.get_children():
		_deed_list.remove_child(c)
		c.queue_free()
	var col: Color = Tricks.TIER_COLORS[t]
	for id: String in Tricks.tier_items(t):
		var it: Dictionary = Tricks.ITEMS[id]
		var row := Ui.hbox(10)
		var b := Ui.button("%dc" % int(it.price), _send.bind("req_deed", [id]), col.darkened(0.3), 20)
		b.custom_minimum_size = Vector2(90, 0)
		row.add_child(b)
		var txt := Ui.label("%s: %s" % [it.name, it.desc], 18)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		_deed_list.add_child(row)
	_refresh_deeds()


func _refresh_deeds() -> void:
	if _deed_info == null or not is_instance_valid(_deed_info):
		return
	var p := Net.profile(Net.me())
	_deed_info.text = "coins: %d    bag: %d    lawyers: %d    uno: %d" % [int(p.get("coins", 0)),
		(p.get("bag", []) as Array).size(), int(p.get("ward", 0)), int(p.get("mirror", 0))]


func _send(method: String, args: Array) -> void:
	_msg.text = "..."
	Net.to_server(casino, method, args)


func _on_result(kind: String, data: Dictionary) -> void:
	if visible and (kind == "broke" or kind == "shop"):
		_msg.text = str(data.msg)
		_refresh_deeds.call_deferred()
