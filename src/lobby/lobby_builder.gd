class_name LobbyBuilder
extends RefCounted
## SLOPSVILLE: the between-games hub, a ridiculous western town.
##   Square      Big Wheel + START button, trampoline, spawn
##   NW          Saloon (Mystery Slop bar, VIP throne)
##   NE          Sheriff (Hall of Fame board, Bot Jail)
##   E           The Lucky Duck Casino (slots, crash, wheel, ducks, roulette)
##   SW          General Store (perk shop)
##   SE          Grand Slop Hotel (wardrobe)
## Main Street runs on the x=0 axis, so the Slide Hill belly-slide spits you into town.
## Art lives in res://assets (built from art_src/); this file only places it and
## says where the gameplay stations are.

const SALOON := Vector3(-21, 0, -33)
const SHERIFF := Vector3(17, 0, -32)
const CASINO := Vector3(40, 0, -1)
const STORE := Vector3(-17, 0, 33)
const HOTEL := Vector3(19, 0, 33.5)

# Stations (world positions). Lobby wires interactions to these.
const START_BTN := Vector3(0, 0, 3)
const BAR := Vector3(-22, 0.4, -36.2)
const THRONE := Vector3(-10.4, 1.2, -36.0)
const VIP_GATE := Vector3(-13.4, 0.4, -26.2)
const PAINT := Vector3(28, 0.4, 37.6)
const HATS := Vector3(24.6, 0.4, 37.6)
const BODY := Vector3(21.2, 0.4, 37.6)
const SLOTS: Array[Vector3] = [Vector3(31.6, 0, -18.4), Vector3(34.0, 0, -18.4), Vector3(36.4, 0, -18.4),
	Vector3(43.6, 0, -18.4), Vector3(46.0, 0, -18.4), Vector3(48.4, 0, -18.4)]
const CRASH := Vector3(49.6, 0, -10.5)
const MINIWHEEL := Vector3(49.8, 0.6, 7.0)
const DUCKS := Vector3(30.8, 0, 10.0)
const ROULETTE: Array[Vector3] = [Vector3(38, 0, -7.5), Vector3(45, 0, -7.5)]
const DEEDS := Vector3(31.2, 0, -13.4)
const BJ_TABLE := Vector3(41.5, 0, 7.4)
const BJ_SEATS := 5
const POKER := Vector3(35.0, 0, 2.9)
const SLOT_MODELS := ["slot_duck", "slot_skull", "slot_soup"]
const SHOP := Vector3(-17, 0.4, 34.2)
const KENNEL := Vector3(17, 0.4, -32)
const TOILET := Vector3(-37, 0, 25)
const TRAMPOLINE := Vector3(0, 0, 18)
const FAME := Vector3(23.2, 3.1, -23.65)


static func build(root: Node3D, b: Batch, props: PropSystem) -> Dictionary:
	var out := {}
	var saloon := Kit.landmark(root, b, "saloon", SALOON)
	out.saloon_doors = saloon.dyn
	Kit.landmark(root, b, "sheriff", SHERIFF)
	Kit.landmark(root, b, "store", STORE, 180.0)
	Kit.landmark(root, b, "hotel", HOTEL, 180.0)
	Kit.landmark(root, b, "casino", CASINO, -90.0)
	Kit.landmark(root, b, "water_tower", Vector3(-40, 0, -2))
	Kit.landmark(root, b, "outhouse", TOILET + Vector3(0, 0, 1.9), 180.0)
	Kit.landmark(root, b, "town_arch", Vector3(0, 0, 45))

	_square(root, b, out)
	_saloon_interior(root, b, out)
	casino_floor(root, b, out)
	_store_and_hotel(root, b)
	_jail(root, b, out)
	_streets(root, b, props)
	return out


