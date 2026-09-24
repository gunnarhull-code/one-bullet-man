class_name PlayerProjectile
extends Node2D

var velocity: Vector2 = Vector2.ZERO
var radius: float = 8.0
var power: float = 1.0
var life: float = 0.7
var item_name: String = ""


func update(delta: float) -> bool:
	position += velocity * delta
	life -= delta
	queue_redraw()
	return life <= 0.0


func _draw() -> void:
	var dir := velocity.normalized() if velocity.length() > 0.001 else Vector2.RIGHT
	if item_name != "":
		ItemVisuals.draw(self, item_name, dir)
	else:
		draw_circle(Vector2.ZERO, radius, Color(0.8, 0.8, 0.8))
