class_name CasinoUI
extends CenterContainer
## Modal panel for gambling machines + perk shop. Pure presentation: every
## outcome comes from the host via Casino.result.

signal closed

var casino: Casino
var _kind := ""
var _body: VBoxContainer
var _msg: Label
var _busy := false
var _anim_t := 0.0
var _anim_data: Dictionary = {}
# per-mode widgets
var _reels: Array[Label] = []
var _crash_label: Label
var _crash_running := false
var _crash_t0 := 0
var _wheel_labels: Array[Label] = []
var _ducks: Array[ColorRect] = []
var _duck_pick := 0
var _roulette_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	casino.result.connect(_on_result)


func open(kind: String) -> void:
	_kind = kind
	_busy = false
	_crash_running = false
	_anim_data = {}
	for c in get_children():
		c.queue_free()
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(620, 380)
	add_child(p)
	_body = Ui.vbox(12)
	p.add_child(_body)
	match kind:
		"slots": _build_slots()
		"crash": _build_crash()
		"wheel": _build_wheel()
		"ducks": _build_ducks()
		"roulette": _build_roulette()
		"shop": _build_shop()
	_msg = Ui.label("", 22, Ui.YELLOW)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(580, 0)
	_body.add_child(_msg)
	_body.add_child(Ui.button("Walk away (Esc)", func() -> void: closed.emit(), Ui.PANEL.lightened(0.2), 18))
	visible = true


func _title(t: String, sub: String) -> void:
	_body.add_child(Ui.label(t, 44, Ui.ACCENT))
	_body.add_child(Ui.label(sub, 18))


func _coins() -> int:
	return int(Net.profile(Net.me()).get("coins", 0))


# --- builders ----------------------------------------------------------------

func _build_slots() -> void:
	_title("SLOTS", "%dc a pull. Three 7s = jackpot. Three skulls = pain." % Casino.SLOT_COST)
	var row := Ui.hbox(16)
	_body.add_child(row)
	_reels.clear()
	for i in 3:
		var p := Ui.panel(Color("#1b1b2f"))
		p.custom_minimum_size = Vector2(170, 100)
		var l := Ui.label("7", 40, Ui.YELLOW)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		row.add_child(p)
		_reels.append(l)
	_body.add_child(Ui.button("PULL", func() -> void: _send("req_slots", []), Color("#e63946"), 30))


func _build_crash() -> void:
	_title("CRASH", "Bet, watch the number climb, cash out before it explodes. x3+ = bonus perk.")
	_crash_label = Ui.label("x1.00", 72, Color("#8ce36b"))
	_body.add_child(_crash_label)
	var row := Ui.hbox()
	_body.add_child(row)
	for bet: int in [10, 25, 50]:
		row.add_child(Ui.button("BET %d" % bet, func() -> void: _send("req_crash_start", [bet]), Color("#ff7a3d")))
	_body.add_child(Ui.button("CASH OUT", _cashout, Color("#8ce36b"), 30))


func _cashout() -> void:
	if _crash_running:
		Net.to_server(casino, "req_crash_cashout")


func _build_wheel() -> void:
	_title("LIL' WHEEL", "%dc a spin. Perks, curses, and curses for your friends." % Casino.WHEEL_COST)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	_wheel_labels.clear()
	for seg: Dictionary in Casino.WHEEL_SEGMENTS:
		var l := Ui.label(str(seg.label), 18)
		l.custom_minimum_size = Vector2(140, 44)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(l)
		_wheel_labels.append(l)
	_body.add_child(Ui.button("SPIN", func() -> void: _send("req_wheel", []), Color("#b388ff"), 30))


func _build_ducks() -> void:
	_title("DUCK RACE", "%dc. Pick a duck. Winner pays x%.1f." % [Casino.DUCK_COST, Casino.DUCK_PAYOUT])
	_ducks.clear()
	var colors := [Color("#ffd23f"), Color("#ff5fa2"), Color("#3ec1ff"), Color("#8ce36b")]
	for i in 4:
		var lane := Control.new()
		lane.custom_minimum_size = Vector2(560, 34)
		var track := ColorRect.new()
		track.color = Color(0, 0, 0, 0.3)
		track.size = Vector2(560, 34)
		lane.add_child(track)
		var duck := ColorRect.new()
		duck.color = colors[i] as Color
		duck.size = Vector2(40, 30)
		duck.position = Vector2(0, 2)
		lane.add_child(duck)
		_body.add_child(lane)
		_ducks.append(duck)
	var row := Ui.hbox()
	_body.add_child(row)
	for i in 4:
		var c: Color = colors[i]
		row.add_child(Ui.button("DUCK %d" % (i + 1), _pick_duck.bind(i), c.darkened(0.2)))


