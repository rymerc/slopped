class_name TrickSystem
extends Node
## Fires Dirty Deeds items in any world. Host validates and spends the item, then
## broadcasts the effect. Lives at World/Tricks so the RPC path is the same in the
## lobby and every minigame. The bag sits in the Net profile, so it follows you.

const BOMB_FUSE := 8.0
const BOMB_PASS_DIST := 1.9
const BOT_THINK := 25.0

var game: WorldBase
var menu: TrickMenu
var _hud: Label
var _pie: Control
var _bomb_id := 0
var _bomb_t := 0.0
var _bomb_by := 0
var _bomb_cd := 0.0
var _bomb_label: Label3D
var _bot_t := BOT_THINK


func _ready() -> void:
	menu = TrickMenu.new()
	menu.tricks = self
	game.hud.add_child(menu)
	_hud = Ui.label("", 22, Color("#ff8a8a"))
	_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_hud.offset_left = 16
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(_hud)
	_pie = Control.new()
	_pie.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pie.visible = false
	game.hud.add_child(_pie)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var bg := ColorRect.new()
	bg.color = Color(1.0, 0.96, 0.82, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pie.add_child(bg)
	for i in 14:  # thick custard globs, leaving small gaps to squint through
		var c := ColorRect.new()
		c.color = Color("#f6e6b4") if i % 2 == 0 else Color("#e8c98a")
		c.size = Vector2(rng.randf_range(240, 560), rng.randf_range(160, 360))
		c.position = Vector2(rng.randf_range(-100, 1300), rng.randf_range(-60, 700))
		c.rotation = rng.randf() * TAU
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pie.add_child(c)


func open_menu() -> void:
	menu.open()
	game.open_ui()


# --- requests --------------------------------------------------------------------

@rpc("any_peer", "reliable")
func req_use(item: String, target: int) -> void:
	do_use(Net.sender(), item, target)


func do_use(by: int, item: String, target: int) -> void:
	if not multiplayer.is_server() or not Tricks.ITEMS.has(item) or not Net.players.has(by):
		return
	var bag: Array = Net.players[by].get("bag", [])
	if not bag.has(item):
		return
	var it: Dictionary = Tricks.ITEMS[item]
	if Tricks.needs_target(item) and (target == by or not Net.players.has(target)):
		return
	bag.erase(item)
	if Tricks.needs_target(item):
		var p: Dictionary = Net.players[target]
		if int(p.get("ward", 0)) > 0:
			p.ward = int(p.ward) - 1
			Net.announce("%s's lawyer got %s thrown out" % [Net.pname(target), it.name])
			Net.broadcast()
			return
		if int(p.get("mirror", 0)) > 0:
			p.mirror = int(p.mirror) - 1
			Net.announce("UNO REVERSE! %s bounced off %s" % [it.name, Net.pname(target)])
			var was := by  # the victim now casts it back, so money tricks pay them
			by = target
			target = was
	Net.broadcast()
	match str(it.kind):
		"hex":
			hex_on(target, it.hex, float(it.secs))
		"all":
			for id: int in Net.players:
				if id != by:
					hex_on(id, it.hex, float(it.secs))
			Net.announce("Someone caused a %s" % it.name)
		"action":
			_action(by, item, target)
	if Tricks.needs_target(item) and randf() < 0.25:
		Net.announce("%s was behind that %s" % [Net.pname(by), it.name])


## Host: applies a hex. Everyone runs it, so the victim's input and the effects
## other players see stay in agreement. Also used by minigame powers.
func hex_on(id: int, kind: String, secs: float) -> void:
	if multiplayer.is_server() and game.avatars.has(id):
		_ev_hex.rpc(id, kind, secs)


@rpc("authority", "call_local", "reliable")
func _ev_hex(id: int, kind: String, secs: float) -> void:
	var av: Avatar = game.avatars.get(id)
	if av == null:
		return
	av.add_hex(kind, secs)
	Fx.text(game, av.global_position + Vector3.UP * 2.4 * av.size, str(Tricks.HEX_NAMES.get(kind, kind)), Color("#ff8a8a"), 0.012)
	Sfx.at(game, "boing", av.global_position, -4.0, 0.2, 0.7)


func _action(by: int, item: String, target: int) -> void:
	var av: Avatar = game.avatars.get(target)
	var me: Avatar = game.avatars.get(by)
	match item:
		"bomb":
			if av and _bomb_id == 0:
				_bomb_id = target
				_bomb_by = by
				_bomb_t = BOMB_FUSE
				_bomb_cd = 1.0
				_ev_bomb.rpc(target, BOMB_FUSE)
				Net.announce("%s is holding a bomb. RUN INTO SOMEONE" % Net.pname(target))
		"swap":
			if av and me and not av.dead and not me.dead:
				var a := av.global_position
				var b := me.global_position
				av.teleport.rpc(b + Vector3.UP * 0.3)
				me.teleport.rpc(a + Vector3.UP * 0.3)
				Net.announce("%s and %s swapped bodies" % [Net.pname(by), Net.pname(target)])
		"audit":
			var cut := int(int(Net.players[target].coins) * 0.3)
			Net.give_coins(target, -cut)
			Net.give_coins(by, cut)
			Net.announce("%s was audited for %dc" % [Net.pname(target), cut])
			Net.broadcast()
		"bankrupt":
			var all := int(Net.players[target].coins)
			Net.give_coins(target, -all)
			Net.give_coins(by, all / 2)
			Net.announce("%s has been acquired. %dc gone" % [Net.pname(target), all])
			Net.broadcast()
		"orbital":
			if av:
				var pos := av.global_position
				_ev_duck.rpc(pos)
				Net.announce("Something is falling on %s" % Net.pname(target))
				await get_tree().create_timer(2.6).timeout
				if is_inside_tree():
					game.props.explode(pos, 10.0, 42.0, by)
		"misfortune":
			Net.announce("%s spun the Wheel of Misfortune" % Net.pname(target))
			for i in 5:
				hex_on(target, Tricks.RANDOM_HEXES.pick_random(), 6.0)
				await get_tree().create_timer(5.0).timeout
				if not is_inside_tree():
					return
		"shuffle":
			var alive: Array = game.avatars.values().filter(func(a: Avatar) -> bool: return not a.dead)
			var spots: Array = alive.map(func(a: Avatar) -> Vector3: return a.global_position)
			spots.shuffle()
			for i in alive.size():
				(alive[i] as Avatar).teleport.rpc((spots[i] as Vector3) + Vector3.UP * 0.3)
			Net.announce("MUSICAL CHAIRS")


@rpc("authority", "call_local", "reliable")
func _ev_bomb(id: int, secs: float) -> void:
	if _bomb_label:
		_bomb_label.queue_free()
		_bomb_label = null
	var av: Avatar = game.avatars.get(id)
	if id == 0 or av == null:
		return
	_bomb_label = Art.label(av, "BOMB", Vector3.UP * (2.6 / maxf(av.size, 0.5)), 0.016, Art.P_RED)
	Sfx.at(game, "hiss", av.global_position, 0.0)
	if id == Net.me():
		game.banner("YOU HAVE THE BOMB\nRUN INTO SOMEONE (%.0fs)" % secs, 2.0)


@rpc("authority", "call_local", "reliable")
func _ev_duck(pos: Vector3) -> void:
	GiantFx.warn(game, pos, 10.0)
	var d := Node3D.new()
	game.add_child(d)
	d.position = pos + Vector3.UP * 130.0
	var yel := Color("#ffd23f")
	Art.part(d, Art.sphere(6.0, 10), yel, Vector3(0, 0, 0), Vector3(1.15, 0.8, 1))
	Art.part(d, Art.sphere(3.6, 9), yel, Vector3(0, 5.6, -2.6))
	Art.part(d, Art.box(Vector3(2.2, 0.8, 2.6)), Art.P_ORANGE, Vector3(0, 5.2, -6.6))
	var tw := d.create_tween()
	tw.tween_property(d, "position", pos, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(d.queue_free)
	Sfx.at(game, "slide_whistle_up", pos, 6.0, 0.0, 0.5)


func _physics_process(delta: float) -> void:
	_update_hud()
	if not multiplayer.is_server():
		return
	_bot_tricks(delta)
	if _bomb_id == 0:
		return
	var av: Avatar = game.avatars.get(_bomb_id)
	_bomb_t -= delta
	_bomb_cd -= delta
	if av == null or av.dead:
		_bomb_id = 0
		_ev_bomb.rpc(0, 0.0)
		return
	if _bomb_t <= 0.0:
		var pos := av.global_position
		_bomb_id = 0
		_ev_bomb.rpc(0, 0.0)
		game.props.explode(pos, 7.0, 34.0, _bomb_by)
		return
	if _bomb_cd > 0.0:
		return
	for o: Avatar in game.avatars.values():
		if o != av and not o.dead and o.global_position.distance_to(av.global_position) < BOMB_PASS_DIST:
			_bomb_id = o.pid
			_bomb_cd = 1.0
			_ev_bomb.rpc(o.pid, _bomb_t)
			break


func _update_hud() -> void:
	var me: Avatar = game.local_avatar()
	var lines: PackedStringArray = []
	if me:
		for k: String in me.hexes:
			var left := (int(me.hexes[k]) - Time.get_ticks_msec()) / 1000.0
			if left > 0.0:
				lines.append("%s %.0fs" % [Tricks.HEX_NAMES.get(k, k), ceilf(left)])
		_pie.visible = me.hexed("pie") or me.hexed("salt")
		if me.hexed("goggles") and game.cam:
			game.cam.wobble = maxf(game.cam.wobble, 0.5)
	_hud.text = "\n".join(lines)


## Solo play should still feel hostile: bots spend their own coins on you.
func _bot_tricks(delta: float) -> void:
	_bot_t -= delta
	if _bot_t > 0.0:
		return
	_bot_t = BOT_THINK * randf_range(0.7, 1.4)
	var bots: Array = Net.players.keys().filter(func(k: int) -> bool: return Net.is_bot(k))
	if bots.is_empty():
		return
	var id: int = bots.pick_random()
	var p: Dictionary = Net.players[id]
	var options: Array = Tricks.ITEMS.keys().filter(func(k: String) -> bool:
		return int(Tricks.ITEMS[k].price) <= int(p.coins) and str(Tricks.ITEMS[k].kind) in ["hex", "action"] \
			and not Tricks.ITEMS[k].get("untargeted", false))
	var targets: Array = Net.players.keys().filter(func(k: int) -> bool: return k != id and game.avatars.has(k))
	if options.is_empty() or targets.is_empty():
		return
	var item: String = options.pick_random()
	Net.give_coins(id, -int(Tricks.ITEMS[item].price))
	(p.bag as Array).append(item)
	do_use(id, item, targets.pick_random())
