class_name EnemyProjectile
extends Node2D

var velocity: Vector2 = Vector2.ZERO
var radius: float = 5.0
var damage: float = 8.0
var life: float = 3.0

func update(delta: float) -> bool:
	position += velocity * delta
	life -= delta
	queue_redraw()
	return life <= 0.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.85, 0.2))
