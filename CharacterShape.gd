class_name CharacterShape
extends RefCounted

# A simple forward-pointing "shield" pentagon instead of a plain circle —
# reads as a body with a front, no sprite work needed.
static func draw(ci: CanvasItem, radius: float, color: Color, facing: Vector2) -> void:
	var dir := facing
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var perp := dir.orthogonal()
	var pts := PackedVector2Array([
		dir * radius * 1.3,
		dir * radius * 0.25 + perp * radius * 0.95,
		dir * -radius * 0.9 + perp * radius * 0.75,
		dir * -radius * 0.9 - perp * radius * 0.75,
		dir * radius * 0.25 - perp * radius * 0.95,
	])
	ci.draw_polygon(pts, PackedColorArray([color]))
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), color.darkened(0.35), 1.5)
