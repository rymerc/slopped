class_name LobbyBuilder
extends RefCounted
## Static geometry for the "Slop Lounge" lobby. Everything is primitives.
##   North: bar + VIP throne (leader only)     West: wardrobe
##   East: casino machines                     South: perk shop, kennel, toilet, trampoline
##   Centre: the Big Wheel + START button

const HALF := 32.0

# Stations (world positions). Lobby wires interactions to these.
const START_BTN := Vector3(0, 0, 3)
const BAR := Vector3(0, 0, -21.5)
const THRONE := Vector3(13, 0.8, -26)
const VIP_GATE := Vector3(13, 0, -21.5)
const PAINT := Vector3(-27, 0, -6)
const HATS := Vector3(-27, 0, 0)
const BODY := Vector3(-27, 0, 6)
const SLOTS := Vector3(27, 0, -9)
const CRASH := Vector3(27, 0, -3)
const MINIWHEEL := Vector3(27, 0, 3)
const DUCKS := Vector3(27, 0, 9)
const SHOP := Vector3(-10, 0, 25)
const KENNEL := Vector3(10, 0, 25)
const TOILET := Vector3(-26, 0, 26)
const TRAMPOLINE := Vector3(0, 0, 18)
const FAME := Vector3(24, 0, 28)


static func build(root: Node3D) -> Dictionary:
	var out := {}
	# Floor + rugs
	Art.solid_box(root, Vector3(HALF * 2, 1, HALF * 2), Color("#6b4c8a"), Vector3(0, -0.5, 0), false)
	_rug(root, Vector3(0, 0, 0), Vector2(18, 18), Color("#ffd23f"))
	_rug(root, Vector3(0, 0, -24), Vector2(34, 12), Color("#c44569"))
	_rug(root, Vector3(-26, 0, 0), Vector2(10, 20), Color("#3ec1ff"))
	_rug(root, Vector3(26, 0, 0), Vector2(10, 24), Color("#2e8b57"))
	_rug(root, Vector3(0, 0, 25), Vector2(40, 10), Color("#ff7a3d"))
	# Walls
	var wall := Color("#4a3566")
	for s: float in [-1.0, 1.0]:
		Art.solid_box(root, Vector3(HALF * 2, 6, 1), wall, Vector3(0, 3, HALF * s))
		Art.solid_box(root, Vector3(1, 6, HALF * 2), wall, Vector3(HALF * s, 3, 0))
	Art.label(root, "THE SLOP LOUNGE", Vector3(0, 7.5, -HALF + 0.6), 0.04, Ui.ACCENT, false)
	# Disco ball
	var disco := Node3D.new()
	disco.name = "Disco"
	disco.position = Vector3(0, 13, 6)
	root.add_child(disco)
	Art.part(disco, Art.sphere(1.0, 8), Color("#d0d8ff"), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, true, 0.6)
	out.disco = disco
	for i in 3:
		var l := OmniLight3D.new()
		l.light_color = [Color("#ff5fa2"), Color("#3ec1ff"), Color("#ffd23f")][i]
		l.light_energy = 1.5
		l.omni_range = 14.0
		l.position = Vector3(cos(i * 2.1) * 4, -1.5, sin(i * 2.1) * 4)
		disco.add_child(l)

	# Centre: start button podium
	Art.solid_cyl(root, 1.4, 1.0, Color("#4a4e69"), START_BTN + Vector3(0, 0.5, 0), -1.0, 12)
	var btn := Art.part(root, Art.cyl(0.9, 1.0, 0.35, 12), Color("#e63946"), START_BTN + Vector3(0, 1.15, 0), Vector3.ONE, Vector3.ZERO, true, 0.35)
	out.start_button = btn
	Art.label(root, "START", START_BTN + Vector3(0, 2.2, 0), 0.012, Color.WHITE)

	_build_bar(root, out)
	_build_wardrobe(root)
	_build_casino(root)
	_build_south(root, out)
	for p: Vector3 in [Vector3(-14, 0, -14), Vector3(14, 0, 14), Vector3(-14, 0, 14), Vector3(14, 0, -10)]:
		_plant(root, p)
	return out


static func _rug(root: Node3D, pos: Vector3, size: Vector2, color: Color) -> void:
	Art.part(root, Art.box(Vector3(size.x, 0.04, size.y)), color, pos + Vector3(0, 0.02, 0), Vector3.ONE, Vector3.ZERO, false)


static func _plant(root: Node3D, pos: Vector3) -> void:
	var b := Art.solid_cyl(root, 0.6, 1.0, Color("#c96f4a"), pos + Vector3(0, 0.5, 0), 0.75, 8)
	Art.part(b, Art.sphere(1.0, 7), Color("#5fbf5a"), Vector3(0, 1.3, 0))
	Art.part(b, Art.sphere(0.7, 7), Color("#8ce36b"), Vector3(0.4, 2.0, 0.2))


