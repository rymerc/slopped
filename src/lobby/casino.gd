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

const BJ_SEATS := 5
const BJ_BET_SECS := 5.0
const BJ_TURN_SECS := 15.0
const BJ_STEP := 0.8
const BJ_RESULT_SECS := 5.0
const ROULETTE_COST := 10
const ROULETTE_PICKS := {"red": {"slots": 18, "pay": 2}, "black": {"slots": 18, "pay": 2}, "green": {"slots": 1, "pay": 14}}

var _crash: Dictionary = {}  # peer -> {bet, start_ms, point}
var bj: Dictionary = _bj_empty()
var _pk: Dictionary = {}  # peer -> {bet, seat, p, d}
var chips_mode := false  # Cursed Casino Night: play for chips, not coins
var chips: Dictionary = {}
var house_bank := 0
var rig := 0  # 0..3, set by the house player


# --- requests (client -> server) -------------------------------------------

@rpc("any_peer", "reliable")
func req_slots(seat: int) -> void:
	do_slots(Net.sender(), seat)


func do_slots(id: int, seat := 0) -> void:
	if not _pay(id, SLOT_COST):
		return
	var reels: Array = []
	var weights: Array = SLOT_WEIGHTS.duplicate()
	weights[4] = int(weights[4]) + rig * 25  # the house leans on the skull reel
	for i in 3:
		reels.append(_weighted(SLOT_SYMBOLS, weights))
	var msg := "Nothing. The house thanks you."
	if reels[0] == reels[1] and reels[1] == reels[2]:
		match str(reels[0]):
			"7":
				_gain(id, 100)
				msg = "JACKPOT! +100c and " + _grant(id, true)
				Net.announce("%s hit the slots JACKPOT" % Net.pname(id))
			"SKULL":
				msg = "TRIPLE SKULL. " + _grant(id, false) + " and " + _grant(id, false)
				Net.announce("%s got double-cursed by the slots" % Net.pname(id))
			_:
				_gain(id, 20)
				msg = "Triple! +20c and " + _grant(id, true)
	elif reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		_gain(id, 15)
		msg = "Pair! +15c"
	elif reels.has("SKULL") and randf() < 0.25:
		msg = "A skull stares back. " + _grant(id, false)
	_fx.rpc("slots", seat, {"reels": reels})
	_reply(id, "slots", {"reels": reels, "msg": msg})


@rpc("any_peer", "reliable")
func req_crash_start(bet: int) -> void:
	var id := Net.sender()
	if _crash.has(id) or not [10, 25, 50].has(bet) or not _pay(id, bet):
		return
	# House edge ~4%: P(point >= m) = 0.96 / m
	var point := clampf(0.96 / maxf(0.0001, 1.0 - randf()) * (1.0 - rig * 0.13), 1.0, 60.0)
	_crash[id] = {"bet": bet, "start": Time.get_ticks_msec(), "point": point}
	_fx.rpc("crash_start", 0, {})
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
	_gain(id, win)
	var msg := "Cashed out at x%.2f: +%dc" % [m, win]
	if m >= 3.0:
		msg += " and " + _grant(id, true)
	_fx.rpc("crash_end", 0, {"mult": m, "won": true})
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
			_gain(id, 30)
			msg = "+30c"
		"jackpot":
			_gain(id, 80)
			msg = "+80c!"
			Net.announce("%s hit the wheel jackpot" % Net.pname(id))
		"curse_other":
			msg = _curse_random_other(id)
		_:
			msg = "Nothing. Spin again?"
	_fx.rpc("wheel", 0, {"index": idx})
	_reply(id, "wheel", {"index": idx, "msg": msg})


@rpc("any_peer", "reliable")
func req_ducks(pick: int) -> void:
	var id := Net.sender()
	if pick < 0 or pick > 3 or not _pay(id, DUCK_COST):
		return
	var winner := randi() % 4
	if winner == pick and randf() < rig * 0.22:
		winner = (pick + 1) % 4
	var msg := "Your duck lost. It is ashamed."
	if winner == pick:
		var won := int(DUCK_COST * DUCK_PAYOUT)
		_gain(id, won)
		msg = "Your duck WON! +%dc" % won
		if randf() < 0.3:
			msg += ". It also pooped on someone: " + _curse_random_other(id)
	_fx.rpc("ducks", 0, {"winner": winner})
	_reply(id, "ducks", {"winner": winner, "pick": pick, "msg": msg})


@rpc("any_peer", "reliable")
func req_roulette(pick: String, seat: int) -> void:
	do_roulette(Net.sender(), pick, seat)


