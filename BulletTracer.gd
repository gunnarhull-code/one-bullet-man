class_name BulletTracer
extends Node2D

# A fast fading streak so hitscan gunshots read as an actual visible bullet.
var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var life: float = 0.08
var max_life: float = 0.08
var color: Color = Color(1.0, 0.95, 0.55)
var width: float = 2.0


func update(delta: float) -> bool:
	life -= delta
	queue_redraw()
	return life <= 0.0


func _draw() -> void:
	var t: float = clamp(life / max_life, 0.0, 1.0)
	draw_line(start_pos, end_pos, Color(color.r, color.g, color.b, t), width)
	draw_circle(end_pos, 3.0 * t + 1.0, Color(1, 1, 1, t * 0.8))
