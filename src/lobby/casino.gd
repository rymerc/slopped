class_name Casino
extends Node
## Server-authoritative gambling + shop. Clients send req_*; the host rolls the
## dice, mutates Net.players, and replies to the requester's CasinoUI.

signal result(kind: String, data: Dictionary)  # emitted on the requesting peer

const SLOT_SYMBOLS := ["CHERRY", "BELL", "LEMON", "7", "SKULL"]
const SLOT_WEIGHTS := [30, 25, 25, 10, 10]
const SLOT_COST := 10
const WHEEL_COST := 15
const DUCK_COST := 10
const DUCK_PAYOUT := 3.5
const CRASH_RATE := 0.16  # multiplier = e^(rate * seconds)
const WHEEL_SEGMENTS := [
	{"label": "+PERK", "kind": "perk"},
	{"label": "CURSED", "kind": "curse"},
	{"label": "+30c", "kind": "coins"},
	{"label": "CURSE A FRIEND", "kind": "curse_other"},
	{"label": "NOTHING", "kind": "none"},
	{"label": "+PERK", "kind": "perk"},
	{"label": "DOUBLE CURSE", "kind": "curse2"},
	{"label": "JACKPOT 80c", "kind": "jackpot"},
]

var _crash: Dictionary = {}  # peer -> {bet, start_ms, point}


# --- requests (client -> server) -------------------------------------------

@rpc("any_peer", "reliable")
func req_slots() -> void:
	var id := Net.sender()
	if not _pay(id, SLOT_COST):
		return
	var reels: Array = []
	for i in 3:
		reels.append(_weighted(SLOT_SYMBOLS, SLOT_WEIGHTS))
	var msg := "Nothing. The house thanks you."
	if reels[0] == reels[1] and reels[1] == reels[2]:
		match str(reels[0]):
			"7":
				Net.give_coins(id, 100)
				msg = "JACKPOT! +100c and " + _grant(id, true)
				Net.announce("%s hit the slots JACKPOT" % Net.pname(id))
			"SKULL":
				msg = "TRIPLE SKULL. " + _grant(id, false) + " and " + _grant(id, false)
				Net.announce("%s got double-cursed by the slots" % Net.pname(id))
			_:
				Net.give_coins(id, 20)
				msg = "Triple! +20c and " + _grant(id, true)
	elif reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		Net.give_coins(id, 15)
		msg = "Pair! +15c"
	elif reels.has("SKULL") and randf() < 0.25:
		msg = "A skull stares back. " + _grant(id, false)
	_reply(id, "slots", {"reels": reels, "msg": msg})


@rpc("any_peer", "reliable")
func req_crash_start(bet: int) -> void:
	var id := Net.sender()
	if _crash.has(id) or not [10, 25, 50].has(bet) or not _pay(id, bet):
		return
	# House edge ~4%: P(point >= m) = 0.96 / m
	var point := clampf(0.96 / maxf(0.0001, 1.0 - randf()), 1.0, 60.0)
	_crash[id] = {"bet": bet, "start": Time.get_ticks_msec(), "point": point}
	_reply(id, "crash_start", {"bet": bet})


@rpc("any_peer", "reliable")
func req_crash_cashout() -> void:
	var id := Net.sender()
	if not _crash.has(id):
		return
	var c: Dictionary = _crash[id]
	var m := _crash_mult(c)
	if m >= float(c.point):
		return  # already busted; _process will report it
	_crash.erase(id)
	var win := int(round(int(c.bet) * m))
	Net.give_coins(id, win)
	var msg := "Cashed out at x%.2f: +%dc" % [m, win]
	if m >= 3.0:
		msg += " and " + _grant(id, true)
	_reply(id, "crash_end", {"mult": m, "won": true, "msg": msg})


@rpc("any_peer", "reliable")
func req_wheel() -> void:
	var id := Net.sender()
	if not _pay(id, WHEEL_COST):
		return
	var idx := randi() % WHEEL_SEGMENTS.size()
	var msg := ""
	match str(WHEEL_SEGMENTS[idx].kind):
		"perk":
			msg = _grant(id, true)
		"curse":
			msg = _grant(id, false)
		"curse2":
			msg = _grant(id, false) + " + " + _grant(id, false)
		"coins":
			Net.give_coins(id, 30)
			msg = "+30c"
		"jackpot":
			Net.give_coins(id, 80)
			msg = "+80c!"
			Net.announce("%s hit the wheel jackpot" % Net.pname(id))
		"curse_other":
			msg = _curse_random_other(id)
		_:
			msg = "Nothing. Spin again?"
	_reply(id, "wheel", {"index": idx, "msg": msg})