static func _build_bar(root: Node3D, out: Dictionary) -> void:
	Art.solid_box(root, Vector3(16, 1.2, 1.4), Color("#7a4b2a"), BAR + Vector3(0, 0.6, -1.5))
	Art.part(root, Art.box(Vector3(16.4, 0.15, 1.8)), Color("#c98b4a"), BAR + Vector3(0, 1.27, -1.5))
	Art.solid_box(root, Vector3(16, 4, 0.6), Color("#5a3a20"), BAR + Vector3(0, 2, -6))
	for i in 14:
		var c := Color.from_hsv(randf(), 0.7, 0.9)
		Art.part(root, Art.cyl(0.12, 0.16, 0.6, 6), c, BAR + Vector3(-6.5 + i, 2.4, -5.5), Vector3.ONE, Vector3.ZERO, true, 0.5)
	for i in 6:
		var p := BAR + Vector3(-6.0 + i * 2.4, 0, 0.4)
		Art.solid_cyl(root, 0.4, 0.9, Color("#e63946"), p + Vector3(0, 0.45, 0), -1.0, 8)
	# Bartender (static, never moves, judges you)
	var bt: Node3D = Art.build_character({"color": Color("#8d8aa0"), "hat": "top", "body": "box"}).root
	bt.position = BAR + Vector3(0, 0, -3.5)
	bt.rotation.y = PI
	root.add_child(bt)
	Art.label(root, "MYSTERY SLOP BAR", BAR + Vector3(0, 4.6, -5.6), 0.025, Ui.YELLOW, false)
	# VIP: raised platform + throne + velvet barrier that only the leader can pass
	Art.solid_box(root, Vector3(7, 0.8, 6), Color("#ffcc33"), THRONE + Vector3(0, -0.4, 0))
	Art.solid_box(root, Vector3(1.6, 0.8, 1.4), Color("#c44569"), THRONE + Vector3(0, 0.4, -1))
	Art.solid_box(root, Vector3(1.6, 2.6, 0.4), Color("#c44569"), THRONE + Vector3(0, 1.3, -1.8))
	Art.part(root, Art.cyl(0.0, 0.25, 0.5, 5), Art.GOLD, THRONE + Vector3(0, 2.9, -1.8))
	var gate := Art.solid_box(root, Vector3(7, 3, 0.3), Color("#e63946"), VIP_GATE + Vector3(0, 1.5, 0), false)
	(gate.get_child(0) as MeshInstance3D).transparency = 0.6
	out.vip_gate = gate.get_child(1) as CollisionShape3D
	Art.label(root, "VIP: LEADER ONLY", VIP_GATE + Vector3(0, 3.6, 0), 0.015, Art.GOLD)


static func _build_wardrobe(root: Node3D) -> void:
	Art.solid_box(root, Vector3(0.6, 5, 14), Color("#d8e2ff"), Vector3(-31, 2.5, 0))
	Art.part(root, Art.box(Vector3(0.2, 4, 12)), Color("#aee6ff"), Vector3(-30.6, 2.5, 0), Vector3.ONE, Vector3.ZERO, false, 0.4)
	var wl := Art.label(root, "WARDROBE", Vector3(-30, 5.6, 0), 0.025, Ui.YELLOW, false)
	wl.rotation.y = PI * 0.5
	# Paint buckets
	for i in 4:
		Art.part(root, Art.cyl(0.35, 0.3, 0.6, 8), Art.SWATCHES[i], PAINT + Vector3(-0.6 + (i % 2) * 1.2, 0.3, -0.6 + (i / 2) * 1.2))
	# Hat rack
	Art.solid_cyl(root, 0.1, 2.8, Art.WOOD, HATS + Vector3(0, 1.4, 0), -1.0, 6)
	for i in 3:
		var h := Art.build_hat(["party", "top", "chef"][i])
		h.position = HATS + Vector3(0, 2.0 + i * 0.4, 0) + Vector3(cos(i * 2.0), 0, sin(i * 2.0)) * 0.35
		root.add_child(h)
	# Body swap booth
	Art.solid_box(root, Vector3(2.2, 3.2, 0.3), Color("#b388ff"), BODY + Vector3(0, 1.6, -1.1))
	Art.solid_box(root, Vector3(2.2, 3.2, 0.3), Color("#b388ff"), BODY + Vector3(0, 1.6, 1.1))
	Art.part(root, Art.box(Vector3(2.4, 0.3, 2.6)), Color("#8a5fd1"), BODY + Vector3(0, 3.3, 0))
	Art.label(root, "BODY SWAP", BODY + Vector3(0, 4.0, 0), 0.012)