func do_roulette(id: int, pick: String, seat := 0) -> void:
	if not ROULETTE_PICKS.has(pick) or not _pay(id, ROULETTE_COST):
		return
	var roll := randi() % 37  # 0 = green, odd = red, even = black
	var landed := "green" if roll == 0 else ("red" if roll % 2 == 1 else "black")
	if landed == pick and randf() < rig * 0.22:  # a magnet under the table
		roll = 0
		landed = "green"
	var msg := "%s %d. The house thanks you." % [landed.to_upper(), roll]
	if landed == pick:
		var won: int = ROULETTE_COST * int(ROULETTE_PICKS[pick].pay)
		_gain(id, won)
		msg = "%s %d! +%dc" % [landed.to_upper(), roll, won]
		if pick == "green":
			Net.announce("%s hit GREEN on the roulette" % Net.pname(id))
	_fx.rpc("roulette", seat, {"roll": roll, "landed": landed})
	_reply(id, "roulette", {"landed": landed, "roll": roll, "pick": pick, "msg": msg})


## Tells every peer to animate the physical machine in the casino.
@rpc("authority", "call_local", "reliable")
func _fx(kind: String, seat: int, data: Dictionary) -> void:
	var w := get_parent()
	if w and w.has_method("casino_fx"):
		w.casino_fx(kind, seat, data)


# --- blackjack --------------------------------------------------------------------
# Cards are 0..51: rank = c % 13 (0 = ace), suit = c / 13. Dealer stands on 17.

static func bj_total(hand: Array) -> int:
	var t := 0
	var aces := 0
	for c: int in hand:
		var r := c % 13
		if r == 0:
			aces += 1
			t += 11
		else:
			t += mini(r + 1, 10)
	while t > 21 and aces > 0:
		t -= 10
		aces -= 1
	return t


## One shared table: bets during a short countdown, cards go round the seats, turns
## run in seat order, then the dealer plays. Empty seats may fill with townsfolk.
@rpc("any_peer", "reliable")
func req_bj_bet(bet: int, seat: int) -> void:
	var id := Net.sender()
	if not str(bj.state) in ["idle", "betting"] or not [10, 25, 50].has(bet) or seat < 0 or seat >= BJ_SEATS:
		return
	if (bj.seats as Dictionary).has(seat) or not _pay(id, bet):
		return
	bj.seats[seat] = {"id": id, "bet": bet, "hand": [], "res": ""}
	if bj.state == "idle":
		bj.state = "betting"
		bj.t = BJ_BET_SECS
	_bj_push()


func _bj_mine(id: int) -> bool:
	return bj.state == "turns" and (bj.seats as Dictionary).has(bj.turn) and int(bj.seats[bj.turn].id) == id


@rpc("any_peer", "reliable")
func req_bj_hit() -> void:
	if _bj_mine(Net.sender()):
		_bj_hit()


@rpc("any_peer", "reliable")
func req_bj_stand() -> void:
	if _bj_mine(Net.sender()):
		_bj_next()


@rpc("any_peer", "reliable")
func req_bj_double() -> void:
	var id := Net.sender()
	if not _bj_mine(id):
		return
	var s: Dictionary = bj.seats[bj.turn]
	if (s.hand as Array).size() != 2 or not _pay(id, int(s.bet)):
		return
	s.bet = int(s.bet) * 2
	(s.hand as Array).append(randi() % 52)
	_bj_next()


func _bj_hit() -> void:
	var s: Dictionary = bj.seats[bj.turn]
	(s.hand as Array).append(randi() % 52)
	if bj_total(s.hand) >= 21:
		_bj_next()
	else:
		bj.t = BJ_TURN_SECS if int(s.id) != 0 else BJ_STEP
		_bj_push()


func _bj_deal() -> void:
	for i in BJ_SEATS:
		if not (bj.seats as Dictionary).has(i) and randf() < 0.55:
			bj.seats[i] = {"id": 0, "bet": 25, "hand": [], "res": ""}  # a local takes the stool
	for k: int in bj.seats:
		bj.seats[k].hand = [randi() % 52, randi() % 52]
	bj.dealer = [randi() % 52, randi() % 52]
	bj.turn = -1
	_bj_next()


## Moves to the next seat that can still act, or to the dealer.
func _bj_next() -> void:
	var keys: Array = (bj.seats as Dictionary).keys()
	keys.sort()
	for k: int in keys:
		if k > int(bj.turn) and bj_total(bj.seats[k].hand) < 21:
			bj.state = "turns"
			bj.turn = k
			bj.t = BJ_TURN_SECS if int(bj.seats[k].id) != 0 else BJ_STEP * 2.0
			_bj_push()
			return
	bj.state = "dealer"
	bj.turn = -1
	bj.t = BJ_STEP * 1.5
	_bj_push()


