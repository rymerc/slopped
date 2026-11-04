class_name Spear
extends Node3D
## Purely visual spear. Every peer simulates the same ballistic arc; only the
## host decides hits (GiantRules), then tells everyone where it landed.

var vel := Vector3.ZERO
var gravity := 12.0
var _life := 6.0
var _stuck := false


func _ready() -> void:
	Art.part(self, Art.cyl(0.045, 0.045, 1.5, 5), Color("#d9b27c"), Vector3.ZERO, Vector3.ONE, Vector3(90, 0, 0))
	Art.part(self, Art.cyl(0.0, 0.1, 0.32, 5), Color("#c0c6d0"), Vector3(0, 0, -0.9), Vector3.ONE, Vector3(-90, 0, 0))
	_orient()


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _stuck:
		return
	vel.y -= gravity * delta
	position += vel * delta
	_orient()


func _orient() -> void:
	if vel.length() < 0.1:
		return
	var up := Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
	basis = Basis.looking_at(vel, up)


func stick(at: Vector3) -> void:
	_stuck = true
	position = at
	_life = 4.0