static func _build_casino(root: Node3D) -> void:
	var cl := Art.label(root, "CASINO", Vector3(30.5, 5.6, 0), 0.03, Ui.ACCENT, false)
	cl.rotation.y = -PI * 0.5
	var machines := [[SLOTS, "SLOTS", Color("#e63946")], [CRASH, "CRASH", Color("#ff7a3d")],
		[MINIWHEEL, "WHEEL", Color("#b388ff")], [DUCKS, "DUCK RACE", Color("#ffd23f")]]
	for m: Array in machines:
		var p: Vector3 = m[0]
		var c: Color = m[2]
		Art.solid_box(root, Vector3(1.4, 2.6, 2.2), c, p + Vector3(1.2, 1.3, 0))
		Art.part(root, Art.box(Vector3(0.1, 1.0, 1.6)), Color("#1b1b2f"), p + Vector3(0.45, 1.8, 0), Vector3.ONE, Vector3.ZERO, false, 0.0)
		Art.part(root, Art.box(Vector3(0.12, 0.8, 1.4)), c.lightened(0.4), p + Vector3(0.42, 1.8, 0), Vector3.ONE, Vector3.ZERO, false, 0.8)
		Art.part(root, Art.sphere(0.25, 8), c.lightened(0.3), p + Vector3(1.2, 2.9, 0), Vector3.ONE, Vector3.ZERO, true, 1.0)
		Art.label(root, str(m[1]), p + Vector3(0.5, 3.6, 0), 0.012)
	# Rubber duck mascot
	var duck := Node3D.new()
	duck.position = DUCKS + Vector3(-1.5, 0, 2.5)
	root.add_child(duck)
	Art.part(duck, Art.sphere(0.7, 8), Ui.YELLOW, Vector3(0, 0.6, 0), Vector3(1.2, 0.9, 1))
	Art.part(duck, Art.sphere(0.45, 8), Ui.YELLOW, Vector3(0, 1.4, -0.4))
	Art.part(duck, Art.box(Vector3(0.3, 0.1, 0.35)), Color("#ff7a3d"), Vector3(0, 1.35, -0.85))


static func _build_south(root: Node3D, out: Dictionary) -> void:
	# Perk shop stall
	Art.solid_box(root, Vector3(6, 1.2, 1.2), Color("#3ec1ff"), SHOP + Vector3(0, 0.6, 1.2))
	for sx: float in [-1.0, 1.0]:
		Art.solid_cyl(root, 0.12, 3.4, Art.WOOD, SHOP + Vector3(2.9 * sx, 1.7, 1.2), -1.0, 6)
	for i in 6:
		var c := Color("#ff5fa2") if i % 2 == 0 else Color.WHITE
		Art.part(root, Art.box(Vector3(1.0, 0.15, 2.2)), c, SHOP + Vector3(-2.5 + i, 3.45, 1.0), Vector3.ONE, Vector3(-15, 0, 0))
	Art.label(root, "PERK SHOP", SHOP + Vector3(0, 4.3, 1.0), 0.02, Ui.YELLOW)
	var keeper: Node3D = Art.build_character({"color": Color("#8ce36b"), "hat": "bucket", "body": "pear"}).root
	keeper.position = SHOP + Vector3(0, 0, 2.6)
	root.add_child(keeper)
	# Bot kennel (doghouse)
	Art.solid_box(root, Vector3(3, 2, 3), Color("#c96f4a"), KENNEL + Vector3(0, 1, 1.5))
	Art.part(root, Art.box(Vector3(2.4, 0.2, 3.4)), Color("#e63946"), KENNEL + Vector3(-0.8, 2.4, 1.5), Vector3.ONE, Vector3(0, 0, 35))
	Art.part(root, Art.box(Vector3(2.4, 0.2, 3.4)), Color("#e63946"), KENNEL + Vector3(0.8, 2.4, 1.5), Vector3.ONE, Vector3(0, 0, -35))
	Art.part(root, Art.box(Vector3(1.0, 1.2, 0.1)), Art.INK, KENNEL + Vector3(0, 0.6, -0.02), Vector3.ONE, Vector3.ZERO, false)
	Art.label(root, "BOT KENNEL", KENNEL + Vector3(0, 3.6, 0.5), 0.015)
	# Toilet teleporter
	Art.solid_box(root, Vector3(1.0, 0.8, 1.2), Color.WHITE, TOILET + Vector3(0, 0.4, 0))
	Art.part(root, Art.cyl(0.55, 0.45, 0.2, 10), Color.WHITE, TOILET + Vector3(0, 0.9, -0.2))
	Art.part(root, Art.box(Vector3(1.0, 1.2, 0.35)), Color.WHITE, TOILET + Vector3(0, 1.2, 0.6))
	Art.label(root, "FLUSH", TOILET + Vector3(0, 2.4, 0), 0.012)
	# Trampoline
	Art.solid_cyl(root, 2.2, 0.5, Color("#1b1b2f"), TRAMPOLINE + Vector3(0, 0.25, 0), -1.0, 14)
	Art.part(root, Art.cyl(2.0, 2.0, 0.06, 14), Color("#3ec1ff"), TRAMPOLINE + Vector3(0, 0.52, 0), Vector3.ONE, Vector3.ZERO, false, 0.3)
	# Hall of fame board
	Art.solid_box(root, Vector3(7, 5, 0.4), Color("#1b1b2f"), FAME + Vector3(0, 3, 1.5))
	var fame := Art.label(root, "", FAME + Vector3(0, 3, 1.2), 0.008, Color.WHITE, false)
	fame.rotation.y = PI
	out.fame = fame
	var fl := Art.label(root, "HALL OF FAME (and shame)", FAME + Vector3(0, 6, 1.2), 0.012, Art.GOLD, false)
	fl.rotation.y = PI
