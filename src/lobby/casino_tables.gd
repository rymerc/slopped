class_name CasinoTables
extends Node
## Playing at the machines. There are no game windows: E sits you down, the camera
## moves in, and everything happens on the physical table or screen, where anyone
## walking past can watch you lose. This node is input and prompt only. The host
## (Casino) decides outcomes, and CasinoFloorFx draws them on every peer.

const BETS := [10, 25, 50]
const ANIM := {"slots": 2.2, "wheel": 3.7, "ducks": 3.7, "roulette": 2.6}
const DUCKS := ["YELLOW", "PINK", "BLUE", "GREEN"]
const PICKS := ["red", "black", "green"]

var game: WorldBase
var casino: Casino
var floor_fx: CasinoFloorFx
var kind := ""
var seat := 0
var _view: Array = []
var _k := 0.0
var _prompt: Label
var _msg: Label
var _bet := 0
var _pick := 0
var _busy := false
var _crash := false
var _pk_hand := false
var _pending := ""
var _pending_t := 0.0


func _ready() -> void:
	process_priority = 100  # after CamRig, so the seat view wins
	var box := Ui.vbox(4)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -54
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg = Ui.label("", 26, Ui.YELLOW)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_msg)
	_prompt = Ui.label("", 22)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prompt)
	game.hud.add_child(box)
	box.visible = false
	casino.result.connect(_on_result)


func seated() -> bool:
	return kind != ""


func sit(k: String, s: int) -> void:
	var seats: Array = floor_fx.refs.seats[k]
	kind = k
	seat = s
	_view = (seats[s] as Dictionary).view
	_k = 0.0
	_busy = false
	_crash = false
	_msg.text = ""
	_msg.get_parent().visible = true
	game.ui_open = true
	Sfx.ui(game, "click")


func leave() -> void:
	if not seated():
		return
	kind = ""
	_msg.get_parent().visible = false
	game.ui_open = false
	game.cam.cam.transform = Transform3D.IDENTITY


func _input(event: InputEvent) -> void:
	if not seated() or event is InputEventMouseMotion:
		return
	for pair: Array in [["interact", _act], ["primary", _act2], ["secondary", _act3],
			["ability_1", _cycle.bind(-1)], ["ability_2", _cycle.bind(1)]]:
		if event.is_action_pressed(pair[0]):
			(pair[1] as Callable).call()
			get_viewport().set_input_as_handled()
			return


func _send(method: String, args: Array = []) -> void:
	Net.to_server(casino, method, args)


func _act() -> void:
	if kind == "poker":
		if _pk_hand:
			_send("req_pk_play")
		else:
			_msg.text = ""
			_send("req_pk_ante", [BETS[_bet], seat])
		return
	if kind == "blackjack":
		if _my_turn():
			_send("req_bj_hit")
		elif _can_bet():
			_msg.text = ""
			_send("req_bj_bet", [BETS[_bet], seat])
		return
	if kind == "crash" and _crash:
		_send("req_crash_cashout")
		return
	if _busy:
		return
	_busy = true
	_msg.text = ""
	match kind:
		"slots": _send("req_slots", [seat])
		"wheel": _send("req_wheel")
		"ducks": _send("req_ducks", [_pick])
		"roulette": _send("req_roulette", [PICKS[_pick], seat])
		"crash": _send("req_crash_start", [BETS[_bet]])


func _act2() -> void:
	if kind == "poker" and _pk_hand:
		_send("req_pk_fold")
	if kind == "blackjack" and _my_turn():
		_send("req_bj_stand")


func _act3() -> void:
	if kind == "blackjack" and _my_turn():
		_send("req_bj_double")


func _my_seat() -> Dictionary:
	return (floor_fx.bj_view.get("seats", {}) as Dictionary).get(seat, {})


func _my_turn() -> bool:
	return int(floor_fx.bj_view.get("turn", -1)) == seat and int(_my_seat().get("id", -1)) == Net.me()


func _can_bet() -> bool:
	return str(floor_fx.bj_view.get("state", "idle")) in ["idle", "betting"] and _my_seat().is_empty()


func _cycle(d: int) -> void:
	if _busy or _crash or _pk_hand or (kind == "blackjack" and not _can_bet()):
		return
	match kind:
		"crash", "blackjack", "poker": _bet = posmod(_bet + d, BETS.size())
		"ducks": _pick = posmod(_pick + d, 4)
		"roulette": _pick = posmod(_pick + d, PICKS.size())
	if kind == "ducks" or kind == "roulette":
		Sfx.ui(game, "click")


func _on_result(k: String, data: Dictionary) -> void:
	match k:
		"broke":
			_busy = false
			_msg.text = str(data.msg)
		"shop":
			pass
		"crash_start":
			_crash = true
			_busy = false
		"crash_end":
			_crash = false
			_msg.text = str(data.msg)
		"bj":
			_msg.text = str(data.get("msg", ""))
		"pk":
			_pk_hand = not bool(data.done)
			_msg.text = str(data.get("msg", ""))
		_:
			_pending = str(data.msg)
			_pending_t = float(ANIM.get(k, 1.0))


func _process(delta: float) -> void:
	if _pending_t > 0.0:
		_pending_t -= delta
		if _pending_t <= 0.0:
			_busy = false
			if seated():
				_msg.text = _pending
	if not seated():
		return
	_k = minf(1.0, _k + delta * 3.0)
	var c: Camera3D = game.cam.cam
	var want := Transform3D(Basis.IDENTITY, _view[0]).looking_at(_view[1])
	c.global_transform = c.global_transform.interpolate_with(want, ease(_k, -2.0))
	_prompt.text = _hint()


func _hint() -> String:
	var e := InputSetup.label("interact")
	var q := InputSetup.label("ability_1")
	var f := InputSetup.label("ability_2")
	var money := ("chips: %d" if casino.chips_mode else "coins: %d") % casino.balance(Net.me())
	var line := ""
	match kind:
		"slots": line = "[%s] PULL (%dc)" % [e, Casino.SLOT_COST]
		"wheel": line = "[%s] SPIN (%dc)" % [e, Casino.WHEEL_COST]
		"ducks": line = "[%s/%s] duck: %s   [%s] BET (%dc)" % [q, f, DUCKS[_pick], e, Casino.DUCK_COST]
		"roulette": line = "[%s/%s] on: %s   [%s] SPIN (%dc)" % [q, f, str(PICKS[_pick]).to_upper(), e, Casino.ROULETTE_COST]
		"crash":
			line = "[%s] CASH OUT" % e if _crash else "[%s/%s] bet: %d   [%s] LAUNCH" % [q, f, BETS[_bet], e]
		"poker":
			if _pk_hand:
				line = "[%s] PLAY (%dc)   [%s] FOLD" % [e, BETS[_bet], InputSetup.label("primary")]
			else:
				line = "[%s/%s] ante: %d   [%s] DEAL ME IN" % [q, f, BETS[_bet], e]
		"blackjack":
			if _my_turn():
				line = "YOUR TURN   [%s] HIT   [%s] STAND   [%s] DOUBLE" % [e, InputSetup.label("primary"), InputSetup.label("secondary")]
			elif _can_bet():
				line = "[%s/%s] bet: %d   [%s] PLACE BET" % [q, f, BETS[_bet], e]
			else:
				line = "the dealer is watching you" if not _my_seat().is_empty() else "wait for the next hand"
	return "%s      %s      [%s] walk away" % [line, money, InputSetup.label("menu")]
