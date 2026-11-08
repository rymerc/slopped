class_name Npcs
extends Node3D
## The townsfolk. Dealers, bartenders and people walking around. They do their jobs.
## They also stare at you. Heads turn further than heads should, walkers stop dead
## as you pass, and nobody blinks.
##
## This runs on each peer separately, watching that peer's own player, and sends
## nothing over the network. So everyone sees the whole town staring at them
## specifically, and nobody can prove it's happening to anyone else.

const STARE_RANGE := 18.0
const FREEZE_RANGE := 7.0
const HIDE_RANGE := 46.0
const OWL_LIMIT := 2.7  # radians: well past comfortable
const WALK_SPEED := 1.5
const MUTTER := ["i know", "nice shoes", "we saw that", "keep going", "it's fine", "you're doing great",
	"don't look", "...", "again?", "we like you"]

var game: WorldBase
var _all: Array[Dictionary] = []
var _mutter_t := 12.0
var deal_t := 0.0  # dealers flick their arms while this runs down


## A worker: stays put, faces `yaw`, follows you with their head.
## job: "" stands there (and fidgets), "wipe" polishes a glass forever, "deal" works
## the table, "piano" hammers the keys, "sit" sits, "rattle" shakes the cell bars.
func add_still(pos: Vector3, yaw: float, look: Dictionary, job := "") -> void:
	_add(look, pos, yaw, [])
	_all[-1].job = job


## A walker: loops a path of points forever.
func add_walker(path: Array, look: Dictionary) -> void:
	_add(look, path[0], 0.0, path)


func _add(look: Dictionary, pos: Vector3, yaw: float, path: Array) -> void:
	var p: Dictionary = Art.build_character(look)
	var root: Node3D = p.root
	add_child(root)
	_hold(p.limbs.arm_r as Node3D, str(look.get("holds", "")))
	if str(p.kind) != "robot":  # robots already have a screen for a face
		_eyes(p.limbs.head as Node3D)
	root.position = pos
	root.rotation.y = yaw
	_all.append({"parts": p, "root": root, "path": path, "i": 1, "phase": randf() * TAU,
		"hold": 0.0, "twitch": randf_range(2.0, 7.0), "off": 0.0, "idle": randf_range(2.0, 6.0), "gesture": ""})


## Something in the right hand. The hand sits 0.38 m down the arm.
static func _hold(arm: Node3D, what: String) -> void:
	var h := Vector3(0, -0.46, -0.04)
	match what:
		"glass":
			Art.part(arm, Art.cyl(0.07, 0.055, 0.17, 7), Color("#bfe8f0"), h + Vector3(0, -0.04, -0.06), Vector3.ONE, Vector3.ZERO, false, 0.2)
			Art.part(arm, Art.box(Vector3(0.2, 0.02, 0.14)), Color("#f2efe9"), h + Vector3(0, 0.06, -0.02))  # the rag
		"card":
			Art.part(arm, Art.box(Vector3(0.12, 0.17, 0.01)), Color("#fbf7ee"), h + Vector3(0, -0.06, -0.06))
			Art.part(arm, Art.box(Vector3(0.04, 0.04, 0.012)), Color("#d62b3a"), h + Vector3(0, -0.06, -0.07))
		"coffee":
			Art.part(arm, Art.cyl(0.06, 0.05, 0.15, 7), Color("#f2efe9"), h + Vector3(0, -0.03, -0.06))
			Art.part(arm, Art.cyl(0.062, 0.062, 0.02, 7), Color("#4a2f22"), h + Vector3(0, 0.05, -0.06))
		"paper":
			Art.part(arm, Art.box(Vector3(0.05, 0.3, 0.22)), Color("#e8e2d0"), h + Vector3(0, -0.08, -0.08), Vector3.ONE, Vector3(0, 0, 10))
		"cone":
			Art.part(arm, Art.cyl(0.06, 0.0, 0.18, 6), Color("#d9a35a"), h + Vector3(0, 0.02, -0.06))
			Art.part(arm, Art.sphere(0.07, 6), Color("#ff9ac1"), h + Vector3(0, 0.13, -0.06))
		"balloon":
			Art.part(arm, Art.cyl(0.006, 0.006, 1.1, 3), Color("#f2efe9"), h + Vector3(0, 0.55, -0.04))
			Art.part(arm, Art.sphere(0.24, 8), Color("#ff3b5c"), h + Vector3(0, 1.25, -0.04), Vector3(1, 1.2, 1))
		"tray":
			Art.part(arm, Art.cyl(0.24, 0.24, 0.02, 10), Color("#c9a24a"), h + Vector3(0, 0.0, -0.1))
			for i in 3:
				Art.part(arm, Art.cyl(0.035, 0.035, 0.14, 6), Color("#ff6fb0"), h + Vector3(cos(i * 2.1) * 0.12, 0.08, -0.1 + sin(i * 2.1) * 0.12), Vector3.ONE, Vector3.ZERO, false, 0.6)


