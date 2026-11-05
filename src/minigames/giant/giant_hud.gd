class_name GiantHud
extends Control
## HUD for GIANT HUNT: clock, bind meter, eye status, role controls, and the
## giant's blindness overlay.

const BLIND_SHADER := preload("res://src/art/blind.gdshader")

var game: GiantGame
var _timer: Label
var _bind: ProgressBar
var _eyes: Label
var _info: Label
var _cross: Label
var _blind_mat: ShaderMaterial


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var blind := ColorRect.new()
	blind.set_anchors_preset(Control.PRESET_FULL_RECT)
	blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blind_mat = ShaderMaterial.new()
	_blind_mat.shader = BLIND_SHADER
	blind.material = _blind_mat
	add_child(blind)

	var top := Ui.vbox(4)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-180, 10)
	top.custom_minimum_size = Vector2(360, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_timer = Ui.label("5:00", 40, Ui.YELLOW)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_timer)
	var bl := Ui.label("BIND", 18)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(bl)
	_bind = Ui.bar(Color("#f4e1b0"))
	_bind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_bind)
	_eyes = Ui.label("", 20)
	_eyes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_eyes)

	_info = Ui.label("", 20)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info.offset_top = -90
	_info.offset_bottom = -20
	add_child(_info)

	_cross = Ui.label("+", 32)
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.position -= Vector2(8, 22)
	add_child(_cross)


func _process(_delta: float) -> void:
	if game == null:
		return
	var t := maxi(0, int(game.time_left))
	_timer.text = "%d:%02d" % [t / 60, t % 60]
	_bind.value = game.bind
	_eyes.text = "LEFT EYE %s    RIGHT EYE %s" % [_pips(int(game.eye_hp[0])), _pips(int(game.eye_hp[1]))]
	var me := game.local_avatar()
	var is_giant := Net.me() == game.giant_id
	_cross.visible = not is_giant and me != null and not me.dead
	if is_giant:
		_blind_mat.set_shader_parameter("left_blind", 1.0 if int(game.eye_hp[0]) <= 0 else 0.0)
		_blind_mat.set_shader_parameter("right_blind", 1.0 if int(game.eye_hp[1]) <= 0 else 0.0)
		if game.tripped > 0.0:
			_info.text = "YOU'RE DOWN! MASH %s TO STRUGGLE FREE" % InputSetup.label("primary")
		else:
			_info.text = "%s stomp %s   %s slap %s   %s ice pee %s   %s fire fart %s" % [
				InputSetup.label("primary"), _cd("stomp"), InputSetup.label("secondary"), _cd("slap"),
				InputSetup.label("ability_1"), _cd("pee"), InputSetup.label("ability_2"), _cd("fart")]
	elif me != null and me.dead:
		_info.text = "ghost mode: move to fly, %s up, %s down. Haunt them." % [InputSetup.label("jump"), InputSetup.label("sprint")]
	else:
		_info.text = "spears %d   %s throw at his EYES   %s plant rope stake (x2 = tripwire)   %s tie (when he's down)" % [
			int(game.spears.get(Net.me(), 0)), InputSetup.label("primary"), InputSetup.label("secondary"), InputSetup.label("interact")]


func _pips(hp: int) -> String:
	if hp <= 0:
		return "[BLIND]"
	return "[" + "#".repeat(hp) + "-".repeat(maxi(0, game.eye_max - hp)) + "]"


func _cd(k: String) -> String:
	var v := float(game.cds.get(k, 0.0))
	return "READY" if v <= 0.05 else "%.0fs" % ceilf(v)