static func _square(root: Node3D, b: Batch, out: Dictionary) -> void:
	# Stone circle under the wheel + the big red button
	var stone := Color("#b8ad9f")
	Art.part(root, Art.cyl(11.0, 11.2, 0.12, 24), stone, Vector3(0, 0.06, -1.5))
	Art.part(root, Art.cyl(9.8, 9.8, 0.13, 24), Color("#d3c5ae"), Vector3(0, 0.07, -1.5))
	Art.part(root, Art.cyl(6.4, 6.4, 0.14, 24), Color("#a33a2c"), Vector3(0, 0.08, -1.5))
	Art.solid_cyl(root, 1.4, 1.0, Color("#4a4e69"), START_BTN + Vector3(0, 0.5, 0), -1.0, 12)
	Art.part(root, Art.cyl(1.55, 1.55, 0.18, 12), Art.GOLD, START_BTN + Vector3(0, 0.1, 0))
	var btn := Art.part(root, Art.cyl(0.9, 1.0, 0.35, 12), Color("#e63946"), START_BTN + Vector3(0, 1.15, 0), Vector3.ONE, Vector3.ZERO, true, 0.35)
	out.start_button = btn
	Art.label(root, "START", START_BTN + Vector3(0, 2.2, 0), 0.012, Color.WHITE)
	# Trampoline: a repurposed wagon wheel, naturally
	Art.solid_cyl(root, 2.2, 0.5, Color("#6e4326"), TRAMPOLINE + Vector3(0, 0.25, 0), -1.0, 14)
	Art.part(root, Art.cyl(2.28, 2.28, 0.12, 14), Art.GOLD, TRAMPOLINE + Vector3(0, 0.46, 0))
	Art.part(root, Art.cyl(2.0, 2.0, 0.06, 14), Color("#3ec1ff"), TRAMPOLINE + Vector3(0, 0.52, 0), Vector3.ONE, Vector3.ZERO, false, 0.3)
	# Fountain, benches and planters around the square
	Dress.put(root, b, "fantasytown_fountain_round_detail", Vector3(-17, 0, 6), 0.0, 3.0, Dress.COL_BOX)
	for p: Vector3 in [Vector3(-11, 0, -14), Vector3(11, 0, -14), Vector3(-11, 0, 14), Vector3(11, 0, 14)]:
		Dress.put(root, b, "coaster_bench", p, 90.0 if p.x < 0 else -90.0, 1.4, Dress.COL_NONE, true)
		Dress.put(root, b, "nature_pot_large", p + Vector3(0, 0, 2.0), 0.0, 1.6, Dress.COL_BOX, true)
		Dress.put(root, b, "kk_furniture_cactus_medium_A", p + Vector3(0, 0.5, 2.0), 0.0, 1.5, Dress.COL_NONE, true)


static func _saloon_interior(root: Node3D, b: Batch, out: Dictionary) -> void:
	var f := 0.4
	# stools along the bar
	for i in 8:
		Dress.put(root, b, "kk_restaurant_chair_stool", SALOON + Vector3(-8.0 + i * 2.0, f, -3.3), 15.0 * i, 0.95, Dress.COL_NONE, true)
	# tables
	for t: Vector3 in [Vector3(-7, 0, 2.5), Vector3(-1.5, 0, 4.8), Vector3(3.5, 0, 1.0), Vector3(-8.6, 0, 6.6)]:
		var p := SALOON + t + Vector3(0, f, 0)
		Dress.put(root, b, "kk_furniture_table_small", p, 20.0, 1.25, Dress.COL_BOX)
		for k in 3:
			var a := k * TAU / 3.0 + t.x
			Dress.put(root, b, "kk_furniture_chair_A_wood", p + Vector3(cos(a), 0, sin(a)) * 1.25, rad_to_deg(-a) - 90.0, 0.95, Dress.COL_NONE, true)
		Dress.put(root, b, "food_mug", p + Vector3(0.1, 1.0, 0.15), 0.0, 0.5, Dress.COL_NONE, true)
		Dress.put(root, b, "pirate_bottle", p + Vector3(-0.2, 1.0, -0.1), 0.0, 0.5, Dress.COL_NONE, true)
	Dress.put(root, b, "kk_furniture_rug_oval_A", SALOON + Vector3(-3, f + 0.01, 3), 0.0, 3.0, Dress.COL_NONE, true)
	var up := 5.62
	for t: Vector3 in [Vector3(-6.5, 0, 7.0), Vector3(5.5, 0, 7.0)]:
		var p := SALOON + t + Vector3(0, up, 0)
		Dress.put(root, b, "kk_furniture_table_small", p, -10.0, 1.25, Dress.COL_BOX)
		for k in 2:
			var a := PI * k + 0.3
			Dress.put(root, b, "kk_furniture_chair_A_wood", p + Vector3(cos(a), 0, sin(a)) * 1.25, rad_to_deg(-a) - 90.0, 0.95, Dress.COL_NONE, true)
		Dress.put(root, b, "pirate_bottle", p + Vector3(-0.2, 1.0, -0.1), 0.0, 0.5, Dress.COL_NONE, true)
	# barrels behind the bar + on the porch
	for i in 3:
		Dress.put(root, b, "pirate_barrel", SALOON + Vector3(6.6 - i * 0.5, f, -7.5 + i * 0.2), 30.0 * i, 0.72, Dress.COL_BOX, true)
	for x: float in [-11.4, -9.6, 8.0, 9.8]:
		Dress.put(root, b, "pirate_barrel", SALOON + Vector3(x, f, 11.2), x * 40.0, 0.75, Dress.COL_BOX, true)
	# VIP velvet gate: only the leader's collision is switched off, see Lobby
	var gate := Art.solid_box(root, Vector3(0.25, 4.0, 4.4), Color("#e63946"), VIP_GATE + Vector3(0, 2.0, 0), false)
	(gate.get_child(0) as MeshInstance3D).transparency = 0.9
	out.vip_gate = gate.get_child(1) as CollisionShape3D
	Art.label(root, "VIP: LEADER ONLY", VIP_GATE + Vector3(-1.4, 3.4, 0), 0.012, Art.GOLD)


