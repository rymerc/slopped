class_name Chars
extends RefCounted
## Chunky low-poly characters (big blocky head, dot eyes, stubby limbs) in the
## style of the concept sheet: kid, frog suit, cat, robot, wizard, banana.
##
## Every costume shares ONE rig so animation + ragdoll work for all of them:
##   Visual(root) > pivot > leg_l, leg_r         (hips at y 0.42)
##                        > torso > arm_l, arm_r (shoulders) > head (neck)
## Limb nodes sit exactly on their joints; meshes hang off them. Origin at the
## feet, facing -Z, ~1.6 m tall at size 1.

const KINDS := ["kid", "frog", "cat", "robot", "wizard", "banana"]
## Player level needed to wear each costume (progression unlocks).
const UNLOCK := {"kid": 1, "frog": 1, "cat": 2, "robot": 3, "wizard": 4, "banana": 5}
const LABELS := {"kid": "Kid", "frog": "Frog Suit", "cat": "Cat", "robot": "Robot",
	"wizard": "Wizard", "banana": "Banana"}

const HIP_Y := 0.42
const HIP_X := 0.12
const SHOULDER := Vector3(0.31, 0.44, 0.0)
const NECK_Y := 0.5
const EYE := Vector3(0.13, 0.3, -0.29)


static func unlocked(kind: String, level: int) -> bool:
	return level >= int(UNLOCK.get(kind, 99))


static func build(look: Dictionary) -> Dictionary:
	var kind := str(look.get("body", "kid"))
	if not KINDS.has(kind):
		kind = "kid"
	var c: Color = look.get("color", Art.P_ORANGE)
	var root := Node3D.new()
	root.name = "Visual"
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)
	var torso := _joint(pivot, "Torso", Vector3(0, HIP_Y, 0))
	var head := _joint(torso, "Head", Vector3(0, NECK_Y, 0))
	var arm_l := _joint(torso, "ArmL", Vector3(-SHOULDER.x, SHOULDER.y, 0))
	var arm_r := _joint(torso, "ArmR", Vector3(SHOULDER.x, SHOULDER.y, 0))
	var leg_l := _joint(pivot, "LegL", Vector3(-HIP_X, HIP_Y, 0))
	var leg_r := _joint(pivot, "LegR", Vector3(HIP_X, HIP_Y, 0))
	var p := {"root": root, "pivot": pivot, "torso": torso, "head": head,
		"arms": [arm_l, arm_r], "legs": [leg_l, leg_r], "kind": kind, "tail": null,
		"eyes": [], "hat": null, "color": c}

	match kind:
		"frog": _frog(p, c)
		"cat": _cat(p, c)
		"robot": _robot(p, c)
		"wizard": _wizard(p, c)
		"banana": _banana(p)
		_: _kid(p, c)

	var hat_kind := str(look.get("hat", "none"))
	if hat_kind == "none" and kind == "wizard":
		hat_kind = "wizard"
	var hat := build_hat(hat_kind) if hat_kind == "wizard" else Art.build_hat(hat_kind)
	if hat:
		hat.position = Vector3(0, 0.58 if kind != "banana" else 0.78, 0.02)
		head.add_child(hat)
		p.hat = hat
	var rest := {}
	for n: Node3D in [pivot, torso, head, arm_l, arm_r, leg_l, leg_r]:
		rest[n.name] = n.transform
	p.rest = rest
	p.limbs = {"torso": torso, "head": head, "arm_l": arm_l, "arm_r": arm_r, "leg_l": leg_l, "leg_r": leg_r}
	return p


