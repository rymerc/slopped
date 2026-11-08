class_name CursedCasino
extends MiniGame
## CURSED CASINO NIGHT. The Lucky Duck after hours. Everyone gambles real machines
## with match chips and most chips at the bell wins, but one player is THE HOUSE.
## The house banks every loss and quietly rigs the odds. Rig too hard for too long
## and suspicion hits 100: the house is exposed and pays half its bank back out.
## Shoving someone steals their chips. The doors are locked.

const START_CHIPS := 100
const MATCH_SECS := 300.0
const STEAL_FRAC := 0.12
const STEAL_MIN := 5
const SUSPICION_RATE := 1.8  # per second, per rig level
const SUSPICION_COOL := 1.5
const RIG_MAX := 3

var casino: Casino
var casino_ui: CasinoUI
var tables: CasinoTables
var floor_fx: CasinoFloorFx
var suspicion := 0.0
var _refs: Dictionary = {}
var _bot_t: Dictionary = {}


func build_arena() -> void:
	make_environment(Color("#1a1030"), Color("#5a2050"), 0.5, 0.25, 90.0, 300.0, Vector3(-40, -52, 0), Color("#a080ff"), Color("#7a3060"))
	allow_shove = true
	var b := Batch.new()
	var ground := StaticBody3D.new()
	ground.collision_mask = 0
	add_child(ground)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(240, 1, 240)
	cs.shape = sh
	cs.position = Vector3(40, -0.5, 0)
	ground.add_child(cs)
	Art.part(self, Art.box(Vector3(240, 1, 240)), Color("#2a1f30"), Vector3(40, -0.55, 0))
	Kit.landmark(self, b, "casino", LobbyBuilder.CASINO, -90.0)
	LobbyBuilder.casino_floor(self, b, _refs)
	# the doors are locked: barred, boarded and chained (the signs are in the models)
	Art.col_box(self, Vector3(0.6, 5.2, 7.4), Vector3(28.1, 2.6, -1))
	Art.col_box(self, Vector3(5.4, 4.4, 0.6), Vector3(40, 2.2, 18))
	Art.col_box(self, Vector3(5.4, 4.4, 0.6), Vector3(40, 2.2, -20))
	Kit.landmark(self, b, "cc_gate_big", Vector3(28.1, 0, -1), 90.0)
	Kit.landmark(self, b, "cc_gate_small", Vector3(40, 0, 18), 180.0)
	Kit.landmark(self, b, "cc_gate_small", Vector3(40, 0, -20), 0.0)
	# after hours: purple candles by the doors, chips and cards where people panicked
	for p: Vector3 in [Vector3(29.3, 0, -5.6), Vector3(29.3, 0, 3.6), Vector3(37.4, 0, 16.6), Vector3(42.6, 0, 16.6),
			Vector3(37.4, 0, -18.6), Vector3(42.6, 0, -18.6)]:
		Art.col_cyl(self, 0.35, 2.0, p + Vector3.UP)
		Kit.landmark(self, b, "cc_candles", p)
	for p: Vector3 in [Vector3(36.5, 0, 0.5), Vector3(44.0, 0, -6.0), Vector3(38.0, 0, 10.0), Vector3(47.0, 0, 3.5)]:
		Kit.landmark(self, b, "cc_mess", p, p.x * 37.0)
	var keep: Array = _refs.values()
	for d: Variant in (_refs.slots as Array) + (_refs.roulette as Array):
		keep.append_array((d as Dictionary).values())
	keep.append_array((_refs.ducks as Dictionary).values())
	b.absorb(self, keep)
	b.commit(self)
	casino = Casino.new()
	casino.name = "Casino"
	casino.chips_mode = true
	add_child(casino)
	casino_ui = CasinoUI.new()
	casino_ui.casino = casino
	hud.add_child(casino_ui)
	casino_ui.closed.connect(close_ui)
	floor_fx = CasinoFloorFx.new()
	floor_fx.refs = _refs
	add_child(floor_fx)
	tables = CasinoTables.new()
	tables.name = "Tables"
	tables.game = self
	tables.casino = casino
	tables.floor_fx = floor_fx
	add_child(tables)
	LobbyBuilder.wire_casino(self, tables.sit, _can_gamble)
	Ambience.emitter(self, "casino_lounge", LobbyBuilder.CASINO + Vector3(-2, 3, 0), &"Music", -1.0, 60.0).pitch_scale = 0.8