## Wide white eyes over the costume's own dot eyes. They never blink.
static func _eyes(head: Node3D) -> void:
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(Chars.EYE.x * sx, Chars.EYE.y, Chars.EYE.z - 0.012)
		Art.part(head, Art.sphere(0.062, 8), Color("#fbf7ee"), p, Vector3(1, 1, 0.35))
		Art.part(head, Art.sphere(0.03, 6), Color("#111118"), p + Vector3(0, 0, -0.022), Vector3(1, 1, 0.4))


func _process(delta: float) -> void:
	var me: Avatar = game.local_avatar() if game else null
	if me == null:
		return
	var eye := me.global_position + Vector3.UP * 1.3 * me.size
	deal_t -= delta
	for n: Dictionary in _all:
		_tick(n, eye, delta)
	_mutter(eye, delta)


func _tick(n: Dictionary, eye: Vector3, delta: float) -> void:
	var root: Node3D = n.root
	var d := root.global_position.distance_to(eye)
	root.visible = d < HIDE_RANGE
	if not root.visible:
		return
	var head: Node3D = n.parts.head
	var limbs: Dictionary = n.parts.limbs
	var path: Array = n.path
	var walking := false
	if not path.is_empty() and d > FREEZE_RANGE:
		walking = _walk(n, root, path, delta)
	if d < FREEZE_RANGE and not path.is_empty():  # the whole body comes round, slowly
		var to := eye - root.global_position
		root.rotation.y = lerp_angle(root.rotation.y, atan2(-to.x, -to.z), clampf(delta * 1.6, 0.0, 1.0))
	n.phase = float(n.phase) + delta * (9.0 if walking else 0.0)
	var swing := sin(float(n.phase)) * 0.6 if walking else 0.0
	(limbs.leg_l as Node3D).rotation.x = swing
	(limbs.leg_r as Node3D).rotation.x = -swing
	(limbs.arm_l as Node3D).rotation.x = -swing * 0.7
	(limbs.arm_r as Node3D).rotation.x = swing * 0.7
	var t := Time.get_ticks_msec() * 0.001 + float(n.phase)
	match str(n.get("job", "")):
		"wipe":
			(limbs.arm_r as Node3D).rotation = Vector3(-1.4, 0, sin(t * 6.0) * 0.5)
		"piano":
			(limbs.arm_l as Node3D).rotation.x = -1.2 + sin(t * 17.0) * 0.28
			(limbs.arm_r as Node3D).rotation.x = -1.2 + sin(t * 13.0 + 1.0) * 0.28
		"deal":
			var flick := sin(t * 12.0) * 0.5 if deal_t > 0.0 else 0.0
			(limbs.arm_r as Node3D).rotation.x = -1.1 + flick
			(limbs.arm_l as Node3D).rotation.x = -0.9
		"sit":
			(limbs.leg_l as Node3D).rotation.x = -1.5
			(limbs.leg_r as Node3D).rotation.x = -1.5
			(limbs.arm_l as Node3D).rotation.x = -0.5
			(limbs.arm_r as Node3D).rotation.x = -0.5
		"rattle":  # hands on the bars; harder when you're close
			var hard := 0.22 if d < FREEZE_RANGE else 0.06
			(limbs.arm_l as Node3D).rotation = Vector3(-1.55 + sin(t * 19.0) * hard, 0, -0.18)
			(limbs.arm_r as Node3D).rotation = Vector3(-1.55 + sin(t * 19.0 + 1.3) * hard, 0, 0.18)
		"":
			if not walking:
				_fidget(n, limbs, d, t, delta)
	var want := Vector2.ZERO
	if d < STARE_RANGE:
		var l: Vector3 = root.global_transform.affine_inverse() * eye - head.global_position * 0.0
		l = l - Vector3(0, 1.3, 0)
		want = Vector2(clampf(atan2(l.y, Vector2(l.x, l.z).length()), -0.8, 0.8),
			clampf(atan2(-l.x, -l.z), -OWL_LIMIT, OWL_LIMIT))
		# every so often the head snaps a little, like it forgot it was being subtle
		n.twitch = float(n.twitch) - delta
		if float(n.twitch) <= 0.0:
			n.twitch = randf_range(2.5, 8.0)
			n.off = randf_range(-0.25, 0.25)
		n.off = lerpf(float(n.off), 0.0, clampf(delta * 9.0, 0.0, 1.0))
		want.y += float(n.off)
	var k := clampf(delta * 3.2, 0.0, 1.0)
	head.rotation.x = lerp_angle(head.rotation.x, want.x, k)
	head.rotation.y = lerp_angle(head.rotation.y, want.y, k)


