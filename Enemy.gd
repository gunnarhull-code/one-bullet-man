class_name Enemy
extends Node2D

const PANIC_TRIGGER_RANGE := 45.0
const LONELY_PATIENCE := 3.0

var etype: String = "switchblade"
var personality: String = ""
var weapon_visual: String = "knife"

var radius: float = 14.0
var color: Color = Color.WHITE
var speed: float = 130.0
var hits_left: float = 1.0
var damage: float = 10.0
var drop: String = "knife"

var crippled: bool = false
var crippled_timer: float = 0.0

var bleed_ticks: int = 0
var bleed_damage: float = 0.0
var bleed_timer: float = 0.0
var bleed_interval: float = 0.4

# spawn walk-in: enemies arrive as a group and don't act until they've
# actually walked onto the visible arena and "notice" you
var aware: bool = false
var inward_dir: Vector2 = Vector2.ZERO
var arena_size: Vector2 = Vector2(960, 540)

# melee (switchblade, bruiser, and a panicking shooter)
var melee_range: float = 30.0
var circle_range: float = 90.0
var circle_time: float = 0.8
var raise_time: float = 0.25
var charge_time: float = 0.16
var charge_speed_mult: float = 3.0
var attack_cooldown_time: float = 0.45
var charge_dir: Vector2 = Vector2.RIGHT
var hit_this_charge: bool = false
var panicking: bool = false

# shooter
var preferred_range: float = 230.0
var fire_interval: float = 1.1
var telegraph_time: float = 0.22
var lonely_timer: float = 0.0

var facing: Vector2 = Vector2.RIGHT
var state: String = "chase"
var state_timer: float = 0.0


func apply_bleed(ticks: int, dmg_per_tick: float) -> void:
	bleed_ticks = ticks
	bleed_damage = dmg_per_tick
	bleed_timer = bleed_interval


func update(delta: float, player_pos: Vector2, any_other_alive: bool, can_attack: bool) -> Dictionary:
	var result := {"melee_hit": false, "fire": false, "bled_out": false}

	if bleed_ticks > 0:
		bleed_timer -= delta
		if bleed_timer <= 0.0:
			bleed_timer = bleed_interval
			bleed_ticks -= 1
			hits_left -= bleed_damage
			if hits_left <= 0.0:
				result.bled_out = true
				return result

	if not aware:
		position += inward_dir * speed * delta
		var inset := 10.0
		if position.x > inset and position.x < arena_size.x - inset and position.y > inset and position.y < arena_size.y - inset:
			aware = true
		queue_redraw()
		return result

	if crippled:
		crippled_timer -= delta
		if crippled_timer <= 0.0:
			crippled = false
		queue_redraw()
		return result

	if etype == "shooter" and not panicking:
		var dist := position.distance_to(player_pos)
		if dist < PANIC_TRIGGER_RANGE:
			panicking = true
			state = "chase"
		else:
			result.fire = update_shooter_ai(delta, player_pos, any_other_alive)
			queue_redraw()
			return result

	result.melee_hit = update_melee_ai(delta, player_pos, can_attack)
	queue_redraw()
	return result


func update_melee_ai(delta: float, player_pos: Vector2, can_attack: bool) -> bool:
	var to_player := player_pos - position
	var dist := to_player.length()
	if dist > 1.0:
		facing = to_player.normalized()

	match state:
		"chase":
			if dist <= melee_range:
				if can_attack:
					if dist <= melee_range * 0.55:
						state = "jab"
						state_timer = raise_time * 0.6
					else:
						state = "raise"
						state_timer = raise_time
			elif personality == "circler" and dist <= circle_range:
				state = "circle"
				state_timer = circle_time
			else:
				position += facing * speed * delta
		"circle":
			var tangent := to_player.orthogonal().normalized()
			position += tangent * speed * 0.75 * delta
			if dist > circle_range + 15.0:
				position += facing * speed * 0.4 * delta
			elif dist < circle_range - 15.0:
				position -= facing * speed * 0.4 * delta
			state_timer -= delta
			if state_timer <= 0.0 and can_attack:
				state = "raise"
				state_timer = raise_time
		"jab":
			state_timer -= delta
			if state_timer <= 0.0:
				state = "cooldown"
				state_timer = attack_cooldown_time * 0.7
				return position.distance_to(player_pos) <= melee_range * 1.2
		"raise":
			state_timer -= delta
			if state_timer <= 0.0:
				charge_dir = facing
				state = "charge"
				state_timer = charge_time
				hit_this_charge = false
		"charge":
			position += charge_dir * speed * charge_speed_mult * delta
			state_timer -= delta
			var hit := false
			if not hit_this_charge and position.distance_to(player_pos) <= melee_range * 1.3:
				hit_this_charge = true
				hit = true
			if state_timer <= 0.0:
				state = "cooldown"
				state_timer = attack_cooldown_time
			return hit
		"cooldown":
			state_timer -= delta
			if state_timer <= 0.0:
				state = "chase"
	return false


func update_shooter_ai(delta: float, player_pos: Vector2, any_other_alive: bool) -> bool:
	var to_player := player_pos - position
	var dist := to_player.length()
	if dist > 1.0:
		facing = to_player.normalized()

	match state:
		"position":
			if personality != "showoff" and dist < preferred_range - 20.0 and dist > 1.0:
				position -= facing * speed * delta
			elif dist > preferred_range + 20.0:
				position += facing * speed * delta
			elif dist > 1.0:
				position += facing.orthogonal() * speed * 0.3 * delta
			state_timer -= delta
			if state_timer <= 0.0:
				if personality == "coward" and not any_other_alive:
					lonely_timer += 0.3
					state_timer = 0.3
					if lonely_timer >= LONELY_PATIENCE:
						lonely_timer = 0.0
						state = "telegraph"
						state_timer = telegraph_time
				else:
					lonely_timer = 0.0
					state = "telegraph"
					state_timer = telegraph_time
		"telegraph":
			state_timer -= delta
			if state_timer <= 0.0:
				state = "position"
				state_timer = fire_interval
				return true
	return false


func is_telegraphing() -> bool:
	return state == "raise" or state == "telegraph" or state == "jab"


func take_hit(power: float) -> bool:
	if crippled:
		return true
	hits_left -= power
	return hits_left <= 0.0


func cripple(duration: float) -> void:
	crippled = true
	crippled_timer = duration
	queue_redraw()


func _draw() -> void:
	if not aware:
		CharacterShape.draw(self, radius, color.darkened(0.35), inward_dir)
		return

	var c := color
	if crippled:
		c = c.lightened(0.55)
	elif state == "telegraph":
		c = c.lightened(0.4)
	if bleed_ticks > 0:
		c = c.lerp(Color(0.7, 0.05, 0.05), 0.35)
	CharacterShape.draw(self, radius, c, facing)

	if state == "raise":
		ItemVisuals.draw(self, weapon_visual, facing.rotated(-1.1))
	elif state == "charge" or state == "jab":
		ItemVisuals.draw(self, weapon_visual, facing)
	elif state == "telegraph":
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 2.0)
