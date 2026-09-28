class_name ItemVisuals
extends RefCounted

# Bare-bones polygon outlines shaped like the actual object, not just a
# generic blade triangle — sized up so they read clearly against the
# player/enemy body. `offset` lets a melee thrust push the shape forward
# along its own axis without rotating it (used for stabbing weapons).
static func draw(ci: CanvasItem, item_name: String, dir: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	match item_name:
		"knife":
			_draw_tapered(ci, dir, offset, [[0, 3], [7, 3], [8, 4.5], [20, 0.6]], Color(0.82, 0.82, 0.86))
		"pencil":
			_draw_tapered(ci, dir, offset, [[0, 2.5], [3, 2.5], [3, 3.2], [14, 3.2], [18, 0.4]], Color(0.92, 0.8, 0.3))
		"chair_leg":
			_draw_tapered(ci, dir, offset, [[0, 7], [6, 4.5], [12, 7.5], [18, 4], [30, 5.5], [44, 3]], Color(0.5, 0.35, 0.2))
		"bottle":
			_draw_tapered(ci, dir, offset, [[0, 7], [10, 7], [14, 3], [20, 2.2]], Color(0.3, 0.6, 0.42))
		"one_bullet", "pistol":
			_draw_gun(ci, dir, offset, 20.0, 4.5, 10.0, Color(0.2, 0.2, 0.24))
		"smg":
			_draw_gun(ci, dir, offset, 30.0, 5.5, 12.0, Color(0.15, 0.15, 0.2))
		"uzi":
			_draw_gun(ci, dir, offset, 22.0, 4.0, 9.0, Color(0.12, 0.12, 0.16))
		"bludgeon":
			_draw_gun(ci, dir, offset, 16.0, 5.0, 8.0, Color(0.3, 0.3, 0.32))
		_:
			pass


# A symmetric-along-the-axis outline (knife, pencil, chair leg, bottle):
# a profile of [distance-from-handle, half-width] pairs, mirrored top/bottom.
static func _draw_tapered(ci: CanvasItem, dir: Vector2, offset: Vector2, profile: Array, color: Color) -> void:
	var perp := dir.orthogonal()
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for p in profile:
		var along: float = p[0]
		var hw: float = p[1]
		top.append(dir * along + perp * hw + offset)
		bottom.append(dir * along - perp * hw + offset)
	var pts := PackedVector2Array()
	for v in top:
		pts.append(v)
	for i in range(bottom.size() - 1, -1, -1):
		pts.append(bottom[i])
	ci.draw_polygon(pts, PackedColorArray([color]))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, color.darkened(0.3), 1.3)


# An L-shaped gun silhouette: a barrel plus an angled grip.
static func _draw_gun(ci: CanvasItem, dir: Vector2, offset: Vector2, barrel_len: float, w: float, grip_len: float, color: Color) -> void:
	var perp := dir.orthogonal()
	var local := [
		Vector2(0, w),
		Vector2(barrel_len, w),
		Vector2(barrel_len, -w),
		Vector2(barrel_len * 0.45, -w),
		Vector2(barrel_len * 0.3, -w - grip_len),
		Vector2(barrel_len * 0.05, -w - grip_len),
		Vector2(barrel_len * 0.15, -w),
		Vector2(0, -w),
	]
	var pts := PackedVector2Array()
	for p in local:
		pts.append(dir * p.x + perp * p.y + offset)
	ci.draw_polygon(pts, PackedColorArray([color]))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, color.darkened(0.3), 1.3)