func _can_gamble() -> bool:
	return Net.me() != boss_id


func close_ui() -> void:
	casino_ui.visible = false
	tables.leave()
	super.close_ui()


func casino_fx(kind: String, seat: int, data: Dictionary) -> void:
	floor_fx.fx(kind, seat, data)


func spawn_for(av: Avatar, index: int) -> Vector3:
	if av.pid == boss_id:
		return Vector3(47, 0.8, -1)
	var a := index * 1.1
	return Vector3(36.0 + cos(a) * 3.0, 0.5, -1.0 + sin(a) * 2.5)


func configure_avatar(av: Avatar) -> void:
	base_config(av)
	if av.pid == boss_id:
		av.set_size(1.25)
	elif not roster.has(av.pid) and not av.dead:
		av.set_dead(true)


func game_begin() -> void:
	if Net.me() == boss_id:
		banner("YOU ARE THE HOUSE\nrig the odds. don't get caught.", 5.0)
	else:
		banner("CURSED CASINO NIGHT\nmost chips at the bell wins. shove to steal.", 5.0)
	if not multiplayer.is_server():
		return
	time_left = MATCH_SECS
	for id: int in mortals():
		casino.chips[id] = START_CHIPS
	scores = casino.chips.duplicate()
	extra = {"bank": 0, "sus": 0.0, "rig": 0}


func game_tick(delta: float) -> void:
	if Net.is_bot(boss_id):
		_bot_house(delta)
	if casino.rig > 0:
		suspicion += SUSPICION_RATE * casino.rig * delta
	else:
		suspicion = maxf(0.0, suspicion - SUSPICION_COOL * delta)
	if suspicion >= 100.0:
		_busted()
	_bots(delta)
	scores = casino.chips.duplicate()
	extra.bank = casino.house_bank
	extra.sus = suspicion
	extra.rig = casino.rig


func _busted() -> void:
	suspicion = 0.0
	casino.rig = 0
	var back := casino.house_bank / 2
	casino.house_bank -= back
	var ids := mortals()
	for id: int in ids:
		casino.chips[id] = int(casino.chips.get(id, 0)) + back / maxi(1, ids.size())
	Net.announce("THE HOUSE WAS RIGGED! %s pays back %d chips" % [Net.pname(boss_id), back])


func world_process(delta: float) -> void:
	super.world_process(delta)
	if not multiplayer.is_server():
		casino.chips = scores


func world_input(event: InputEvent) -> void:
	if Net.me() != boss_id or over:
		return
	if event.is_action_pressed("ability_1"):
		Net.to_server(self, "req_rig", [1])
	elif event.is_action_pressed("ability_2"):
		Net.to_server(self, "req_rig", [-1])


@rpc("any_peer", "reliable")
func req_rig(delta_level: int) -> void:
	if multiplayer.is_server() and Net.sender() == boss_id:
		casino.rig = clampi(casino.rig + signi(delta_level), 0, RIG_MAX)


func on_shove_hit(pid: int, victim: int) -> void:
	if victim == boss_id:
		return
	var have := int(casino.chips.get(victim, 0))
	var n := mini(have, maxi(STEAL_MIN, int(have * STEAL_FRAC)))
	if n <= 0:
		return
	casino.chips[victim] = have - n
	if pid == boss_id:
		casino.house_bank += n
	else:
		casino.chips[pid] = int(casino.chips.get(pid, 0)) + n
	_ev_steal.rpc((avatars[victim] as Avatar).global_position, n)


