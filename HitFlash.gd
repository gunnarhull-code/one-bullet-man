class_name HitFlash
extends Node2D

var life: float = 0.16
var max_life: float = 0.16
var max_radius: float = 20.0


func update(delta: float) -> bool:
	life -= delta
	queue_redraw()
	return life <= 0.0


func _draw() -> void:
	var t: float = 1.0 - clamp(life / max_life, 0.0, 1.0)
	var r: float = lerp(3.0, max_radius, t)
	var a: float = 1.0 - t
	draw_circle(Vector2.ZERO, r, Color(1, 1, 1, a * 0.85))
	draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 12, Color(1, 1, 1, a * 0.5), 2.0)