## Where seat i's cards land on the felt.
static func bj_spot(i: int) -> Vector3:
	var a := deg_to_rad(-60.0 + i * 30.0)
	return BJ_TABLE + Vector3(sin(a) * 2.15, 1.0, -cos(a) * 1.65)


## Where a player sits, outside the rail.
static func bj_stool(i: int) -> Vector3:
	var a := deg_to_rad(-60.0 + i * 30.0)
	return BJ_TABLE + Vector3(sin(a) * 3.75, 0, -cos(a) * 3.0)


## Interact points for the machines. open(kind, seat) sits you down at one.
## Shared by the lobby and Cursed Casino Night.
static func wire_casino(w: WorldBase, open: Callable, cond: Callable = Callable()) -> void:
	for i in SLOTS.size():
		w.add_interact(SLOTS[i] + Vector3(0, 0, 1.2), 1.7, "Play SLOTS", open.bind("slots", i), cond)
	w.add_interact(CRASH + Vector3(-1.4, 0, 0), 2.2, "Play CRASH", open.bind("crash", 0), cond)
	w.add_interact(MINIWHEEL + Vector3(-3.6, -0.6, 0), 3.0, "Spin LIL' WHEEL", open.bind("wheel", 0), cond)
	w.add_interact(DUCKS + Vector3(2.4, 0, 0), 3.2, "Bet on DUCKS", open.bind("ducks", 0), cond)
	for i in ROULETTE.size():
		w.add_interact(ROULETTE[i] + Vector3(0, 0, 2.2), 2.4, "Play ROULETTE", open.bind("roulette", i), cond)
	for i in 2:
		w.add_interact(POKER + Vector3(-1.0 + i * 2.0, 0, -2.0), 1.3, "Sit down at POKER", open.bind("poker", i), cond)
	for i in BJ_SEATS:
		w.add_interact(bj_stool(i), 1.15, "Sit down at BLACKJACK", open.bind("blackjack", i), cond)


static func _seat(root: Node3D, pos: Vector3, yaw: float, px: float, view: Vector3, look: Vector3, text := "") -> Dictionary:
	var l := Art.label(root, text, pos, px, Ui.YELLOW, false)
	l.rotation.y = yaw
	return {"label": l, "view": [view, look]}


