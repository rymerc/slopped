extends WorldBase
## Bare stage for tests/lm_preview.gd: ground, game lighting, one landmark.

var lm_id := "saloon"


func build_world() -> void:
	Lobby.apply_lighting(self)
	Terrain.build(self, func(_x: float, _z: float) -> float: return 0.0,
		func(_x: float, _z: float, _h: float, _n: Vector3) -> Color: return Color("#c9a26a"), 90.0, 6.0, false)
	var b := Batch.new()
	if Kit.has(lm_id):
		b.add(Kit.mesh(lm_id), Transform3D.IDENTITY)
	else:
		Kit.landmark(self, b, lm_id, Vector3.ZERO)
	b.commit(self)
	print("tris ", b.tris)
