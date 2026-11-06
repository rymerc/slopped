class_name CasinoFloorFx
extends Node
## Draws casino games on the physical machines, on every peer: reels stop on the
## real result, wheels land on the real segment, the crash screen climbs, cards hit
## the felt. Shared by the lobby casino and Cursed Casino Night. refs is what
## LobbyBuilder.casino_floor() returns.

const SYMBOL_FACE := {"CHERRY": 0, "BELL": 1, "LEMON": 3, "7": 4, "SKULL": 7}
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var refs: Dictionary = {}
var _slots: Dictionary = {}  # machine -> {t, stop: [face...]}
var _wheel_tw: Tween
var _roul_v := 0.0
var _duck_t := 0.0
var _duck_win := 0
var _crash_t0 := -1
var _felt: Dictionary = {}  # key -> {node, down}: everything on the blackjack table
var bj_view: Dictionary = {}
var _deal_from := Vector3.ZERO
var _roul_slot: Dictionary = {}
var _roul_t: Dictionary = {}
var _chart: Node3D
var _chart_t := 0.0


func spinning_slots() -> bool:
	return not _slots.is_empty()


func _label(kind: String, seat: int) -> Label3D:
	return ((refs.seats[kind] as Array)[seat] as Dictionary).label


func fx(kind: String, seat: int, d: Dictionary) -> void:
	var host: Node = get_parent()
	match kind:
		"slots":
			var slots: Array = refs.get("slots", [])
			var m := clampi(seat, 0, slots.size() - 1)
			var faces: Array = (d.reels as Array).map(func(s: String) -> int: return int(SYMBOL_FACE[s]))
			_slots[m] = {"t": 2.0, "stop": faces, "text": "  ".join(PackedStringArray(d.reels))}
			_label("slots", m).text = "..."
			Sfx.at(host, "click", LobbyBuilder.SLOTS[m], 0.0, 0.1, 0.7)
		"wheel":
			var rw := refs.get("prize_wheel") as Node3D
			var seg := TAU / Casino.WHEEL_SEGMENTS.size()
			var target := (int(d.index) + 0.5) * seg + TAU * 5.0
			rw.rotation.z = fmod(rw.rotation.z, TAU)
			if _wheel_tw:
				_wheel_tw.kill()
			_wheel_tw = create_tween()
			_wheel_tw.tween_property(rw, "rotation:z", target, 3.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			_label("wheel", 0).text = "..."
			_later(3.5, _label("wheel", 0), str(Casino.WHEEL_SEGMENTS[int(d.index)].label))
		"roulette":
			_roul_v = 7.0
			# green is slot 0, odd slots red, even slots black; roll picks which one
			var slot := 0 if int(d.roll) == 0 else (1 if str(d.landed) == "red" else 2) + (int(d.roll) % 8) * 2
			_roul_slot[seat] = (slot + 0.5) * TAU / 18.0
			_roul_t[seat] = 2.4
			_label("roulette", seat).text = "NO MORE BETS"
			_later(2.4, _label("roulette", seat), "%s %d" % [str(d.landed).to_upper(), int(d.roll)])
		"ducks":
			_duck_t = 3.5
			_duck_win = int(d.winner)
			_label("ducks", 0).text = "AND THEY'RE OFF"
			_later(3.5, _label("ducks", 0), "%s WINS" % CasinoTables.DUCKS[_duck_win])
		"crash_start":
			_crash_t0 = Time.get_ticks_msec()
			_chart_reset()
		"crash_end":
			_crash_t0 = -1
			var l := _label("crash", 0)
			l.text = "x%.2f" % float(d.mult)
			l.modulate = Color("#8ce36b") if d.won else Color("#ff5a5a")
			if not d.won:
				Sfx.at(host, "boom", LobbyBuilder.CRASH, -4.0, 0.1, 1.5)
		"bj":
			_draw_table(d)
			var npcs := refs.get("npcs") as Npcs
			if npcs:
				npcs.deal_t = 1.0
		"poker":
			_draw_poker(seat, d)


func _later(secs: float, l: Label3D, text: String) -> void:
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(l):
			l.text = text)


# --- crash chart: the line actually draws itself up the wall ------------------------

func _chart_reset() -> void:
	if _chart:
		_chart.queue_free()
	_chart = Node3D.new()
	get_parent().add_child(_chart)
	_chart_t = 0.0


func _chart_tick(delta: float, t: float) -> void:
	_chart_t -= delta
	if _chart == null or _chart_t > 0.0:
		return
	_chart_t = 0.2
	var m := exp(Casino.CRASH_RATE * t)
	var x := clampf(t / 16.0, 0.0, 1.0)
	var y := clampf((m - 1.0) / 3.0, 0.0, 1.0)
	Art.part(_chart, Art.box(Vector3(0.04, 0.12, 0.2)), Color("#46e3ff"), Vector3(51.72, 1.35 + y * 2.9, -13.7 + x * 6.4), Vector3.ONE, Vector3.ZERO, false, 2.0)