## The readouts that replace the old popup windows: each game draws on its machine.
static func _seats(root: Node3D, out: Dictionary) -> void:
	var slots: Array = []
	for p: Vector3 in SLOTS:
		slots.append(_seat(root, p + Vector3(0, 1.36, 0.56), 0.0, 0.0012, p + Vector3(0, 1.95, 2.3), p + Vector3(0, 1.72, 0), "INSERT REGRET"))
	var roul: Array = []
	for p: Vector3 in ROULETTE:
		var r := _seat(root, p + Vector3(0, 2.0, 0), 0.0, 0.006, p + Vector3(0, 2.6, 2.5), p + Vector3(0, 0.9, 0), "PLACE BETS")
		(r.label as Label3D).billboard = BaseMaterial3D.BILLBOARD_ENABLED
		roul.append(r)
	var bj: Array = []
	for i in BJ_SEATS:
		var c := bj_spot(i)
		var st := bj_stool(i)
		var b := _seat(root, c + Vector3(0, 0.62, 0), 0.0, 0.0044, st + Vector3(0, 2.25, 0) + (st - c).normalized() * 0.3, c.lerp(BJ_TABLE + Vector3(0, 1, 0.3), 0.3), "")
		(b.label as Label3D).billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bj.append(b)
	out.bj_head = Art.label(root, "", BJ_TABLE + Vector3(0, 2.4, 0.3), 0.007, Ui.YELLOW)
	var poker: Array = []
	for i in 2:
		var c := POKER + Vector3(-1.0 + i * 2.0, 0, 0)
		var pl := _seat(root, c + Vector3(0, 1.75, 0), 0.0, 0.0044, c + Vector3(0, 2.3, -2.7), c + Vector3(0, 0.95, -0.3), "")
		(pl.label as Label3D).billboard = BaseMaterial3D.BILLBOARD_ENABLED
		poker.append(pl)
	out.seats = {
		"slots": slots, "roulette": roul, "blackjack": bj, "poker": poker,
		"crash": [_seat(root, Vector3(51.72, 3.55, -12.1), -PI * 0.5, 0.011, Vector3(46.2, 2.7, -10.5), Vector3(51.8, 2.9, -10.5), "x1.00")],
		"wheel": [_seat(root, MINIWHEEL + Vector3(-0.2, 7.4, 0), -PI * 0.5, 0.009, Vector3(42.8, 3.8, 7.0), Vector3(49.8, 4.0, 7.0), "SPIN ME")],
		"ducks": [_seat(root, DUCKS + Vector3(-0.3, 2.9, 0), PI * 0.5, 0.008, Vector3(35.0, 3.6, 10.0), Vector3(30.4, 1.0, 10.0), "PLACE BETS")],
	}


## Everyone who lives here. Casino staff are added by casino_floor.
static func populate(npcs: Npcs) -> void:
	var f := 0.4
	npcs.add_still(SALOON + Vector3(-1, f + 0.95, -6.8), PI,  # on a crate: the bar is taller than he is
	 {"color": Color("#8d8aa0"), "hat": "top", "body": "robot", "holds": "glass"}, "wipe")
	npcs.add_still(SHOP + Vector3(0, 0, 2.6), 0.0, {"color": Color("#ff8a3d"), "hat": "bucket", "body": "cat"})
	npcs.add_still(Playground.BAR2 + Vector3(1.0, 0.3, 1.0), -0.7, {"color": Color("#ff5fa2"), "hat": "party", "body": "frog", "holds": "glass"}, "wipe")
	npcs.add_still(SALOON + Vector3(-9.8, f, -0.9), -PI * 0.5, {"color": Color("#4a4e69"), "hat": "top", "body": "wizard"}, "piano")  # the pianist
	npcs.add_still(HOTEL + Vector3(-6, f, 3.0), PI, {"color": Color("#c44569"), "hat": "none", "body": "kid", "holds": "paper"})  # hotel desk
	npcs.add_still(SHERIFF + Vector3(-4.8, f, 6.4), PI, {"color": Color("#2f8f8a"), "hat": "bucket", "body": "kid", "holds": "coffee"})  # the sheriff
	# upstairs at the saloon: still holding the hand he was dealt in 1887
	npcs.add_still(SALOON + Vector3(-5.4, 5.62, 7.4), 0.0, {"color": Color("#e8e0cc"), "hat": "top", "body": "robot", "holds": "card"})
	var loops := [
		[Vector3(-16, 0, -16), Vector3(16, 0, -16), Vector3(20, 0, 16), Vector3(-16, 0, 16)],
		[Vector3(20, 0, -14), Vector3(-20, 0, -14), Vector3(-22, 0, 10), Vector3(-6, 0, 20)],
		[Vector3(-3, 0, 20), Vector3(-3, 0, -18)],
		[Vector3(5, 0, 44), Vector3(4, 0, 62), Vector3(-10, 0, 58)],
		[Vector3(-20, 0, -18), Vector3(-30, 0, 2), Vector3(-34, 0, 18)],
	]
	var kinds := ["kid", "cat", "wizard", "frog", "robot"]
	var cols := [Color("#7ccf4e"), Color("#ffd23f"), Color("#3ec1ff"), Color("#8b5cf6"), Color("#ff8a3d")]
	var hats := ["top", "bucket", "none", "traffic", "party"]
	var holds := ["coffee", "paper", "cone", "balloon", "coffee"]
	for i in loops.size():
		npcs.add_walker(loops[i], {"color": cols[i], "hat": hats[i], "body": kinds[i], "holds": holds[i]})
	var o := Vector3(Playground.BEACH_DIR.x, 0, Playground.BEACH_DIR.y) * 98.0
	npcs.add_walker([o + Vector3(-8, Playground.height(o.x, o.z), 6), o + Vector3(10, Playground.height(o.x, o.z), -6)],
		{"color": Color("#f2efe9"), "hat": "party", "body": "banana", "holds": "cone"})
	var c := Playground.CARNIVAL
	npcs.add_walker([c + Vector3(-6, 0, 6), c + Vector3(8, 0, -6), c + Vector3(-10, 0, -10)],
		{"color": Color("#ff5fa2"), "hat": "party", "body": "cat", "holds": "balloon"})
	npcs.add_walker([c + Vector3(12, 0, 8), c + Vector3(-4, 0, 12)], {"color": Color("#3ec1ff"), "hat": "propeller", "body": "kid", "holds": "cone"})