func _bj_tick(delta: float) -> void:
	if bj.state == "idle":
		return
	bj.t = float(bj.t) - delta
	if float(bj.t) > 0.0:
		return
	match str(bj.state):
		"betting":
			_bj_deal()
		"turns":
			var s: Dictionary = bj.seats[bj.turn]
			if int(s.id) == 0 and bj_total(s.hand) < 15:
				_bj_hit()
			else:
				_bj_next()
		"dealer":
			if bj_total(bj.dealer) < 17:
				(bj.dealer as Array).append(randi() % 52)
				if bj_total(bj.dealer) > 21 and randf() < rig * 0.25:  # the deck has opinions
					(bj.dealer as Array).pop_back()
				bj.t = BJ_STEP
				_bj_push()
			else:
				_bj_settle()
		"payout":
			bj = _bj_empty()
			_bj_push()


func _bj_empty() -> Dictionary:
	return {"state": "idle", "t": 0.0, "seats": {}, "dealer": [], "turn": -1}


func _bj_settle() -> void:
	var dt := bj_total(bj.dealer)
	for k: int in bj.seats:
		var s: Dictionary = bj.seats[k]
		var pt := bj_total(s.hand)
		var bet := int(s.bet)
		var natural: bool = pt == 21 and (s.hand as Array).size() == 2
		var pay := 0
		var msg := ""
		if pt > 21:
			msg = "BUST with %d. The dealer does not blink." % pt
			s.res = "BUST"
		elif natural and dt != 21:
			pay = bet + bet * 3 / 2
			msg = "BLACKJACK! +%dc" % (bet * 3 / 2)
			s.res = "BLACKJACK"
		elif dt > 21 or pt > dt:
			pay = bet * 2
			msg = "You win %d to %d. +%dc" % [pt, dt, bet]
			s.res = "WIN"
		elif pt == dt:
			pay = bet
			msg = "Push at %d. The dealer stares." % pt
			s.res = "PUSH"
		else:
			msg = "Dealer has %d, you have %d." % [dt, pt]
			s.res = "LOSE"
		if int(s.id) != 0 and Net.players.has(int(s.id)):
			if pay > 0:
				_gain(int(s.id), pay)
			_reply(int(s.id), "bj", {"done": true, "msg": msg})
	bj.state = "payout"
	bj.t = BJ_RESULT_SECS
	_bj_push()


## What every peer needs to draw the table.
func _bj_push() -> void:
	var seats := {}
	for k: int in bj.seats:
		var s: Dictionary = bj.seats[k]
		seats[k] = {"id": s.id, "bet": s.bet, "hand": s.hand, "res": s.res,
			"name": Net.pname(int(s.id)) if int(s.id) != 0 else "a local"}
	_fx.rpc("bj", 0, {"state": bj.state, "hide": str(bj.state) in ["betting", "turns"], "turn": bj.turn,
		"t": float(bj.t), "dealer": bj.dealer, "seats": seats})


# --- three card poker: ante, look, then fold or pay again to play -----------------

## [category, tiebreaks...] compares as an array. 5 straight flush .. 0 high card.
static func pk_rank(hand: Array) -> Array:
	var r: Array = hand.map(func(c: int) -> int: return 12 if c % 13 == 0 else (c % 13) - 1)  # ace high
	r.sort()
	r.reverse()
	var flush: bool = hand[0] / 13 == hand[1] / 13 and hand[1] / 13 == hand[2] / 13
	var run: bool = int(r[0]) - int(r[2]) == 2 and r[0] != r[1] and r[1] != r[2]
	if r[0] == r[1] and r[1] == r[2]:
		return [4, r[0]]
	if run and flush:
		return [5, r[0]]
	if run:
		return [3, r[0]]
	if flush:
		return [2, r[0], r[1], r[2]]
	if r[0] == r[1]:
		return [1, r[0], r[2]]
	if r[1] == r[2]:
		return [1, r[1], r[0]]
	return [0, r[0], r[1], r[2]]


static func pk_name(hand: Array) -> String:
	return ["high card", "a pair", "a flush", "a straight", "three of a kind", "a straight flush"][int(pk_rank(hand)[0])]


func _pk_beats(a: Array, b: Array) -> int:
	var x := pk_rank(a)
	var y := pk_rank(b)
	for i in mini(x.size(), y.size()):
		if int(x[i]) != int(y[i]):
			return 1 if int(x[i]) > int(y[i]) else -1
	return 0


@rpc("any_peer", "reliable")
func req_pk_ante(bet: int, seat: int) -> void:
	var id := Net.sender()
	if _pk.has(id) or not [10, 25, 50].has(bet) or seat < 0 or seat > 1 or not _pay(id, bet):
		return
	var p: Array = []
	var d: Array = []
	var used: Array = []
	for i in 6:  # one real deck: no two identical cards
		var c := randi() % 52
		while used.has(c):
			c = randi() % 52
		used.append(c)
		(p if i % 2 == 0 else d).append(c)
	_pk[id] = {"bet": bet, "seat": seat, "p": p, "d": d}
	_fx.rpc("poker", seat, {"p": p, "d": d, "hide": true, "text": pk_name(p)})
	_reply(id, "pk", {"done": false, "msg": "You have %s." % pk_name(p)})


