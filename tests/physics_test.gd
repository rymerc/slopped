extends SceneTree
## Headless test of the physics / ragdoll / prop systems inside the real lobby.
##   godot --headless --path . -s tests/physics_test.gd -- --host --bots=2
## Duck-typed (no class_name refs) so it compiles before autoloads exist.

var _start := 0
var _stage := 0
var _t0 := 0.0
var _fail := false
var _w: Node
var _me: Node
var _bot: Node
var _crate: Node


func _initialize() -> void:
	_start = Time.get_ticks_msec()
	change_scene_to_file("res://src/main/main.tscn")


func _t() -> float:
	return (Time.get_ticks_msec() - _start) / 1000.0


func _check(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		_fail = true


func _process(_d: float) -> bool:
	if _t() > 60.0:
		_check(false, "timeout at stage %d" % _stage)
		return _done()
	_w = root.get_node_or_null("Main/World")
	if _w == null:
		return false
	match _stage:
		0:
			if _t() > 2.0:
				_me = _w.local_avatar()
				for av: Node in _w.avatars.values():
					if av.is_bot:
						_bot = av
				_check(_me != null and _bot != null, "avatars present")
				_check(_w.props.list.size() > 50, "props spawned (%d)" % _w.props.list.size())
				_me.start_ragdoll(Vector3(6, 9, 0))
				_check(_me.state == 1, "full ragdoll started")
				_t0 = _t()
				_stage = 1
		1:
			if _me.state == 0 and _t() - _t0 > 1.0:
				_check(true, "ragdoll -> get-up -> normal in %.1fs" % (_t() - _t0))
				_check(_me.global_position.y > -1.0 and _me.global_position.y < 6.0, "landed sane (y=%.2f)" % _me.global_position.y)
				_check(_me.collision_layer == 2, "collision restored")
				_me.push(Vector3(4, 0, 0))  # partial: no ragdoll
				_check(_me.state == 0, "small hit stays standing (partial ragdoll)")
				# shove the bot (server path)
				_bot.place(_me.global_position + _me.forward() * 1.0)
				_w.do_shove(_me.pid, _me.forward())
				_t0 = _t()
				_stage = 2
			elif _t() - _t0 > 8.0:
				_check(false, "ragdoll never recovered (state=%d)" % _me.state)
				_stage = 2
		2:
			if _t() - _t0 > 0.5:
				_check(_bot.velocity.length() > 1.0 or _bot.state != 0, "shove moved the bot")
				# grab + throw a crate
				for p: Node in _w.props.list:
					if p.kind == "crate_s" or p.kind == "ball":
						_crate = p
						break
				_me.place(_crate.global_position + Vector3(1.2, 0.3, 0))
				_t0 = _t()
				_stage = 3
		3:
			if _t() - _t0 > 0.3 and _t() - _t0 < 0.4:
				_w.props.do_grab(_me.pid, _crate.id)
			if _t() - _t0 > 0.8:
				_check(_me.holding == _crate and _crate.holder == _me.pid, "grabbed %s" % _crate.kind)
				_w.props.do_release(_me.pid, true, Vector3(0, 0.3, -1))
				_t0 = _t()
				_stage = 4
		4:
			if _t() - _t0 > 0.15:
				_check(_me.holding == null and _crate.holder == 0, "released")
				_check(_crate.linear_velocity.length() > 5.0, "thrown fast (%.1f m/s)" % _crate.linear_velocity.length())
				# explosion launches the bot into a ragdoll
				_bot.place(Vector3(5, 0.5, 9))
				_t0 = _t()
				_stage = 5
		5:
			if _t() - _t0 > 0.5:
				_w.props.explode(_bot.global_position + Vector3(-1.5, 0, 0), 6.0, 24.0, _me.pid)
				_t0 = _t()
				_stage = 6
		6:
			if _t() - _t0 > 0.2:
				_check(_bot.state == 1, "explosion ragdolled the bot")
				_me.die(Vector3(5, 5, 0), "launch")
				_check(_me.dead, "death -> ghost")
				var corpse := false
				for c: Node in _w.get_children():
					if c.name.begins_with("Ragdoll"):
						corpse = true
				_check(corpse, "corpse ragdoll spawned")
				_me.set_dead(false)
				_t0 = _t()
				_stage = 7
		7:
			# vault: a crate on each plate opens it
			var plates := [Vector3(30, 0.5, 80), Vector3(60, 0.5, 80)]
			var crates := []
			for p: Node in _w.props.list:
				if p.kind == "crate" and crates.size() < 2:
					crates.append(p)
			for i in 2:
				crates[i].global_position = plates[i] + Vector3(0, 1.0, 0)
				crates[i].sleeping = false
			_t0 = _t()
			_stage = 8
		8:
			if _t() - _t0 > 1.5:
				_check(_w.vault_open > 0.0, "crates on both plates opened the vault")
				# hazards: stand in the sweeper's path
				_me.place(Vector3(-75, 2.8, 14 + 2.5))
				_t0 = _t()
				_stage = 9
		9:
			if _t() - _t0 > 5.0:
				_check(_me.state != 0 or _me.global_position.distance_to(Vector3(-75, 2.8, 16.5)) > 1.5, "sweeper knocked the player")
				return _done()
	return false


func _done() -> bool:
	print("PHYSICS ", "FAILED" if _fail else "OK")
	quit(1 if _fail else 0)
	return false