static func casino_floor(root: Node3D, b: Batch, out: Dictionary) -> void:
	var reels: Array = []
	for i in SLOTS.size():
		reels.append((Kit.landmark(root, b, SLOT_MODELS[i % SLOT_MODELS.size()], SLOTS[i], 0.0) as Dictionary).dyn)
	out.slots = reels
	Kit.landmark(root, b, "crash_cabinet", CRASH, -90.0)
	out.prize_wheel = (Kit.landmark(root, b, "prize_wheel", MINIWHEEL, -90.0) as Dictionary).dyn.get("rotor")
	out.ducks = (Kit.landmark(root, b, "duck_track", DUCKS + Vector3(-0.3, 0, 0), -90.0) as Dictionary).dyn
	var wheels: Array = []
	for p: Vector3 in ROULETTE:
		wheels.append((Kit.landmark(root, b, "roulette_table", p, 90.0 if p.x < 41.0 else -90.0) as Dictionary).dyn)
	out.roulette = wheels
	Kit.landmark(root, b, "poker_table", POKER, 0.0)
	Kit.landmark(root, b, "blackjack_table", BJ_TABLE, 0.0)
	# stools + a dealer per table
	for i in BJ_SEATS:
		Dress.put(root, b, "kk_furniture_chair_stool", bj_stool(i) + (BJ_TABLE - bj_stool(i)).normalized() * 0.1, i * 30.0, 0.62, Dress.COL_NONE, true)
	# VIP couch + plants, and the Crash wall label
	Kit.landmark(root, b, "back_room", DEEDS + Vector3(0.6, 0, 0), 90.0)
	_seats(root, out)
	_wheel_labels(out.prize_wheel)
	var npcs := Npcs.new()
	npcs.name = "Npcs"
	npcs.game = root as WorldBase
	root.add_child(npcs)
	out.npcs = npcs
	npcs.add_still(DEEDS + Vector3(-0.2, 0, 0), PI * 0.5, {"color": Color("#7fbf6a"), "hat": "top", "body": "frog", "holds": "card"})
	Dress.put(root, b, "nature_pot_large", Vector3(29.8, 0, -8.8), 0.0, 1.5, Dress.COL_BOX, true)
	Dress.put(root, b, "nature_pot_large", Vector3(29.8, 0, 6.0), 0.0, 1.5, Dress.COL_BOX, true)
	# bottom right of the screen: the chart climbs from bottom left to top right
	Art.label(root, "CRASH", Vector3(51.72, 1.75, -8.4), 0.008, Ui.YELLOW, false).rotation.y = -PI * 0.5
	Art.label(root, "BLACKJACK", BJ_TABLE + Vector3(0, 3.1, 1.0), 0.009, Ui.YELLOW)
	Art.label(root, "POKER", POKER + Vector3(0, 2.8, 0), 0.008, Ui.YELLOW)
	var staff := [[POKER + Vector3(0, 0, 2.1), 0.0, "kid"], [BJ_TABLE + Vector3(0, 0, 1.5), 0.0, "cat"],
		[Vector3(38, 0, -10.0), PI, "robot"], [Vector3(45, 0, -10.0), PI, "frog"]]
	for d: Array in staff:
		npcs.add_still(d[0], d[1], {"color": Color("#f2efe9"), "hat": "none", "body": d[2], "holds": "card"}, "deal")
	# regulars: a full poker game, and one who never leaves the slots
	var regulars := [[POKER + Vector3(-3.0, 0, 0), PI * 0.5, "wizard", Color("#4a4e69")], [POKER + Vector3(3.0, 0, 0), -PI * 0.5, "robot", Color("#ff8a3d")],
		[SLOTS[4] + Vector3(0, 0, 1.3), PI, "frog", Color("#7ccf4e")]]
	for d: Array in regulars:
		npcs.add_still(d[0], d[1], {"color": d[3], "hat": "top", "body": d[2]})
	npcs.add_walker([Vector3(34, 0, -3), Vector3(47, 0, -3), Vector3(47, 0, 1.5), Vector3(34, 0, 1.5)],
		{"color": Color("#2a2030"), "hat": "top", "body": "kid", "holds": "tray"})
	npcs.add_walker([Vector3(42, 0, -15), Vector3(33, 0, -15), Vector3(33, 0, -4)], {"color": Color("#7a2336"), "hat": "none", "body": "wizard"})
	Art.label(root, "LIL' WHEEL", MINIWHEEL + Vector3(-1.2, 6.6, 0), 0.012, Ui.YELLOW)
	Art.label(root, "DUCK DERBY", DUCKS + Vector3(2.4, 2.2, 0), 0.012, Ui.YELLOW)
	Art.label(root, "ROULETTE", Vector3(41.5, 2.8, -7.5), 0.008, Ui.YELLOW)
	Art.label(root, "SLOTS", Vector3(35, 3.9, -18), 0.012, Ui.YELLOW)
	Art.label(root, "SLOTS", Vector3(46, 3.9, -18), 0.012, Ui.YELLOW)