static func _joint(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = n
	j.position = pos
	parent.add_child(j)
	return j


# --- shared pieces -----------------------------------------------------------

static func _limbs(p: Dictionary, sleeve: Color, hand: Color, pants: Color, shoe: Color) -> void:
	for a: Node3D in p.arms:
		Art.part(a, Art.bbox(Vector3(0.15, 0.36, 0.16), 0.3), sleeve, Vector3(0, -0.16, 0))
		Art.part(a, Art.bbox(Vector3(0.13, 0.12, 0.13), 0.3), hand, Vector3(0, -0.38, 0))
	for l: Node3D in p.legs:
		Art.part(l, Art.bbox(Vector3(0.17, 0.34, 0.19), 0.25), pants, Vector3(0, -0.17, 0))
		Art.part(l, Art.bbox(Vector3(0.19, 0.1, 0.27), 0.35), shoe, Vector3(0, -0.37, -0.03))


static func _dot_eyes(p: Dictionary, z := EYE.z, y := EYE.y, color := Art.INK) -> void:
	var head: Node3D = p.head
	var eyes: Array = []
	for sx: float in [-1.0, 1.0]:
		var e := Node3D.new()
		e.name = "EyeL" if sx < 0.0 else "EyeR"
		e.position = Vector3(EYE.x * sx, y, z)
		head.add_child(e)
		var m := Art.part(e, Art.bbox(Vector3(0.075, 0.14, 0.04), 0.4), color)
		m.name = "Pupil"
		eyes.append(e)
	p.eyes = eyes


static func _smile(head: Node3D, z: float, y := 0.15, color := Color("#8a4a3a")) -> void:
	Art.part(head, Art.box(Vector3(0.1, 0.025, 0.02)), color, Vector3(0, y, z))
	Art.part(head, Art.box(Vector3(0.04, 0.025, 0.02)), color, Vector3(-0.065, y + 0.015, z), Vector3.ONE, Vector3(0, 0, -30))
	Art.part(head, Art.box(Vector3(0.04, 0.025, 0.02)), color, Vector3(0.065, y + 0.015, z), Vector3.ONE, Vector3(0, 0, 30))


# --- costumes ----------------------------------------------------------------

static func _kid(p: Dictionary, c: Color) -> void:
	var torso: Node3D = p.torso
	var head: Node3D = p.head
	Art.part(torso, Art.bbox(Vector3(0.5, 0.5, 0.34), 0.3), c, Vector3(0, 0.24, 0))
	Art.part(head, Art.bbox(Vector3(0.62, 0.56, 0.54), 0.3), Art.SKIN, Vector3(0, 0.29, 0))
	# hair cap
	Art.part(head, Art.bbox(Vector3(0.66, 0.2, 0.58), 0.4), Color("#6b4230"), Vector3(0, 0.53, 0.02))
	Art.part(head, Art.bbox(Vector3(0.66, 0.36, 0.2), 0.4), Color("#6b4230"), Vector3(0, 0.38, 0.2))
	_dot_eyes(p)
	_smile(head, -0.275)
	_limbs(p, c, Art.SKIN, Color("#4a5a8a"), Art.SHOE)


static func _frog(p: Dictionary, c: Color) -> void:
	var torso: Node3D = p.torso
	var head: Node3D = p.head
	Art.part(torso, Art.bbox(Vector3(0.52, 0.52, 0.36), 0.35), c, Vector3(0, 0.24, 0))
	Art.part(torso, Art.bbox(Vector3(0.34, 0.36, 0.06), 0.4), Color("#efd9a8"), Vector3(0, 0.22, -0.17))
	# hood around a little face
	Art.part(head, Art.bbox(Vector3(0.72, 0.64, 0.6), 0.35), c, Vector3(0, 0.3, 0.03))
	Art.part(head, Art.bbox(Vector3(0.48, 0.42, 0.06), 0.4), Art.SKIN, Vector3(0, 0.27, -0.27))
	for sx: float in [-1.0, 1.0]:
		Art.part(head, Art.sphere(0.14, 7), c, Vector3(0.18 * sx, 0.64, -0.06))
		Art.part(head, Art.sphere(0.1, 7), Color.WHITE, Vector3(0.18 * sx, 0.66, -0.14))
		Art.part(head, Art.sphere(0.05, 5), Art.INK, Vector3(0.18 * sx, 0.66, -0.23))
	_dot_eyes(p, -0.305, 0.29)
	_smile(head, -0.305, 0.16)
	_limbs(p, c, c, c, Art.SHOE)


static func _cat(p: Dictionary, c: Color) -> void:
	var torso: Node3D = p.torso
	var head: Node3D = p.head
	var stripe := c.darkened(0.2)
	Art.part(torso, Art.bbox(Vector3(0.5, 0.5, 0.34), 0.3), c, Vector3(0, 0.24, 0))
	Art.part(torso, Art.bbox(Vector3(0.3, 0.34, 0.05), 0.4), Art.P_CREAM, Vector3(0, 0.2, -0.165))
	for i in 2:
		Art.part(torso, Art.box(Vector3(0.06, 0.04, 0.36)), stripe, Vector3(0.26, 0.12 + i * 0.12, 0))
	Art.part(head, Art.bbox(Vector3(0.64, 0.56, 0.54), 0.3), c, Vector3(0, 0.29, 0))
	Art.part(head, Art.bbox(Vector3(0.26, 0.16, 0.06), 0.4), Art.P_CREAM, Vector3(0, 0.14, -0.27))
	for sx: float in [-1.0, 1.0]:
		Art.part(head, Art.prism(Vector3(0.22, 0.22, 0.12)), c, Vector3(0.19 * sx, 0.66, 0.02))
		Art.part(head, Art.prism(Vector3(0.12, 0.13, 0.04)), Color("#f7a1b5"), Vector3(0.19 * sx, 0.64, -0.04))
		for i in 2:
			Art.part(head, Art.box(Vector3(0.16, 0.012, 0.01)), Art.INK, Vector3(0.24 * sx, 0.15 + i * 0.04, -0.285),
				Vector3.ONE, Vector3(0, 0, (8.0 - i * 16.0) * sx))
	Art.part(head, Art.prism(Vector3(0.06, 0.045, 0.03)), Color("#e8788f"), Vector3(0, 0.19, -0.3), Vector3.ONE, Vector3(0, 0, 180))
	_dot_eyes(p)
	# scarf (wraps the neck, one tail hanging down the front)
	Art.part(torso, Art.bbox(Vector3(0.56, 0.11, 0.4), 0.3), Art.P_RED, Vector3(0, 0.5, 0))
	Art.part(torso, Art.bbox(Vector3(0.11, 0.3, 0.05), 0.3), Art.P_RED, Vector3(0.12, 0.33, -0.2))
	# tail: three segments curling up behind
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.06, 0.17)
	torso.add_child(tail)
	var seg := tail
	for i in 3:
		var s := Node3D.new()
		s.position = Vector3(0, 0, 0.0 if i == 0 else 0.17)
		s.rotation_degrees.x = 25.0
		seg.add_child(s)
		Art.part(s, Art.bbox(Vector3(0.09, 0.09, 0.19), 0.3), stripe if i == 2 else c, Vector3(0, 0, 0.08))
		seg = s
	p.tail = tail
	_limbs(p, c, c, c, c.darkened(0.15))


