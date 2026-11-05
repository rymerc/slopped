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


static func build_island(root: Node3D) -> void:
	emitter(root, "saloon_piano", LobbyBuilder.SALOON + Vector3(-9, 2, -1), &"Music", -2.0, 42.0)
	emitter(root, "casino_lounge", LobbyBuilder.CASINO + Vector3(-2, 3, 0), &"Music", -2.0, 42.0)
	emitter(root, "carnival_organ", Playground.CAROUSEL + Vector3(0, 3, 0), &"Music", 0.0, 60.0)
	emitter(root, "beach_ukulele", Playground.BAR2 + Vector3(0, 2, 0), &"Music", -2.0, 40.0)
	var cove := Vector3(Playground.BEACH_DIR.x, 0, Playground.BEACH_DIR.y) * 118.0
	emitter(root, "surf", cove + Vector3(0, Playground.SEA_Y + 2.0, 0), &"Ambience", 0.0, 70.0)
	for a: float in [0.2, 1.3, 2.9, 4.7, 5.6]:
		var p := Vector3(cos(a), 0, sin(a)) * 132.0 + Vector3(0, Playground.SEA_Y + 2.0, 0)
		emitter(root, "surf", p, &"Ambience", -5.0, 60.0)