## Prize names printed on the wheel itself, so it lands on something you can read.
static func _wheel_labels(rotor: Node3D) -> void:
	var seg := TAU / Casino.WHEEL_SEGMENTS.size()
	for i in Casino.WHEEL_SEGMENTS.size():
		var mid := seg * (i + 0.5)
		var l := Art.label(rotor, str(Casino.WHEEL_SEGMENTS[i].label), Vector3(sin(mid), cos(mid), 0) * 1.65 + Vector3(0, 0, 0.1), 0.0042, Color.WHITE, false)
		l.rotation.z = PI * 0.5 - mid


static func _store_and_hotel(root: Node3D, b: Batch) -> void:
	Art.label(root, "PERK SHOP", SHOP + Vector3(0, 3.1, 1.2), 0.014, Ui.YELLOW)
	for p: Vector3 in [Vector3(-23.6, 0.4, 24.6), Vector3(-21.8, 0.4, 24.8), Vector3(-11.2, 0.4, 24.6)]:
		Dress.put(root, b, "pirate_crate", p, p.x * 11.0, 0.72, Dress.COL_BOX, true)
	Dress.put(root, b, "pirate_barrel", Vector3(-9.8, 0.4, 24.6), 0.0, 0.72, Dress.COL_BOX, true)
	Dress.put(root, b, "kk_restaurant_crate_tomatoes", Vector3(-14.0, 1.75, 35.0), 10.0, 0.42, Dress.COL_NONE, true)
	Dress.put(root, b, "kk_restaurant_crate_potatoes", Vector3(-20.0, 1.75, 35.0), -14.0, 0.42, Dress.COL_NONE, true)
	# Wardrobe in the hotel lobby: paint, hats, body swap
	var base := Art.WOOD.darkened(0.2)
	Art.solid_box(root, Vector3(1.8, 0.5, 1.8), base, PAINT + Vector3(0, 0.25, 0.1))
	for i in 4:
		Art.part(root, Art.cyl(0.35, 0.3, 0.6, 8), Art.SWATCHES[i], PAINT + Vector3(-0.42 + (i % 2) * 0.84, 0.8, -0.32 + (i / 2) * 0.84))
	Art.solid_cyl(root, 0.1, 2.8, Art.WOOD, HATS + Vector3(0, 1.4, 0), -1.0, 6)
	for i in 3:
		var h := Art.build_hat(["party", "top", "chef"][i])
		h.position = HATS + Vector3(0, 2.0 + i * 0.4, 0) + Vector3(cos(i * 2.0), 0, sin(i * 2.0)) * 0.35
		root.add_child(h)
	Art.solid_box(root, Vector3(2.2, 3.2, 0.3), Color("#b388ff"), BODY + Vector3(0, 1.6, -1.1 + 0.9))
	Art.part(root, Art.box(Vector3(2.4, 0.3, 1.6)), Color("#8a5fd1"), BODY + Vector3(0, 3.3, 0.5))
	Art.label(root, "BODY SWAP", BODY + Vector3(0, 3.9, 0), 0.009)
	Art.label(root, "PAINT", PAINT + Vector3(0, 2.0, 0), 0.009)
	Art.label(root, "HATS", HATS + Vector3(0, 3.3, 0), 0.009)
	Dress.put(root, b, "kk_furniture_couch", Vector3(10.4, 0.4, 30.5), 90.0, 1.3, Dress.COL_BOX, true)
	Dress.put(root, b, "kk_furniture_lamp_standing", Vector3(10.2, 0.4, 28.2), 0.0, 1.3, Dress.COL_NONE, true)
	Dress.put(root, b, "kk_furniture_shelf_B_large_decorated", Vector3(8.2, 0.4, 38.8), 180.0, 1.2, Dress.COL_NONE, true)
	for x: float in [10.0, 14.0, 24.0, 28.0]:
		Dress.put(root, b, "kk_furniture_chair_A", Vector3(x, 0.4, 23.8), x * 7.0, 1.0, Dress.COL_NONE, true)