# --- three card poker ---------------------------------------------------------------

func _draw_poker(seat: int, d: Dictionary) -> void:
	var c := LobbyBuilder.POKER + Vector3(-1.0 + seat * 2.0, 1.0, -0.72)
	_deal_from = LobbyBuilder.POKER + Vector3(0, 1.1, 0.8)
	var want := {}
	var delay := 0.0
	var p: Array = d.p
	var dl: Array = d.d
	for i in p.size():
		delay = _card("pk%d_%d" % [seat, i], int(p[i]), c + Vector3((i - 1) * 0.28, 0.01 + i * 0.006, 0), false, delay, want)
	for i in dl.size():
		delay = _card("pkd%d_%d" % [seat, i], int(dl[i]), c + Vector3((i - 1) * 0.28, 0.01 + i * 0.006, 0.72), bool(d.hide), delay, want)
	for key: String in _felt.keys():
		if key.begins_with("pk%d_" % seat) or key.begins_with("pkd%d_" % seat):
			if not want.has(key):
				(_felt[key].node as Node3D).queue_free()
				_felt.erase(key)
	_deal_from = Vector3.ZERO
	_label("poker", seat).text = str(d.text)


# --- blackjack table ----------------------------------------------------------------

func _shoe() -> Vector3:
	return LobbyBuilder.BJ_TABLE + Vector3(2.0, 1.1, 0.1)


## Syncs the felt with the host's view. Only new cards animate: they fly out of the
## shoe, one after another, which is what makes it read as dealing.
func _draw_table(v: Dictionary) -> void:
	bj_view = v
	var want := {}
	var delay := 0.0
	var seats: Dictionary = v.seats
	var keys: Array = seats.keys()
	keys.sort()
	for k: int in keys:
		var s: Dictionary = seats[k]
		var hand: Array = s.hand
		var spot := LobbyBuilder.bj_spot(k)
		for i in hand.size():
			var at := spot + Vector3((i - (hand.size() - 1) * 0.5) * 0.24, 0.012 + i * 0.006, -0.02 + i * 0.03)
			delay = _card("s%d_%d" % [k, i], int(hand[i]), at, false, delay, want)
		_bet_chips(k, int(s.bet), spot, want)
		var l := _label("blackjack", k)
		l.text = "" if hand.is_empty() else ("%s  %d" % [str(s.res), Casino.bj_total(hand)] if str(s.res) != "" else str(Casino.bj_total(hand)))
		if hand.is_empty():
			l.text = "%dc" % int(s.bet)
		l.modulate = Ui.ACCENT if int(v.turn) == k else Ui.YELLOW
	for i in LobbyBuilder.BJ_SEATS:
		if not seats.has(i):
			_label("blackjack", i).text = ""
	var dealer: Array = v.dealer
	for i in dealer.size():
		var at := LobbyBuilder.BJ_TABLE + Vector3((i - (dealer.size() - 1) * 0.5) * 0.46 - 0.2, 1.0, 0.3)
		delay = _card("d_%d" % i, int(dealer[i]), at, bool(v.hide) and i == 1, delay, want)
	for key: String in _felt.keys():
		if not want.has(key):
			(_felt[key].node as Node3D).queue_free()
			_felt.erase(key)
	var head := _table_head()
	head.text = {"idle": "", "betting": "PLACE YOUR BETS", "turns": "", "dealer": "DEALER PLAYS", "payout": ""}.get(str(v.state), "")
	if str(v.state) in ["dealer", "payout"] and not dealer.is_empty():
		head.text = "DEALER %d" % Casino.bj_total(dealer)


func _table_head() -> Label3D:
	return refs.bj_head


func _card(key: String, c: int, at: Vector3, down: bool, delay: float, want: Dictionary) -> float:
	want[key] = true
	if _felt.has(key):
		if bool(_felt[key].down) == down:
			return delay  # already out (or still flying to its spot)
		# the dealer's hole card turns over where it lies
		(_felt[key].node as Node3D).queue_free()
		_felt.erase(key)
		var flip := _card_node(c, false)
		get_parent().add_child(flip)
		flip.position = at
		flip.scale = Vector3(0.1, 1, 1)
		flip.create_tween().tween_property(flip, "scale", Vector3.ONE, 0.18)
		_felt[key] = {"node": flip, "down": false}
		return delay
	var n := _card_node(c, down)
	get_parent().add_child(n)
	n.position = _deal_from if _deal_from != Vector3.ZERO else _shoe()
	n.scale = Vector3.ONE * 0.6
	_felt[key] = {"node": n, "down": down}
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "position", at, 0.26).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector3.ONE, 0.26).set_delay(delay)
	tw.tween_property(n, "rotation:y", TAU, 0.26).set_delay(delay)
	get_tree().create_timer(delay + 0.02).timeout.connect(func() -> void:
		if is_inside_tree():
			Sfx.at(get_parent(), "click", at, -6.0, 0.25, 1.5))
	return delay + 0.17


