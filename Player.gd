class_name Player
extends Node2D

const BARE_HANDS_RANGE := 30.0
const BARE_HANDS_COOLDOWN := 0.22
const SPEED := 300.0
const DASH_SPEED := 780.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.4
const GRAPPLE_MOVE_MULT := 0.55
const MELEE_HALF_ANGLE := 1.212

var radius: float = 12.0
var health: float = 100.0
var max_health: float = 100.0

var held_item: String = "" # "" = bare hands
var held_uses: int = 0

var aim_dir: Vector2 = Vector2.RIGHT
var last_move_dir: Vector2 = Vector2.RIGHT

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var dash_is_lunge: bool = false
var invulnerable: bool = false

var action_cooldown_timer: float = 0.0

var is_swinging: bool = false
var swing_timer: float = 0.0
var swing_duration: float = 0.15
var swing_style: String = "swing" # "swing" (arc) or "thrust" (stab forward)
var swing_arc: float = 0.95 # half-angle (rad) the "swing" style rotates through — weight-scaled per item
var current_range: float = BARE_HANDS_RANGE
var current_arc_half_angle: float = MELEE_HALF_ANGLE # matches the held item's real hit-cone width

# Grapple/chokehold state — owned mechanically by Main (which also tracks
# the grabbed Enemy), mirrored here so movement/drawing can react to it.
var is_grappling: bool = false
var is_choking: bool = false


func reset(spawn_pos: Vector2) -> void:
	position = spawn_pos
	health = max_health
	held_item = "one_bullet"
	held_uses = 1
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	action_cooldown_timer = 0.0
	invulnerable = false
	is_swinging = false
	swing_timer = 0.0
	is_grappling = false
	is_choking = false
	queue_redraw()


func handle_input(delta: float) -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 0.001:
		aim_dir = to_mouse.normalized()

	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		move.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		move.y += 1
	if move.length() > 0.001:
		move = move.normalized()
		last_move_dir = move

	if dash_timer > 0.0:
		dash_timer -= delta
		position += dash_dir * DASH_SPEED * delta
	elif is_choking:
		pass # locked in place while choking someone out
	else:
		var spd: float = SPEED * GRAPPLE_MOVE_MULT if is_grappling else SPEED
		position += move * spd * delta

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if action_cooldown_timer > 0.0:
		action_cooldown_timer -= delta
	if is_swinging:
		swing_timer -= delta
		if swing_timer <= 0.0:
			is_swinging = false

	invulnerable = dash_timer > 0.0 and not dash_is_lunge

	queue_redraw()


func start_swing(duration: float, style: String = "swing", arc: float = 0.95) -> void:
	is_swinging = true
	swing_duration = duration
	swing_timer = duration
	swing_style = style
	swing_arc = arc


func try_dash() -> bool:
	if dash_cooldown_timer > 0.0 or is_grappling:
		return false
	dash_dir = last_move_dir
	dash_is_lunge = dash_dir.dot(aim_dir) > 0.4
	dash_timer = DASH_TIME
	dash_cooldown_timer = DASH_COOLDOWN
	return true


func try_action(cooldown: float) -> bool:
	if action_cooldown_timer > 0.0:
		return false
	action_cooldown_timer = cooldown
	return true


func action_ready() -> bool:
	return action_cooldown_timer <= 0.0


func consume_held_item() -> void:
	held_uses -= 1
	if held_uses <= 0:
		held_item = ""
		held_uses = 0


func pick_up(item_name: String, uses: int) -> void:
	held_item = item_name
	held_uses = uses


func take_damage(amount: float) -> void:
	if invulnerable:
		return
	health -= amount
	if health < 0.0:
		health = 0.0


func _draw() -> void:
	if current_range > 0.0 and not is_grappling:
		_draw_range_cone()

	CharacterShape.draw(self, radius, Color(0.92, 0.92, 0.88), aim_dir)

	var item_dir := aim_dir
	var item_offset := Vector2.ZERO
	if is_swinging:
		var t: float = 1.0 - (swing_timer / swing_duration)
		if swing_style == "thrust":
			var thrust_t: float = sin(clamp(t, 0.0, 1.0) * PI)
			item_offset = aim_dir * thrust_t * 16.0
		else:
			var swing_angle: float = lerp(-swing_arc, swing_arc, t)
			item_dir = aim_dir.rotated(swing_angle)
	if held_item != "":
		ItemVisuals.draw(self, held_item, item_dir, item_offset)


func _draw_range_cone() -> void:
	var segments := 10
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var a: float = -current_arc_half_angle + (2.0 * current_arc_half_angle) * (float(i) / float(segments))
		points.append(aim_dir.rotated(a) * current_range)
	draw_polygon(points, PackedColorArray([Color(1, 1, 1, 0.07)]))
	draw_polyline(points.slice(1, points.size()), Color(1, 1, 1, 0.22), 1.3)