static func _jail(root: Node3D, b: Batch, out: Dictionary) -> void:
	# Hall of Fame board on the sheriff's porch (facing the square)
	Art.part(root, Art.box(Vector3(5.0, 3.0, 0.08)), Color("#3a2f2a"), FAME + Vector3(0, 0, -0.06))
	var fame := Art.label(root, "", FAME + Vector3(0, -0.2, 0.02), 0.0052, Color.WHITE, false)
	out.fame = fame
	Art.label(root, "HALL OF FAME (and shame)", FAME + Vector3(0, 1.8, 0.02), 0.0075, Art.GOLD, false)
	Art.label(root, "ADOPT A BOT", KENNEL + Vector3(-3.2, 2.4, -1.2), 0.009, Ui.YELLOW)
	Art.label(root, "RELEASE A BOT", KENNEL + Vector3(4.6, 2.4, -1.2), 0.009, Ui.YELLOW)
	Dress.put(root, b, "kk_furniture_chair_B_wood", KENNEL + Vector3(-5.0, 0, 4.9), 200.0, 1.0, Dress.COL_NONE, true)
	Dress.put(root, b, "kk_furniture_shelf_B_small_decorated", KENNEL + Vector3(7.5, 0, 7.5), 0.0, 1.1, Dress.COL_NONE, true)


## Wheel ruts, plank crossings, loose stones and a trough: the ground has a history.
static func _ground(root: Node3D, b: Batch) -> void:
	var rut := Color("#8f7a5c").srgb_to_linear()
	var strip := Art.box(Vector3(0.45, 0.03, 1.0))
	for sx: float in [-2.7, 2.7, -3.9, 3.9]:
		for i in 88:
			var z := -44.0 + i + sin(i * 0.3 + sx) * 0.2
			if z > -14.0 and z < 11.0:  # the plaza stone covers these
				continue
			b.add(strip, Transform3D(Basis.IDENTITY, Vector3(sx + sin(i * 0.17) * 0.25, 0.015, z)), true, rut)
	var plank := Art.box(Vector3(7.0, 0.05, 0.42))
	for z0: float in [-20.0, 21.4]:
		for i in 8:
			var t := Color("#a87a4c").darkened(float(i % 3) * 0.1).srgb_to_linear()
			b.add(plank, Transform3D(Basis(Vector3.UP, (i % 2) * 0.02), Vector3(0, 0.03, z0 + i * 0.46)), true, t)
	var stone := Art.cyl(0.28, 0.34, 0.1, 6)
	var cob := Color("#9c9288")
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in 110:  # cobbles around the wheel plaza
		var a := rng.randf() * TAU
		var r := rng.randf_range(11.4, 14.0)
		var s := rng.randf_range(0.8, 1.5)
		var c := cob.darkened(rng.randf() * 0.2).srgb_to_linear()
		b.add(stone, Transform3D(Basis(Vector3.UP, a).scaled(Vector3(s, 1, s)), Vector3(cos(a) * r, 0.05, -1.5 + sin(a) * r)), true, c)
	for i in 60:  # loose stones on the dirt
		var p := Vector3(rng.randf_range(-44, 44), 0.04, rng.randf_range(-44, 44))
		if maxf(absf(p.x), absf(p.z)) < 14.0:
			continue
		var s := rng.randf_range(0.3, 0.6)
		b.add(stone, Transform3D(Basis.IDENTITY.scaled(Vector3(s, 1, s)), p), true, cob.darkened(0.15).srgb_to_linear())
	Art.solid_box(root, Vector3(3.2, 0.9, 1.0), Color("#6e4326"), Vector3(-24, 0.45, -19))
	Art.part(root, Art.box(Vector3(2.9, 0.06, 0.74)), Color("#46a8c8"), Vector3(-24, 0.86, -19), Vector3.ONE, Vector3.ZERO, false, 0.1)
	Art.solid_box(root, Vector3(3.2, 0.9, 1.0), Color("#6e4326"), Vector3(24, 0.45, 19.6))
	Art.part(root, Art.box(Vector3(2.9, 0.06, 0.74)), Color("#46a8c8"), Vector3(24, 0.86, 19.6), Vector3.ONE, Vector3.ZERO, false, 0.1)


