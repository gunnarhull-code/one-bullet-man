class_name Wall
extends Node2D

# "solid" blocks movement, vision, and bullets outright. "soft" (drywall)
# blocks movement and vision the same as solid, but bullets/thrown items
# punch through it at reduced effect instead of stopping dead.
var size: Vector2 = Vector2(40, 400)
var wall_material: String = "solid"


func get_rect() -> Rect2:
	return Rect2(position - size / 2.0, size)


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	if wall_material == "solid":
		draw_rect(rect, Color(0.22, 0.21, 0.24))
		_draw_courses(rect, 26.0, Color(0.13, 0.12, 0.14))
	else:
		draw_rect(rect, Color(0.62, 0.53, 0.4))
		_draw_panels(rect, 90.0, Color(0.47, 0.39, 0.29))
	draw_rect(rect, Color(0, 0, 0, 0.4), false, 2.0)


# Brick/block courses — a few horizontal seams with staggered vertical
# joints, so a solid wall reads as masonry instead of a flat gray slab.
func _draw_courses(rect: Rect2, spacing: float, line_color: Color) -> void:
	var y := rect.position.y + spacing
	var row := 0
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color, 1.2)
		var offset: float = spacing * 0.5 if row % 2 == 0 else 0.0
		var x := rect.position.x + offset
		while x < rect.end.x:
			draw_line(Vector2(x, y - spacing), Vector2(x, y), line_color, 1.0)
			x += spacing
		y += spacing
		row += 1


# Drywall panel joints — sparser vertical-only seams.
func _draw_panels(rect: Rect2, spacing: float, line_color: Color) -> void:
	var x := rect.position.x + spacing
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), line_color, 1.0)
		x += spacing
