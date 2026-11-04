class_name Sfx
extends RefCounted
## Procedural cartoon sound effects. Nothing ships as an asset: every clip is
## synthesised once (on first use) into an AudioStreamWAV and cached, so the
## whole sound set costs ~0 MB on disk. Swap any entry for a real .wav later
## by dropping it in `res://audio/<name>.wav` (checked first).
##
##   Sfx.at(node, "land", pos)   3D one-shot, auto-freed
##   Sfx.ui("ding")              2D one-shot
##   Sfx.loop("wind")            looping stream for a player you own

const RATE := 22050
const MAX_VOICES := 40

static var _cache: Dictionary = {}
static var _voices := 0


static func stream(n: String) -> AudioStream:
	if _cache.has(n):
		return _cache[n]
	var path := "res://audio/%s.wav" % n
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else _make(n)
	_cache[n] = s
	return s


static func at(where: Node, n: String, pos: Vector3, db := 0.0, pitch_var := 0.08, pitch := 1.0) -> void:
	if where == null or not where.is_inside_tree() or _voices >= MAX_VOICES:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(n)
	p.volume_db = db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-pitch_var, pitch_var)))
	p.unit_size = 8.0
	p.max_distance = 80.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	var host: Node = where.get_tree().current_scene
	if host == null:
		host = where
	host.add_child(p)
	p.global_position = pos
	_voices += 1
	p.finished.connect(func() -> void:
		_voices -= 1
		p.queue_free())
	p.play()


static func ui(where: Node, n: String, db := 0.0, pitch := 1.0) -> void:
	if where == null or not where.is_inside_tree() or _voices >= MAX_VOICES:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream(n)
	p.volume_db = db
	p.pitch_scale = pitch
	where.add_child(p)
	_voices += 1
	p.finished.connect(func() -> void:
		_voices -= 1
		p.queue_free())
	p.play()


# --- synthesis -------------------------------------------------------------

