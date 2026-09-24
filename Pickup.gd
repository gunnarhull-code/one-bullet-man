class_name Pickup
extends Node2D

var item_name: String = "knife"
var uses: int = 4
var radius: float = 10.0
var color: Color = Color.WHITE
var label: String = "Knife"


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 4.0, Color(1, 1, 1, 0.08))
	ItemVisuals.draw(self, item_name, Vector2.RIGHT)