@rpc("any_peer", "reliable")
func req_ducks(pick: int) -> void:
	var id := Net.sender()
	if pick < 0 or pick > 3 or not _pay(id, DUCK_COST):
		return
	var winner := randi() % 4
	var msg := "Your duck lost. It is ashamed."
	if winner == pick:
		var won := int(DUCK_COST * DUCK_PAYOUT)
		Net.give_coins(id, won)
		msg = "Your duck WON! +%dc" % won
		if randf() < 0.3:
			msg += ". It also pooped on someone: " + _curse_random_other(id)
	_reply(id, "ducks", {"winner": winner, "pick": pick, "msg": msg})


@rpc("any_peer", "reliable")
func req_buy(perk: String) -> void:
	var id := Net.sender()
	if not PerkDB.PERKS.has(perk) or not PerkDB.info(perk).good:
		return
	if not _pay(id, PerkDB.SHOP_PRICE):
		return
	Net.give_perk(id, perk)
	Net.broadcast()
	_reply(id, "shop", {"msg": "Bought %s" % PerkDB.info(perk).name})


@rpc("any_peer", "reliable")
func req_curse(target: int) -> void:
	var id := Net.sender()
	if target == id or not Net.players.has(target) or not _pay(id, PerkDB.CURSE_PRICE):
		return
	var c := PerkDB.random_bad()
	Net.give_perk(target, c)
	Net.broadcast()
	Net.announce("Someone paid to curse %s with %s" % [Net.pname(target), PerkDB.info(c).name])
	_reply(id, "shop", {"msg": "Curse delivered. They'll never know it was you."})


# --- server internals -------------------------------------------------------

func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for id: int in _crash.keys():
		var c: Dictionary = _crash[id]
		var m := _crash_mult(c)
		if m >= float(c.point):
			_crash.erase(id)
			var msg := "CRASHED at x%.2f. -%dc" % [float(c.point), int(c.bet)]
			if randf() < 0.3:
				msg += " and " + _grant(id, false)
			_reply(id, "crash_end", {"mult": float(c.point), "won": false, "msg": msg})


func _crash_mult(c: Dictionary) -> float:
	var t := (Time.get_ticks_msec() - int(c.start)) / 1000.0
	return exp(CRASH_RATE * t)


func _pay(id: int, cost: int) -> bool:
	if not multiplayer.is_server() or not Net.players.has(id):
		return false
	if int(Net.players[id].coins) < cost:
		_reply(id, "broke", {"msg": "Not enough coins. Win some games, peasant."})
		return false
	Net.give_coins(id, -cost)
	return true


func _grant(id: int, good: bool) -> String:
	var p := PerkDB.random_good() if good else PerkDB.random_bad()
	Net.give_perk(id, p)
	return ("perk: %s" if good else "curse: %s") % PerkDB.info(p).name


func _curse_random_other(id: int) -> String:
	var others: Array = Net.players.keys().filter(func(k: int) -> bool: return k != id)
	if others.is_empty():
		return "no friends to curse (sad)"
	var t: int = others.pick_random()
	var c := PerkDB.random_bad()
	Net.give_perk(t, c)
	Net.announce("%s cursed %s with %s" % [Net.pname(id), Net.pname(t), PerkDB.info(c).name])
	return "%s now has %s" % [Net.pname(t), PerkDB.info(c).name]


func _weighted(items: Array, weights: Array) -> Variant:
	var total := 0
	for w: int in weights:
		total += w
	var r := randi() % total
	for i in items.size():
		r -= int(weights[i])
		if r < 0:
			return items[i]
	return items[0]


func _reply(id: int, kind: String, data: Dictionary) -> void:
	Net.broadcast()
	Net.call_peer(id, self, "_result", [kind, data])


@rpc("authority", "reliable")
func _result(kind: String, data: Dictionary) -> void:
	result.emit(kind, data)
