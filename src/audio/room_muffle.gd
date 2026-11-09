class_name RoomMuffle
extends Node
## Cheap occlusion for the diegetic music. The town's interiors are boxes; when a
## source and the listener (the active camera) are not in the same room, or one is
## indoors and the other out, the source is heard "through a wall": turned down and
## low-passed. Only the players' own volume and filter change, smoothly, so the
## mixer buses and the audio settings are untouched.

const DUCK_DB := -9.0
const CUTOFF_HZ := 900.0

var rooms: Array[AABB] = []
var _src: Array = []  # [player, room index or -1 outdoors, base volume_db, base cutoff]


func add(p: AudioStreamPlayer3D, room := -1) -> void:
	_src.append([p, room, p.volume_db, p.attenuation_filter_cutoff_hz])


func room_of(pos: Vector3) -> int:
	for i in rooms.size():
		if rooms[i].has_point(pos):
			return i
	return -1


## True when the source would currently be heard through a wall.
func muffled(i: int, listener: Vector3) -> bool:
	return int(_src[i][1]) != room_of(listener)


func sources() -> int:
	return _src.size()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	var k := clampf(delta * 3.0, 0.0, 1.0)
	for i in _src.size():
		var s: Array = _src[i]
		var p := s[0] as AudioStreamPlayer3D
		if not is_instance_valid(p):
			continue
		var through := muffled(i, at)
		p.volume_db = lerpf(p.volume_db, float(s[2]) + (DUCK_DB if through else 0.0), k)
		p.attenuation_filter_cutoff_hz = lerpf(p.attenuation_filter_cutoff_hz, CUTOFF_HZ if through else float(s[3]), k)
