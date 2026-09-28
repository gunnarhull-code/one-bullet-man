class_name MuzzleFlash
extends Node2D

var dir: Vector2 = Vector2.RIGHT
var life: float = 0.07
var max_life: float = 0.07
var flash_size: float = 12.0


func update(delta: float) -> bool:
	life -= delta
	queue_redraw()
	return life <= 0.0


func _draw() -> void:
	var t: float = clamp(life / max_life, 0.0, 1.0)
	var perp := dir.orthogonal()
	var len_v: float = flash_size * (0.6 + 0.4 * t)
	var pts := PackedVector2Array([
		dir * len_v,
		dir * len_v * 0.35 + perp * flash_size * 0.4,
		dir * len_v * 0.55,
		dir * len_v * 0.35 - perp * flash_size * 0.4,
	])
	draw_polygon(pts, PackedColorArray([Color(1.0, 0.9, 0.5, t)]))
	draw_circle(Vector2.ZERO, flash_size * 0.28 * t, Color(1, 1, 0.8, t))