@rpc("authority", "call_local", "reliable")
func _ev_steal(pos: Vector3, n: int) -> void:
	Fx.text(self, pos + Vector3.UP * 2.0, "-%d" % n, Art.GOLD, 0.014)
	Fx.confetti(self, pos + Vector3.UP, 12)
	Sfx.at(self, "coin", pos, 0.0)


func on_time_up() -> void:
	var ids := mortals()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(casino.chips.get(a, 0)) > int(casino.chips.get(b, 0)))
	var pays := {}
	for i in ids.size():
		pays[ids[i]] = [1 if i < ids.size() / 2 else 0, 15 + int(casino.chips.get(ids[i], 0)) / 5, 60]
	var top: int = ids[0] if not ids.is_empty() else 0
	var best := int(casino.chips.get(top, 0))
	if casino.house_bank > best:
		pays[boss_id] = [3, 40 + casino.house_bank / 5, 150]
		finish("THE HOUSE ALWAYS WINS (%d chips)" % casino.house_bank, [boss_id], pays)
	else:
		pays[top] = [3, 60 + best / 4, 150]
		pays[boss_id] = [0, 15, 40]
		finish("%s BROKE THE BANK (%d chips)" % [Net.pname(top), best], [top], pays)


func on_player_left(id: int) -> void:
	if id == boss_id:
		on_time_up()


func info_text() -> String:
	var sus := "SUSPICION %d%%" % int(extra.get("sus", 0.0))
	if Net.me() == boss_id:
		return "RIG LEVEL %d  (%s up, %s down)   BANK %d   %s   shove to confiscate" % [int(extra.get("rig", 0)),
			InputSetup.label("ability_1"), InputSetup.label("ability_2"), int(extra.get("bank", 0)), sus]
	return "%s   shove to steal chips   play any machine" % sus


func board_lines() -> PackedStringArray:
	var out := super.board_lines()
	out.insert(0, "THE HOUSE: %s" % Net.pname(boss_id))
	return out


# --- bots ------------------------------------------------------------------------

func _bot_house(delta: float) -> void:
	var t := float(_bot_t.get(boss_id, 4.0)) - delta
	_bot_t[boss_id] = t
	if t <= 0.0:
		_bot_t[boss_id] = 6.0
		casino.rig = 0 if suspicion > 70.0 else randi_range(1, RIG_MAX)


func _bots(delta: float) -> void:
	for id: int in mortals() + [boss_id]:
		var av: Avatar = avatars.get(id)
		if av == null or not av.is_bot or av.dead:
			continue
		var b: Dictionary = _bot_t.get("b%d" % id, {"t": randf_range(1, 4), "goal": _bot_spot(), "act": randf()})
		_bot_t["b%d" % id] = b
		b.t = float(b.t) - delta
		var to: Vector3 = (b.goal as Vector3) - av.global_position
		to.y = 0.0
		av.bot_move = to.normalized() * 0.7 if to.length() > 1.8 else Vector3.ZERO
		if float(b.t) > 0.0:
			continue
		b.t = randf_range(2.5, 5.0)
		b.goal = _bot_spot()
		if id == boss_id or float(b.act) < 0.3:
			var near: Array = avatars.values().filter(func(o: Avatar) -> bool:
				return o != av and o.global_position.distance_to(av.global_position) < 2.6)
			if not near.is_empty():
				do_shove(id, (near[0] as Avatar).global_position - av.global_position)
		elif randf() < 0.5:
			casino.do_slots(id, randi() % LobbyBuilder.SLOTS.size())
		else:
			casino.do_roulette(id, ["red", "black"].pick_random(), randi() % 2)


func _bot_spot() -> Vector3:
	return Vector3(randf_range(31.0, 49.0), 0, randf_range(-16.0, 15.0))
