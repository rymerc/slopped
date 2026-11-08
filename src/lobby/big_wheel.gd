class_name BigWheel
extends Node3D
## Giant wheel-of-fortune. Faces +Z. Segments = match modifiers.

signal spin_finished(index: int)

const RADIUS := 4.5

var segments: Array = PerkDB.MODIFIERS
var spinning := false
var _disc: Node3D


func _ready() -> void:
	# The stand is modelled (wheel_stand) and placed by the lobby into its Batch.
	_disc = Node3D.new()
	_disc.position = Vector3(0, 6.2, 0)
	add_child(_disc)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_disc_mesh()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(0.15, 0.15, 0.15)
	mi.material_override = m
	_disc.add_child(mi)
	# Rim, hub, pegs
	Art.part(_disc, Art.cyl(RADIUS + 0.25, RADIUS + 0.25, 0.3, 24), Art.INK, Vector3(0, 0, -0.18), Vector3.ONE, Vector3(90, 0, 0), false)
	Art.part(_disc, Art.cyl(0.6, 0.6, 0.4, 12), Art.GOLD, Vector3(0, 0, 0.1), Vector3.ONE, Vector3(90, 0, 0), true, 0.3)
	var seg := TAU / segments.size()
	for i in segments.size():
		var a := seg * i
		Art.part(_disc, Art.sphere(0.12, 6), Art.GOLD, Vector3(sin(a), cos(a), 0) * (RADIUS - 0.1) + Vector3(0, 0, 0.1))
		var mid := a + seg * 0.5
		var l := Art.label(_disc, str(segments[i].name), Vector3(sin(mid), cos(mid), 0) * RADIUS * 0.6 + Vector3(0, 0, 0.08), 0.0065, Color.WHITE, false)
		l.rotation.z = PI * 0.5 - mid
	# Pointer at top (not spinning)
	Art.part(self, Art.cyl(0.0, 0.4, 0.9, 6), Color("#e63946"), Vector3(0, 6.2 + RADIUS + 0.3, 0.35), Vector3.ONE, Vector3(180, 0, 0))
	Art.label(self, "SPIN TO START", Vector3(0, 6.2 + RADIUS + 1.4, 0), 0.02, Ui.YELLOW)


func _build_disc_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := TAU / segments.size()
	var steps := 6
	for i in segments.size():
		var c: Color = segments[i].color
		if i % 2 == 1:
			c = c.darkened(0.12)
		for s in steps:
			var a1 := seg * i + seg * s / steps
			var a2 := seg * i + seg * (s + 1) / steps
			for p: Vector3 in [Vector3.ZERO, Vector3(sin(a1), cos(a1), 0) * RADIUS, Vector3(sin(a2), cos(a2), 0) * RADIUS]:
				st.set_color(c)
				st.set_normal(Vector3.BACK)
				st.add_vertex(p)
	return st.commit()


## Spins so segment `index` ends under the pointer.
func spin_to(index: int, secs := 5.0) -> void:
	spinning = true
	var seg := TAU / segments.size()
	var target := seg * (index + 0.5) + TAU * 6.0
	_disc.rotation.z = fmod(_disc.rotation.z, TAU)
	var tw := create_tween()
	tw.tween_property(_disc, "rotation:z", target, secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_on_spun.bind(index))


func _on_spun(index: int) -> void:
	spinning = false
	spin_finished.emit(index)