## Idle business for anyone without a job: scratch, check a watch that isn't there,
## shift about. Get close and they stop all that and wave at you, very slowly.
func _fidget(n: Dictionary, limbs: Dictionary, d: float, t: float, delta: float) -> void:
	var arm_l := limbs.arm_l as Node3D
	var arm_r := limbs.arm_r as Node3D
	if d < FREEZE_RANGE:
		arm_r.rotation = Vector3(-2.7, 0, 0.35 + sin(t * 1.6) * 0.35)
		return
	n.idle = float(n.idle) - delta
	if float(n.idle) <= 0.0:
		n.gesture = ["", "scratch", "watch", "shift", ""][randi() % 5] if str(n.gesture) == "" else ""
		n.idle = randf_range(1.8, 3.0) if str(n.gesture) != "" else randf_range(3.0, 8.0)
	match str(n.gesture):
		"scratch":
			arm_r.rotation = Vector3(-2.9, 0, -0.5 + sin(t * 14.0) * 0.12)
		"watch":
			arm_l.rotation = Vector3(-1.4, 0, -0.6)
			arm_r.rotation = Vector3(-0.9, 0, 0.5)
		"shift":
			(limbs.torso as Node3D).rotation.z = sin(t * 2.0) * 0.08


func _walk(n: Dictionary, root: Node3D, path: Array, delta: float) -> bool:
	if float(n.hold) > 0.0:
		n.hold = float(n.hold) - delta
		return false
	var goal: Vector3 = path[int(n.i)]
	var to := goal - root.position
	to.y = 0.0
	if to.length() < 0.4:
		n.i = (int(n.i) + 1) % path.size()
		n.hold = randf_range(0.0, 3.0)
		return false
	root.position += to.normalized() * WALK_SPEED * delta
	root.rotation.y = lerp_angle(root.rotation.y, atan2(-to.x, -to.z), clampf(delta * 5.0, 0.0, 1.0))
	return true


func _mutter(eye: Vector3, delta: float) -> void:
	_mutter_t -= delta
	if _mutter_t > 0.0:
		return
	_mutter_t = randf_range(14.0, 32.0)
	var near: Array = _all.filter(func(n: Dictionary) -> bool:
		return (n.root as Node3D).global_position.distance_to(eye) < 9.0)
	if not near.is_empty():
		var root: Node3D = near.pick_random().root
		Fx.text(game, root.global_position + Vector3.UP * 2.1, MUTTER.pick_random(), Color("#d8d0e0"), 0.007, 0.5, 2.6)