static func _make(n: String) -> AudioStreamWAV:
	match n:
		"jump": return _render(0.16, func(t: float, _i: int) -> float:
			return _sq(t, lerpf(260.0, 620.0, t / 0.16)) * 0.35 * _env(t, 0.16, 0.005))
		"land": return _render(0.14, func(t: float, _i: int) -> float:
			return (sin(TAU * lerpf(110.0, 50.0, t / 0.14) * t) * 0.8 + _lp_noise(0.25) * 0.6) * _env(t, 0.14, 0.002))
		"step": return _render(0.06, func(t: float, _i: int) -> float:
			return _lp_noise(0.35) * _env(t, 0.06, 0.002) * 0.6)
		"bonk": return _render(0.18, func(t: float, _i: int) -> float:
			return (sin(TAU * lerpf(700.0, 220.0, sqrt(t / 0.18)) * t) + randf_range(-1, 1) * maxf(0.0, 1.0 - t * 60.0)) * 0.5 * _env(t, 0.18, 0.001))
		"pop": return _render(0.08, func(t: float, _i: int) -> float:
			return sin(TAU * lerpf(500.0, 1300.0, t / 0.08) * t) * 0.5 * _env(t, 0.08, 0.002))
		"whoosh": return _render(0.3, func(t: float, _i: int) -> float:
			return _bp_noise(0.08 + 0.3 * sin(PI * t / 0.3)) * sin(PI * t / 0.3) * 0.7)
		"knock": return _render(0.1, func(t: float, _i: int) -> float:
			return (sin(TAU * 190.0 * t) * 0.7 + _lp_noise(0.5) * 0.5) * _env(t, 0.1, 0.001))
		"thud": return _render(0.22, func(t: float, _i: int) -> float:
			return (sin(TAU * lerpf(80.0, 40.0, t / 0.22) * t) + _lp_noise(0.12) * 0.7) * 0.8 * _env(t, 0.22, 0.002))
		"death": return _render(0.75, func(t: float, _i: int) -> float:
			var f := lerpf(950.0, 220.0, t / 0.75) * (1.0 + sin(TAU * 7.0 * t) * 0.04)
			return sin(TAU * f * t) * 0.4 * _env(t, 0.75, 0.01))
		"slide_whistle_up": return _render(0.45, func(t: float, _i: int) -> float:
			return sin(TAU * lerpf(300.0, 1100.0, t / 0.45) * t) * 0.35 * _env(t, 0.45, 0.01))
		"poof": return _render(0.35, func(t: float, _i: int) -> float:
			return _lp_noise(0.2) * _env(t, 0.35, 0.005) * 0.8)
		"boom": return _render(1.1, func(t: float, _i: int) -> float:
			return (_lp_noise(0.06) * 1.4 + sin(TAU * 55.0 * t) * 0.6) * pow(1.0 - t / 1.1, 2.0) * minf(1.0, t * 400.0))
		"fart": return _render(0.8, func(t: float, _i: int) -> float:
			var f := 70.0 + sin(TAU * 9.0 * t) * 18.0 + randf() * 6.0
			return (_saw(t, f) * 0.6 + _lp_noise(0.2) * 0.4) * _env(t, 0.8, 0.02) * 0.8)
		"slap": return _render(0.12, func(t: float, _i: int) -> float:
			return randf_range(-1, 1) * pow(maxf(0.0, 1.0 - t / 0.12), 4.0))
		"hiss": return _render(0.8, func(t: float, _i: int) -> float:
			return randf_range(-1, 1) * 0.25 * _env(t, 0.8, 0.05))
		"splash": return _render(0.5, func(t: float, _i: int) -> float:
			return _bp_noise(0.3) * _env(t, 0.5, 0.004) * 0.9)
		"ding": return _render(0.5, func(t: float, _i: int) -> float:
			var f := 988.0 if t < 0.1 else (1319.0 if t < 0.2 else 1976.0)
			return sin(TAU * f * t) * 0.35 * _env(t, 0.5, 0.003))
		"coin": return _render(0.22, func(t: float, _i: int) -> float:
			return _sq(t, 988.0 if t < 0.07 else 1319.0) * 0.22 * _env(t, 0.22, 0.002))
		"boing": return _render(0.4, func(t: float, _i: int) -> float:
			return sin(TAU * 200.0 * t + 6.0 * sin(TAU * 14.0 * t)) * 0.5 * _env(t, 0.4, 0.002))
		"click": return _render(0.03, func(t: float, _i: int) -> float:
			return randf_range(-1, 1) * maxf(0.0, 1.0 - t * 40.0) * 0.6)
		"wind": return _render(2.0, func(t: float, _i: int) -> float:
			return _bp_noise(0.04 + 0.02 * sin(TAU * 0.5 * t)) * 0.8, true)
		"scrape": return _render(1.0, func(_t: float, _i: int) -> float:
			return _bp_noise(0.25) * 0.4, true)
		"squish": return _render(0.2, func(t: float, _i: int) -> float:
			return (_lp_noise(0.3) * 0.6 + sin(TAU * lerpf(300.0, 120.0, t / 0.2) * t) * 0.4) * _env(t, 0.2, 0.004))
	return _render(0.05, func(_t: float, _i: int) -> float: return 0.0)


static var _lp := 0.0
static var _bp1 := 0.0
static var _bp2 := 0.0


static func _lp_noise(k: float) -> float:
	_lp += (randf_range(-1, 1) - _lp) * k
	return _lp * 2.0


static func _bp_noise(k: float) -> float:
	_bp1 += (randf_range(-1, 1) - _bp1) * k
	_bp2 += (_bp1 - _bp2) * k
	return (_bp1 - _bp2) * 3.0


static func _env(t: float, len: float, attack: float) -> float:
	return minf(1.0, t / maxf(attack, 0.0001)) * pow(maxf(0.0, 1.0 - t / len), 1.6)


static func _sq(t: float, f: float) -> float:
	return 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0


static func _saw(t: float, f: float) -> float:
	return fmod(t * f, 1.0) * 2.0 - 1.0


static func _render(secs: float, f: Callable, looped := false) -> AudioStreamWAV:
	var n := int(secs * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	_lp = 0.0
	_bp1 = 0.0
	_bp2 = 0.0
	for i in n:
		var v := clampf(float(f.call(float(i) / RATE, i)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	return w