static func _streets(root: Node3D, b: Batch, props: PropSystem) -> void:
	_ground(root, b)
	# Bulb strings + bunting across Main Street and around the square
	var warm := [Color("#ffe6a8"), Color("#ffb45e")]
	Dress.bulbs(b, Vector3(-7.8, 8.6, -23.6), Vector3(7.5, 8.6, -23.6), 20, 1.6, warm)
	Dress.bulbs(b, Vector3(-8.2, 8.0, 23.0), Vector3(7.0, 8.0, 23.0), 20, 1.6, warm)
	Dress.bunting(b, Vector3(-8.2, 11.0, -23.6), Vector3(26.0, 9.0, -23.6), 26, 1.8)
	Dress.bunting(b, Vector3(-34.0, 10.5, -23.6), Vector3(-8.2, 11.0, 23.0), 34, 2.0)
	Dress.bulbs(b, Vector3(7.0, 8.0, 23.0), Vector3(28.0, 11.0, 16.0), 20, 1.4, warm)
	Dress.bulbs(b, Vector3(26.0, 9.0, -23.6), Vector3(28.0, 11.0, -13.0), 14, 1.2, warm)
	# Lamp posts along the sidewalks
	for p: Vector3 in [Vector3(-7.5, 0, -19), Vector3(7.5, 0, -19), Vector3(-7.5, 0, 20), Vector3(7.5, 0, 20),
			Vector3(-26, 0, -14), Vector3(-26, 0, 12), Vector3(26, 0, -16), Vector3(26, 0, 13)]:
		Playground.lamp(root, p)
	# Wagons, market stalls, hay and clutter: makes the square feel used
	Dress.put(root, b, "fantasytown_stall_red", Vector3(-22, 0, -13), 90.0, 2.4, Dress.COL_BOX)
	Dress.put(root, b, "fantasytown_stall_green", Vector3(-22, 0, -5), 90.0, 2.4, Dress.COL_BOX)
	Dress.put(root, b, "fantasytown_cart_high", Vector3(-25, 0, 14), 40.0, 2.0, Dress.COL_BOX)
	Dress.put(root, b, "fantasytown_cart", Vector3(-30.5, 0, -18), -30.0, 2.0, Dress.COL_BOX)
	Dress.put(root, b, "fantasytown_stall_bench", Vector3(-20, 0, 12), 90.0, 2.4, Dress.COL_NONE, true)
	for z: float in [-10.0, -9.2, 0.8]:
		Dress.put(root, b, "kk_city_box_A", Vector3(-20.2, 0, z), z * 30.0, 2.0, Dress.COL_NONE, true)
	for i in 5:
		Dress.put(root, b, "survival_fence", Vector3(-46.0, 0, -11.5 + i * 4.8), 90.0, 8.8, Dress.COL_BOX)
	for p: Vector3 in [Vector3(-33, 0, 12), Vector3(-45, 0, 22), Vector3(-30, 0, 30), Vector3(32, 0, -28),
			Vector3(42, 0, 28), Vector3(-44, 0, -24)]:
		Dress.put(root, b, "nature_cactus_tall", p, p.x * 9.0, 3.2, Dress.COL_BOX)
		Dress.put(root, b, "nature_cactus_short", p + Vector3(1.8, 0, 1.0), p.z * 9.0, 2.6, Dress.COL_NONE, true)
	# Loose props you can actually grab, stack and throw
	for p: Vector3 in [Vector3(-16, 0.6, -18), Vector3(-15, 0.6, -19), Vector3(16, 0.6, 19), Vector3(21, 0.6, 18)]:
		props.spawn("barrel", p)
	for p: Vector3 in [Vector3(-30, 0.5, 10), Vector3(-30, 1.5, 10), Vector3(-28.9, 0.5, 10.2), Vector3(12, 0.5, -18)]:
		props.spawn("crate", p)
	for i in 4:
		props.spawn("stool", Vector3(-6 + i * 2.0, 0.9, -28.5 + 2.0 * (i % 2)))
	for i in 3:
		props.spawn("keg", SALOON + Vector3(9.0 + i * 0.9, 0.95, 12.6))