static func _robot(p: Dictionary, c: Color) -> void:
	var torso: Node3D = p.torso
	var head: Node3D = p.head
	var metal := Art.P_STEEL
	var joint := Color("#4a4e5e")
	var glow := c.lightened(0.25) if c.get_luminance() < 0.75 else Art.P_BLUE
	var body := Art.part(torso, Art.bbox(Vector3(0.5, 0.48, 0.34), 0.15), metal, Vector3(0, 0.25, 0))
	body.material_override = Art.mat(metal, false, 0.0, 0.8)
	Art.part(torso, Art.bbox(Vector3(0.22, 0.08, 0.04), 0.3), glow, Vector3(0, 0.28, -0.17), Vector3.ONE, Vector3.ZERO, false, 1.6)
	var h := Art.part(head, Art.bbox(Vector3(0.66, 0.54, 0.54), 0.15), metal, Vector3(0, 0.29, 0))
	h.material_override = Art.mat(metal, false, 0.0, 0.8)
	Art.part(head, Art.bbox(Vector3(0.52, 0.38, 0.04), 0.2), Color("#1d2030"), Vector3(0, 0.29, -0.27))
	for sx: float in [-1.0, 1.0]:
		Art.part(head, Art.bbox(Vector3(0.06, 0.18, 0.16), 0.3), joint, Vector3(0.35 * sx, 0.29, 0))
	Art.part(head, Art.cyl(0.02, 0.02, 0.3, 5), Art.INK, Vector3(0, 0.7, 0))
	Art.part(head, Art.sphere(0.06, 6), Art.P_RED, Vector3(0, 0.87, 0), Vector3.ONE, Vector3.ZERO, false, 0.8)
	# ^ ^ eyes, glowing
	var eyes: Array = []
	for sx: float in [-1.0, 1.0]:
		var e := Node3D.new()
		e.name = "EyeL" if sx < 0.0 else "EyeR"
		e.position = Vector3(EYE.x * sx, 0.32, -0.295)
		head.add_child(e)
		for k: float in [-1.0, 1.0]:
			var m := Art.part(e, Art.box(Vector3(0.09, 0.03, 0.02)), glow, Vector3(0.03 * k, 0.0, 0), Vector3.ONE,
				Vector3(0, 0, -40.0 * k), false, 2.0)
			m.name = "Pupil"
		eyes.append(e)
	p.eyes = eyes
	for a: Node3D in p.arms:
		Art.part(a, Art.bbox(Vector3(0.12, 0.12, 0.12), 0.3), joint, Vector3(0, -0.04, 0))
		Art.part(a, Art.bbox(Vector3(0.15, 0.24, 0.16), 0.15), metal, Vector3(0, -0.2, 0))
		Art.part(a, Art.bbox(Vector3(0.14, 0.12, 0.14), 0.3), joint, Vector3(0, -0.38, 0))
	for l: Node3D in p.legs:
		Art.part(l, Art.bbox(Vector3(0.12, 0.16, 0.12), 0.3), joint, Vector3(0, -0.08, 0))
		Art.part(l, Art.bbox(Vector3(0.18, 0.2, 0.2), 0.15), metal, Vector3(0, -0.24, 0))
		Art.part(l, Art.bbox(Vector3(0.2, 0.1, 0.27), 0.3), joint, Vector3(0, -0.37, -0.03))


