class_name Geometry
extends RefCounted

# Shared line/rect math for walls: vision blocking, bullet penetration, and
# circle-vs-wall movement collision all build on the same segment-vs-rect
# primitive so the three stay consistent with each other.

# Slab method: intersect a segment (from -> to) against an axis-aligned rect.
# Returns [t_enter, t_exit] in 0..1 along the segment, or [] if it never
# enters the rect.
static func segment_vs_rect(from: Vector2, to: Vector2, rect: Rect2) -> Array:
	var d := to - from
	var t0 := 0.0
	var t1 := 1.0
	for axis in range(2):
		var o: float = from[axis]
		var dd: float = d[axis]
		var lo: float = rect.position[axis]
		var hi: float = rect.end[axis]
		if abs(dd) < 0.0001:
			if o < lo or o > hi:
				return []
		else:
			var ta := (lo - o) / dd
			var tb := (hi - o) / dd
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = max(t0, ta)
			t1 = min(t1, tb)
			if t0 > t1:
				return []
	return [t0, t1]


# Vision/LOS: both wall materials are opaque — drywall blocks sight even
# though bullets can punch through it.
static func is_segment_blocked(from: Vector2, to: Vector2, walls: Array) -> bool:
	for w in walls:
		if not segment_vs_rect(from, to, w.get_rect()).is_empty():
			return true
	return false


# Bullet/thrown-item penetration: a solid wall stops a shot outright at
# solid_t (0..1 along the segment); each soft ("drywall") crossing lets it
# through but should reduce whatever effect the caller applies.
static func raycast_walls(from: Vector2, to: Vector2, walls: Array) -> Dictionary:
	var nearest_solid_t := 1.0
	var soft_crossings := 0
	for w in walls:
		var hit: Array = segment_vs_rect(from, to, w.get_rect())
		if hit.is_empty():
			continue
		if w.wall_material == "solid":
			nearest_solid_t = min(nearest_solid_t, hit[0])
		else:
			soft_crossings += 1
	return {"solid_t": nearest_solid_t, "soft_crossings": soft_crossings}


# Movement collision: push a circle out of a rect it's overlapping, by
# clamping to the rect's nearest point and shoving out along that normal.
static func resolve_circle_vs_rect(pos: Vector2, radius: float, rect: Rect2) -> Vector2:
	var closest := Vector2(
		clamp(pos.x, rect.position.x, rect.end.x),
		clamp(pos.y, rect.position.y, rect.end.y)
	)
	var diff := pos - closest
	var dist := diff.length()
	if dist >= radius:
		return pos
	var push_dir: Vector2 = diff / dist if dist > 0.0001 else Vector2.UP
	return closest + push_dir * radius