func _card_node(c: int, down: bool) -> Node3D:
	var n := Node3D.new()
	Art.part(n, Art.box(Vector3(0.42, 0.012, 0.6)), Color("#fbf7ea"))
	var flat := MeshInstance3D.new()
	flat.material_override = Art.vcol_mat()
	flat.position.y = 0.008
	n.add_child(flat)
	if down:
		flat.mesh = Kit.part_mesh("cards", "back")
		return n
	var suit := c / 13
	flat.mesh = Kit.part_mesh("cards", "s%d" % suit)
	var col := Color("#c4202f") if suit % 2 == 0 else Color("#16121c")
	for sgn: float in [1.0, -1.0]:
		var l := Art.label(n, RANKS[c % 13], Vector3(0.12 * sgn, 0.009, 0.19 * sgn), 0.0034, col, false)
		l.outline_size = 0
		l.rotation = Vector3(-PI * 0.5, PI if sgn > 0.0 else 0.0, 0)
		l.no_depth_test = false
	return n


func _bet_chips(k: int, bet: int, spot: Vector3, want: Dictionary) -> void:
	var key := "b%d_%d" % [k, bet]
	want[key] = true
	if _felt.has(key):
		return
	var n := Node3D.new()
	var cols := {10: Color("#e8372f"), 25: Color("#3fb24a"), 50: Color("#2f6be0")}
	var col: Color = cols.get(bet, Color("#16121c"))
	var stack := clampi(bet / 5, 2, 10)
	for i in stack:
		Art.part(n, Art.cyl(0.075, 0.075, 0.03, 9), col if i % 2 == 0 else Color("#f6efe0"), Vector3(0, 0.015 + i * 0.03, 0))
	get_parent().add_child(n)
	n.position = spot + Vector3(0.3, 0.0, 0.18) + Vector3.UP * 0.0
	_felt[key] = {"node": n, "down": false}


func _process(delta: float) -> void:
	var slots: Array = refs.get("slots", [])
	for m: int in _slots.keys():
		var s: Dictionary = _slots[m]
		s.t = float(s.t) - delta
		var dyn: Dictionary = slots[m]
		for r in 3:
			var node := dyn["reel%d" % r] as Node3D
			if float(s.t) > 1.2 - r * 0.5:
				node.rotate_x(delta * 22.0)
			else:
				node.rotation.x = PI * 0.5 - (int((s.stop as Array)[r]) + 0.5) * TAU / 8.0
		(dyn.lever as Node3D).rotation.x = -0.9 * clampf((float(s.t) - 1.6) * 3.0, 0.0, 1.0)
		if float(s.t) <= 0.0:
			_label("slots", m).text = str(s.text)
			_slots.erase(m)
	var tables: Array = refs.get("roulette", [])
	for i in tables.size():
		var rotor := tables[i].rotor as Node3D
		var ball := tables[i].ball as Node3D
		rotor.rotation.y += delta * (0.25 + _roul_v)
		var left := float(_roul_t.get(i, 0.0))
		if left > 0.6:  # ball runs the other way round the rim
			_roul_t[i] = left - delta
			ball.rotation.y -= delta * (_roul_v * 2.0)
		elif _roul_slot.has(i):  # then drops and rides in its slot with the wheel
			_roul_t[i] = maxf(0.0, left - delta)
			var seated := rotor.rotation.y - float(_roul_slot[i])
			ball.rotation.y = lerp_angle(ball.rotation.y, seated, clampf(delta * 9.0, 0.0, 1.0))
	_roul_v = move_toward(_roul_v, 0.0, delta * 2.6)
	if _crash_t0 >= 0:
		var t := (Time.get_ticks_msec() - _crash_t0) / 1000.0
		var l := _label("crash", 0)
		l.text = "x%.2f" % exp(Casino.CRASH_RATE * t)
		l.modulate = Ui.YELLOW
		_chart_tick(delta, t)
	var ducks: Dictionary = refs.get("ducks", {})
	if _duck_t > 0.0 and not ducks.is_empty():
		_duck_t -= delta
		var p := 1.0 - _duck_t / 3.5
		for i in 4:
			var speed := 1.0 if i == _duck_win else 0.8 + 0.12 * sin(i * 7.3)
			var dn := ducks["duck%d" % i] as Node3D
			dn.position.x = -3.9 + 7.8 * clampf(p * speed, 0.0, 1.0)
			dn.position.y = 1.05 + absf(sin(_duck_t * 14.0 + i)) * 0.08
		if _duck_t <= 0.0:
			get_tree().create_timer(1.5).timeout.connect(_reset_ducks)


func _reset_ducks() -> void:
	if not is_inside_tree():
		return
	var ducks: Dictionary = refs.get("ducks", {})
	for i in 4:
		if ducks.has("duck%d" % i):
			(ducks["duck%d" % i] as Node3D).position.x = -3.9