static func _wizard(p: Dictionary, c: Color) -> void:
	var torso: Node3D = p.torso
	var head: Node3D = p.head
	# robe flares down over the hips
	Art.part(torso, Art.cyl(0.25, 0.36, 0.72, 7), c, Vector3(0, 0.14, 0))
	Art.part(torso, Art.cyl(0.27, 0.27, 0.07, 7), Color("#6b4226"), Vector3(0, 0.12, 0))
	Art.part(torso, Art.box(Vector3(0.12, 0.09, 0.03)), Art.GOLD, Vector3(0, 0.12, -0.28), Vector3.ONE, Vector3.ZERO, false, 0.2)
	Art.part(head, Art.bbox(Vector3(0.6, 0.54, 0.52), 0.3), Art.SKIN, Vector3(0, 0.29, 0))
	var grey := Color("#d9d6de")
	for sx: float in [-1.0, 1.0]:
		Art.part(head, Art.bbox(Vector3(0.1, 0.3, 0.4), 0.4), grey, Vector3(0.3 * sx, 0.24, 0.06))
	Art.part(head, Art.prism(Vector3(0.42, 0.42, 0.14)), Color.WHITE, Vector3(0, -0.02, -0.27), Vector3.ONE, Vector3(0, 0, 180))
	Art.part(head, Art.bbox(Vector3(0.36, 0.06, 0.06), 0.3), grey, Vector3(0, 0.2, -0.28))
	_dot_eyes(p, -0.275, 0.33)
	_limbs(p, c, Art.SKIN, c.darkened(0.25), Art.SHOE)
	# staff in the right hand, crystal on top
	var staff := Node3D.new()
	staff.name = "Staff"
	staff.position = Vector3(0, -0.38, -0.05)
	(p.arms[1] as Node3D).add_child(staff)
	Art.part(staff, Art.cyl(0.035, 0.04, 1.4, 5), Color("#7a4a2a"), Vector3(0, 0.25, 0))
	Art.part(staff, Art.sphere(0.11, 4), Color("#5fd8ff"), Vector3(0, 1.02, 0), Vector3(0.8, 1.3, 0.8), Vector3.ZERO,
		false, 1.2).material_override = Art.mat(Color("#5fd8ff"), false, 1.2, 1.0)


