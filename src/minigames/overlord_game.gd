class_name OverlordGame
extends MiniGame
## One player floats above the arena and casts aimed powers at everyone else.
## Shared by POCKET GOD and THE FLOOR IS LAVA SOUP. The overlord is a ghost body
## (no collision), so the normal avatar sync carries them around.
##
## Subclasses define powers() and cast(id, pos), which runs on the host. Every
## strike is telegraphed: warn() first, then the hit, so deaths feel earned.

const BOSS_HEIGHT := 34.0

var cds: Dictionary = {}
var bot_pace := Vector2(1.5, 3.5)  # seconds between a bot overlord's casts
var _bot_think := 2.0


## [{"id", "act" (input action), "cd" seconds, "label"}]
func powers() -> Array:
	return []


func cast(_id: String, _pos: Vector3) -> void:
	pass


func boss_start() -> Vector3:
	return Vector3(0, BOSS_HEIGHT, 30)


func spawn_for(av: Avatar, index: int) -> Vector3:
	if av.pid == boss_id:
		return boss_start()
	return mortal_spawn(index)


func mortal_spawn(index: int) -> Vector3:
	var a := index * 1.3
	return Vector3(cos(a) * 8.0, 1.0, sin(a) * 8.0)


func configure_avatar(av: Avatar) -> void:
	if av.pid == boss_id:
		av.role = "overlord"
		av.ghost_speed = 26.0
		if not av.dead:
			av.set_dead(true)
		if av.is_local():
			cam.distance = 20.0
			cam.pitch = -1.0
			_cross.visible = true
		return
	configure_mortal(av)
	if not roster.has(av.pid) and not av.dead:
		av.set_dead(true)


func configure_mortal(av: Avatar) -> void:
	base_config(av)


func world_input(event: InputEvent) -> void:
	var me := local_avatar()
	if me == null or me.pid != boss_id or over:
		return
	for p: Dictionary in powers():
		if event.is_action_pressed(p.act):
			var skip: Array[RID] = [me.get_rid()]
			Net.to_server(self, "req_power", [p.id, cam.aim_point(skip, 500.0)])


@rpc("any_peer", "reliable")
func req_power(id: String, pos: Vector3) -> void:
	if Net.sender() == boss_id:
		use_power(id, pos)


func use_power(id: String, pos: Vector3) -> void:
	if not multiplayer.is_server() or over or float(cds.get(id, 0.0)) > 0.0:
		return
	for p: Dictionary in powers():
		if p.id == id:
			var mult := PerkDB.cooldown_mult(Net.perks_of(boss_id))
			cds[id] = float(p.cd) * mult
			cast(id, pos)


func tick_powers(delta: float) -> void:
	for k: String in cds:
		cds[k] = maxf(0.0, float(cds[k]) - delta)
	extra["cds"] = cds
	if Net.is_bot(boss_id):
		_bot_boss(delta)


## Bot overlord: picks something off cooldown and aims at someone.
func _bot_boss(delta: float) -> void:
	_bot_think -= delta
	if _bot_think > 0.0:
		return
	_bot_think = randf_range(bot_pace.x, bot_pace.y)
	var alive: Array = alive_mortals()
	if alive.is_empty():
		return
	var target: Avatar = alive.pick_random()
	var ready_now: Array = powers().filter(func(p: Dictionary) -> bool: return float(cds.get(p.id, 0.0)) <= 0.0)
	if not ready_now.is_empty():
		use_power(str(ready_now.pick_random().id), target.global_position)


func alive_mortals() -> Array:
	var out: Array = []
	for id: int in mortals():
		var av: Avatar = avatars.get(id)
		if av and not av.dead:
			out.append(av)
	return out


func boss_info() -> String:
	var bits: PackedStringArray = []
	var c: Dictionary = extra.get("cds", {})
	for p: Dictionary in powers():
		var left := float(c.get(p.id, 0.0))
		bits.append("%s %s %s" % [InputSetup.label(p.act), p.label, "READY" if left <= 0.0 else "%.0fs" % left])
	return "   ".join(bits)


@rpc("authority", "call_local", "reliable")
func _ev_warn(pos: Vector3, r: float) -> void:
	GiantFx.warn(self, pos, r)
	Sfx.at(self, "hiss", pos, -6.0, 0.1, 1.4)


## Host: delayed area hit. launch > 0 knocks people around; props always fly.
func strike(pos: Vector3, r: float, delay: float, launch: float, skip := 0) -> void:
	_ev_warn.rpc(pos, r)
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or over:
		return
	_ev_boom.rpc(pos, r)
	props.blast(pos, r, launch, launch, skip)


@rpc("authority", "call_local", "reliable")
func _ev_boom(pos: Vector3, r: float) -> void:
	Fx.explosion(self, pos, minf(r, 6.0))
	Sfx.at(self, "boom", pos, 4.0, 0.1, 1.2)
	var me := local_avatar()
	if me and me.global_position.distance_to(pos) < r * 2.5:
		cam.shake(0.7)