func _build_roulette() -> void:
	_title("ROULETTE", "%dc a spin. Red or black pays x2, green pays x14." % Casino.ROULETTE_COST)
	_roulette_label = Ui.label("--", 72, Ui.YELLOW)
	_roulette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_roulette_label)
	var row := Ui.hbox()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	row.add_child(Ui.button("RED", _send.bind("req_roulette", ["red"]), Color("#b5202f"), 30))
	row.add_child(Ui.button("BLACK", _send.bind("req_roulette", ["black"]), Color("#1a1a22"), 30))
	row.add_child(Ui.button("GREEN", _send.bind("req_roulette", ["green"]), Color("#0f7a4f"), 30))


func _anim_roulette() -> void:
	var col := {"red": Color("#ff5a5a"), "black": Ui.TEXT, "green": Color("#5ee08f")}
	if _anim_t < 2.0:
		_roulette_label.text = str(randi() % 37)
		_roulette_label.add_theme_color_override("font_color", col.values().pick_random())
	else:
		_roulette_label.text = str(int(_anim_data.roll))
		_roulette_label.add_theme_color_override("font_color", col[str(_anim_data.landed)])
		_finish()


func _pick_duck(i: int) -> void:
	_duck_pick = i
	_send("req_ducks", [i])


func _build_shop() -> void:
	_title("PERK SHOP", "Perks last one match and stack. %dc each." % PerkDB.SHOP_PRICE)
	var grid := GridContainer.new()
	grid.columns = 2
	_body.add_child(grid)
	for id: String in PerkDB.good_ids():
		var info := PerkDB.info(id)
		grid.add_child(Ui.button("%s - %s" % [info.name, info.desc], func() -> void: _send("req_buy", [id]), Color("#3ec1ff"), 16))
	_body.add_child(Ui.label("Curse a friend (%dc, anonymous*):" % PerkDB.CURSE_PRICE, 20, Ui.ACCENT))
	var row := HFlowContainer.new()
	_body.add_child(row)
	for pid: int in Net.players:
		if pid == Net.me():
			continue
		row.add_child(Ui.button(Net.pname(pid), func() -> void: _send("req_curse", [pid]), Color("#e63946"), 16))


# --- network ------------------------------------------------------------------

func _send(method: String, args: Array) -> void:
	if _busy:
		return
	_busy = method != "req_buy" and method != "req_curse"
	_msg.text = "..."
	Net.to_server(casino, method, args)


func _on_result(kind: String, data: Dictionary) -> void:
	if not visible:
		return
	match kind:
		"broke", "shop":
			_busy = false
			_msg.text = str(data.msg)
		"slots", "wheel", "ducks", "roulette":
			_anim_data = data
			_anim_t = 0.0
		"crash_start":
			_crash_running = true
			_crash_t0 = Time.get_ticks_msec()
			_msg.text = "Climbing... (bet %dc)" % int(data.bet)
		"crash_end":
			_crash_running = false
			_busy = false
			_crash_label.text = "x%.2f" % float(data.mult)
			_crash_label.add_theme_color_override("font_color", Color("#8ce36b") if data.won else Color("#e63946"))
			_msg.text = str(data.msg)


func _process(delta: float) -> void:
	if not visible:
		return
	if _crash_running and _crash_label:
		var t := (Time.get_ticks_msec() - _crash_t0) / 1000.0
		_crash_label.text = "x%.2f" % exp(Casino.CRASH_RATE * t)
		_crash_label.add_theme_color_override("font_color", Color("#ffd23f"))
	if _anim_data.is_empty():
		return
	_anim_t += delta
	match _kind:
		"slots": _anim_slots()
		"wheel": _anim_wheel()
		"ducks": _anim_ducks()
		"roulette": _anim_roulette()


func _finish() -> void:
	_msg.text = str(_anim_data.msg)
	_anim_data = {}
	_busy = false


func _anim_slots() -> void:
	var reels: Array = _anim_data.reels
	for i in 3:
		if _anim_t < 0.8 + i * 0.5:
			_reels[i].text = str(Casino.SLOT_SYMBOLS.pick_random())
		else:
			_reels[i].text = str(reels[i])
	if _anim_t > 2.0:
		_finish()


func _anim_wheel() -> void:
	var target := int(_anim_data.index)
	var n := _wheel_labels.size()
	# Highlight hops slow down over 3s and land on target.
	var total_hops := n * 3 + target
	var p := clampf(_anim_t / 3.0, 0.0, 1.0)
	var hop := int(floor((1.0 - pow(1.0 - p, 3.0)) * total_hops))
	for i in n:
		var on := i == hop % n
		_wheel_labels[i].add_theme_color_override("font_color", Ui.YELLOW if on else Ui.TEXT)
		_wheel_labels[i].scale = Vector2.ONE * (1.15 if on else 1.0)
	if p >= 1.0:
		_finish()


func _anim_ducks() -> void:
	var winner := int(_anim_data.winner)
	var dur := 3.5
	var p := clampf(_anim_t / dur, 0.0, 1.0)
	for i in 4:
		var speed := 1.0 if i == winner else 0.8 + 0.12 * sin(i * 7.3)
		var wobble := sin(_anim_t * (6.0 + i)) * 0.03
		_ducks[i].position.x = clampf(p * speed + wobble * (1.0 - p), 0.0, 1.0) * 520.0
	if p >= 1.0:
		_finish()