static func _banana(p: Dictionary) -> void:
	var torso: Node3D = p.torso
	var head: Node3D = p.head
	var y := Color("#ffd23f")
	Art.part(torso, Art.cyl(0.26, 0.2, 0.55, 7), y, Vector3(0, 0.22, 0.02), Vector3.ONE, Vector3(-8, 0, 0))
	Art.part(torso, Art.cyl(0.2, 0.08, 0.2, 7), y.darkened(0.08), Vector3(0, -0.12, 0.06), Vector3.ONE, Vector3(-15, 0, 0))
	Art.part(torso, Art.cyl(0.05, 0.05, 0.08, 5), Color("#5a3a22"), Vector3(0, -0.24, 0.08))
	Art.part(head, Art.cyl(0.24, 0.26, 0.5, 7), y, Vector3(0, 0.22, 0.0), Vector3.ONE, Vector3(6, 0, 0))
	Art.part(head, Art.cyl(0.1, 0.23, 0.32, 7), y.lightened(0.05), Vector3(0, 0.6, 0.05), Vector3.ONE, Vector3(18, 0, 0))
	Art.part(head, Art.cyl(0.05, 0.07, 0.16, 5), Color("#6b4226"), Vector3(0, 0.82, 0.1), Vector3.ONE, Vector3(28, 0, 0))
	# shades: the eyes live behind the lenses (giant-hunt hit points stay valid)
	_dot_eyes(p, -0.25, 0.3, Color("#1a1420"))
	Art.part(head, Art.box(Vector3(0.5, 0.04, 0.04)), Color("#1a1420"), Vector3(0, 0.36, -0.26))
	for sx: float in [-1.0, 1.0]:
		Art.part(head, Art.bbox(Vector3(0.2, 0.13, 0.04), 0.3), Color("#1a1420"), Vector3(0.12 * sx, 0.3, -0.265),
			Vector3.ONE, Vector3.ZERO, false, 0.0).material_override = Art.mat(Color("#1a1420"), false, 0.0, 1.0)
	_smile(head, -0.26, 0.12, Color("#5a3a22"))
	var limb := Color("#2a2430")
	_limbs(p, limb, limb, limb, limb)


## Wizard's own pointy hat (used when the hat slot is "none").
static func build_hat(kind: String) -> Node3D:
	if kind != "wizard":
		return Art.build_hat(kind)
	var h := Node3D.new()
	var col := Color("#6a3fc9")
	Art.part(h, Art.cyl(0.44, 0.44, 0.05, 8), col, Vector3(0, 0.0, 0))
	Art.part(h, Art.cyl(0.18, 0.3, 0.4, 7), col, Vector3(0, 0.22, 0))
	Art.part(h, Art.cyl(0.305, 0.305, 0.08, 7), Art.GOLD, Vector3(0, 0.06, 0), Vector3.ONE, Vector3.ZERO, false, 0.15)
	Art.part(h, Art.cyl(0.0, 0.18, 0.4, 7), col, Vector3(0.06, 0.56, 0.04), Vector3.ONE, Vector3(0, 0, -25))
	return h


## Cartoon death face: hide eyes, draw X's.
static func x_eyes(p: Dictionary) -> void:
	for e: Node3D in p.get("eyes", []):
		for ch: Node in e.get_children():
			(ch as Node3D).visible = false
		for k: float in [-1.0, 1.0]:
			Art.part(e, Art.box(Vector3(0.14, 0.03, 0.03)), Art.INK, Vector3(0, 0, -0.01), Vector3.ONE, Vector3(0, 0, 45.0 * k))
