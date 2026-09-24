class_name Player
extends Node2D

const BARE_HANDS_RANGE := 30.0
const BARE_HANDS_COOLDOWN := 0.22
const SPEED := 300.0
const DASH_SPEED := 780.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.4

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
var current_range: float = BARE_HANDS_RANGE

const MELEE_HALF_ANGLE := 1.212


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
	else:
		position += move * SPEED * delta

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


func start_swing(duration: float) -> void:
	is_swinging = true
	swing_duration = duration
	swing_timer = duration


func try_dash() -> void:
	if dash_cooldown_timer > 0.0:
		return
	dash_dir = last_move_dir
	dash_is_lunge = dash_dir.dot(aim_dir) > 0.4
	dash_timer = DASH_TIME
	dash_cooldown_timer = DASH_COOLDOWN


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
	if current_range > 0.0:
		_draw_range_cone()

	CharacterShape.draw(self, radius, Color(0.92, 0.92, 0.88), aim_dir)

	var item_dir := aim_dir
	if is_swinging:
		var t: float = 1.0 - (swing_timer / swing_duration)
		var swing_angle: float = lerp(-0.95, 0.95, t)
		item_dir = aim_dir.rotated(swing_angle)
	if held_item != "":
		ItemVisuals.draw(self, held_item, item_dir)


func _draw_range_cone() -> void:
	var segments := 10
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var a: float = -MELEE_HALF_ANGLE + (2.0 * MELEE_HALF_ANGLE) * (float(i) / float(segments))
		points.append(aim_dir.rotated(a) * current_range)
	draw_polygon(points, PackedColorArray([Color(1, 1, 1, 0.07)]))
	draw_polyline(points.slice(1, points.size()), Color(1, 1, 1, 0.22), 1.3)
