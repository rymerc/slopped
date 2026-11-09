class_name Ambience
extends RefCounted
## Diegetic audio: the music is coming from the buildings. Each emitter is a looping
## 3D player, so walking down Main Street crossfades piano into casino lounge, and
## the surf rises as you reach the coast. Loops are synthesised by art_src/make_audio.py.

const DIR := "res://assets/audio/%s.wav"


static func _stream(n: String) -> AudioStream:
	var s: AudioStreamWAV = load(DIR % n)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	return s


static func emitter(root: Node3D, n: String, pos: Vector3, bus: StringName, db := 0.0, reach := 45.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(n)
	p.bus = bus
	p.volume_db = db
	p.unit_size = reach * 0.22
	p.max_distance = reach
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.panning_strength = 0.6
	p.position = pos
	root.add_child(p)
	p.play()
	return p


## Town interiors as boxes (building centre, half size from art_src/blender/town.py
## and casino.py, rotated into world axes). Order matters: see build_island.
static func town_rooms() -> Array[AABB]:
	var out: Array[AABB] = []
	for r: Array in [[LobbyBuilder.SALOON, Vector3(13.0, 9.6, 9.0)], [LobbyBuilder.CASINO, Vector3(12.0, 9.0, 19.0)],
			[LobbyBuilder.SHERIFF, Vector3(9.5, 7.0, 8.0)], [LobbyBuilder.STORE, Vector3(8.5, 7.0, 7.0)],
			[LobbyBuilder.HOTEL, Vector3(12.0, 12.0, 7.5)]]:
		var c: Vector3 = r[0]
		var h: Vector3 = r[1]
		out.append(AABB(Vector3(c.x - h.x, c.y, c.z - h.z), Vector3(h.x * 2.0, h.y, h.z * 2.0)))
	return out


static func build_island(root: Node3D) -> RoomMuffle:
	var muffle := RoomMuffle.new()
	muffle.name = "RoomMuffle"
	muffle.rooms = town_rooms()
	root.add_child(muffle)
	muffle.add(emitter(root, "saloon_piano", LobbyBuilder.SALOON + Vector3(-9, 2, -1), &"Music", -2.0, 42.0), 0)
	muffle.add(emitter(root, "casino_lounge", LobbyBuilder.CASINO + Vector3(-2, 3, 0), &"Music", -2.0, 42.0), 1)
	muffle.add(emitter(root, "carnival_organ", Playground.CAROUSEL + Vector3(0, 3, 0), &"Music", 0.0, 60.0))
	muffle.add(emitter(root, "beach_ukulele", Playground.BAR2 + Vector3(0, 2, 0), &"Music", -2.0, 40.0))
	var cove := Vector3(Playground.BEACH_DIR.x, 0, Playground.BEACH_DIR.y) * 118.0
	muffle.add(emitter(root, "surf", cove + Vector3(0, Playground.SEA_Y + 2.0, 0), &"Ambience", 0.0, 70.0))
	for a: float in [0.2, 1.3, 2.9, 4.7, 5.6]:
		var p := Vector3(cos(a), 0, sin(a)) * 132.0 + Vector3(0, Playground.SEA_Y + 2.0, 0)
		muffle.add(emitter(root, "surf", p, &"Ambience", -5.0, 60.0))
	return muffle