@rpc("any_peer", "reliable")
func req_pk_fold() -> void:
	var id := Net.sender()
	if not _pk.has(id):
		return
	var h: Dictionary = _pk[id]
	_pk.erase(id)
	_fx.rpc("poker", int(h.seat), {"p": [], "d": [], "hide": false, "text": "FOLDED"})
	_reply(id, "pk", {"done": true, "msg": "You fold. The table watches you do it."})


@rpc("any_peer", "reliable")
func req_pk_play() -> void:
	var id := Net.sender()
	if not _pk.has(id):
		return
	var h: Dictionary = _pk[id]
	var bet := int(h.bet)
	if not _pay(id, bet):
		return
	_pk.erase(id)
	var cmp := _pk_beats(h.p, h.d)
	var dealer_qualifies := int(pk_rank(h.d)[0]) > 0 or int(pk_rank(h.d)[1]) >= 10  # queen high
	var msg := ""
	if not dealer_qualifies:
		_gain(id, bet * 3)
		msg = "Dealer doesn't qualify. Ante pays, play pushes: +%dc" % bet
	elif cmp > 0:
		var bonus := bet * 2 if int(pk_rank(h.p)[0]) >= 3 else 0
		_gain(id, bet * 4 + bonus)
		msg = "%s beats %s. +%dc" % [pk_name(h.p).capitalize(), pk_name(h.d), bet * 2 + bonus]
	elif cmp == 0:
		_gain(id, bet * 2)
		msg = "Tie. Nobody is happy."
	else:
		msg = "Dealer's %s takes it." % pk_name(h.d)
	_fx.rpc("poker", int(h.seat), {"p": h.p, "d": h.d, "hide": false, "text": msg.left(26)})
	_reply(id, "pk", {"done": true, "msg": msg})


## DIRTY DEEDS DEPT.: self items apply now, everything else goes in the bag.
@rpc("any_peer", "reliable")
func req_deed(item: String) -> void:
	var id := Net.sender()
	if not Tricks.ITEMS.has(item):
		return
	var it: Dictionary = Tricks.ITEMS[item]
	if not _pay(id, int(it.price)):
		return
	var p: Dictionary = Net.players[id]
	var msg := "%s is in your bag. Press %s in any world to use it." % [it.name, "the trick key"]
	match str(it.kind):
		"self":
			p[it.field] = int(p.get(it.field, 0)) + 1
			msg = "%s on retainer." % it.name
		"perk":
			Net.give_perk(id, it.perk)
			msg = "%s active for your next match." % it.name
		_:
			(p.bag as Array).append(item)
	Net.broadcast()
	_reply(id, "shop", {"msg": msg})


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

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_bj_tick(delta)
	for id: int in _crash.keys():
		var c: Dictionary = _crash[id]
		var m := _crash_mult(c)
		if m >= float(c.point):
			_crash.erase(id)
			var msg := "CRASHED at x%.2f. -%dc" % [float(c.point), int(c.bet)]
			if randf() < 0.3:
				msg += " and " + _grant(id, false)
			_fx.rpc("crash_end", 0, {"mult": float(c.point), "won": false})
			_reply(id, "crash_end", {"mult": float(c.point), "won": false, "msg": msg})


func _crash_mult(c: Dictionary) -> float:
	var t := (Time.get_ticks_msec() - int(c.start)) / 1000.0
	return exp(CRASH_RATE * t)


func balance(id: int) -> int:
	return int(chips.get(id, 0)) if chips_mode else int(Net.profile(id).get("coins", 0))


func _pay(id: int, cost: int) -> bool:
	if not multiplayer.is_server() or not Net.players.has(id):
		return false
	if balance(id) < cost:
		_reply(id, "broke", {"msg": "Not enough coins. Win some games, peasant."})
		return false
	_gain(id, -cost)
	return true


## Coins normally; on Cursed Casino Night it's chips, and the house banks the difference.
func _gain(id: int, n: int) -> void:
	if not chips_mode:
		Net.give_coins(id, n)
		return
	chips[id] = maxi(0, int(chips.get(id, 0)) + n)
	house_bank = maxi(0, house_bank - n)


func _grant(id: int, good: bool) -> String:
	if chips_mode:
		return "a free drink"
	var p := PerkDB.random_good() if good else PerkDB.random_bad()
	Net.give_perk(id, p)
	return ("perk: %s" if good else "curse: %s") % PerkDB.info(p).name


func _curse_random_other(id: int) -> String:
	if chips_mode:
		return "someone else's problem"
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
