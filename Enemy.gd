class_name Enemy
extends Node2D

const PANIC_TRIGGER_RANGE := 55.0
const PANIC_RELEASE_MARGIN := 70.0
const LONELY_PATIENCE := 3.0

# Knockback recovery: a light hit gives a quick flinch-turn, a heavy one
# (a thrown heavy item, a grapple-throw, or a punished dodge) knocks the
# enemy into a full 180-degree spin and a much longer recovery. Trip +
# assassinate reuses this: a hit connecting on a "knockdown" enemy is
# always a kill (see take_hit).
const STAGGER_KNOCKBACK_THRESHOLD := 140.0
const STAGGER_RECOVER_TIME := 0.28
const KNOCKDOWN_RECOVER_TIME := 1.1

# Unarmed strikes stun instead of knocking back — hands are the control
# tool, weapons are the damage/knockdown tool.
const STUN_DURATION := 2.2

# Doesn't know exactly where the player is: heads for the one doorway
# waypoint and pauses to peek before committing to cross it.
const DOORWAY_ARRIVE_DIST := 50.0
const DOORWAY_PEEK_TIME := 0.9
const BLIND_APPROACH_SPEED_MULT := 0.75

var etype: String = "switchblade"
var personality: String = ""
var weapon_visual: String = "knife"

var radius: float = 14.0
var color: Color = Color.WHITE
var speed: float = 130.0
var hits_left: float = 1.0
var damage: float = 10.0
var drop: String = "knife"
var drop_chance: float = 1.0 # guns are rarer drops than melee weapons
var hit_push: float = 20.0 # how hard landing a melee hit shoves the player back

var crippled: bool = false
var crippled_timer: float = 0.0

var stunned: bool = false
var stun_timer: float = 0.0

var bleed_ticks: int = 0
var bleed_damage: float = 0.0
var bleed_timer: float = 0.0
var bleed_interval: float = 0.4

var knock_state: String = "" # "", "stagger", "knockdown"
var knock_timer: float = 0.0
var knock_duration: float = 0.0
var knock_dir: Vector2 = Vector2.RIGHT

# Grapple: frozen and dragged around by the player while grabbed.
var grappled: bool = false
var choke_progress: float = 0.0

# spawn walk-in: kept for a possible future off-screen entrance, but
# encounter-spawned enemies start aware=true and skip this entirely.
var aware: bool = false
var inward_dir: Vector2 = Vector2.ZERO
var arena_size: Vector2 = Vector2(1920, 1080)

# Line-of-sight-driven awareness: no telepathy — an enemy that can't see
# the player heads for the last place it saw them (or the doorway, if it
# never has) instead of beelining at their real position.
var doorway_waypoint: Vector2 = Vector2.ZERO
var last_known_player_pos: Vector2 = Vector2.ZERO
var has_last_known: bool = false
var doorway_peek_timer: float = 0.0
var peek_done: bool = false

# Patrol: before ever spotting the player, wander near the spawn point
# instead of standing frozen or already knowing to march on the doorway.
const PATROL_RADIUS := 160.0
const PATROL_SPEED_MULT := 0.5
const PATROL_ARRIVE_DIST := 12.0
const PATROL_PAUSE_TIME := 1.5
var patrol_home: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
var has_patrol_target: bool = false
var patrol_pause_timer: float = 0.0

# melee (switchblade, bruiser, and a panicking shooter) — a slow, obvious
# windup ("raise"), then a short sprinting commitment ("charge") that's
# fast but brief enough to dodge, then a real recovery window ("cooldown")
# before the next move. Timings get a little jitter so the rhythm doesn't
# feel metronomic.
var melee_range: float = 30.0
var circle_range: float = 90.0
var circle_time: float = 0.8
var raise_time: float = 0.4
var charge_time: float = 0.14
var charge_speed_mult: float = 3.6
var attack_cooldown_time: float = 0.65
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


func apply_knockback(dir: Vector2, force: float) -> void:
	if force <= 0.0 or crippled:
		return
	position += dir * force
	knock_dir = dir
	stunned = false
	state = "chase"
	state_timer = 0.0
	hit_this_charge = false
	if force >= STAGGER_KNOCKBACK_THRESHOLD:
		knock_state = "knockdown"
		knock_duration = KNOCKDOWN_RECOVER_TIME
	else:
		knock_state = "stagger"
		knock_duration = STAGGER_RECOVER_TIME
	knock_timer = knock_duration
	queue_redraw()


func apply_stun(duration: float) -> void:
	stunned = true
	stun_timer = duration
	knock_state = ""
	state = "chase"
	state_timer = 0.0
	queue_redraw()


# How far the body is turned off its normal facing right now, as a recovery
# animation: a stagger snaps back quickly, a knockdown spins a full 180
# into the hit, holds, then spins back up near the end of the recovery.
func _current_turn_angle() -> float:
	if knock_state == "":
		return 0.0
	var elapsed: float = knock_duration - knock_timer
	var t: float = clamp(elapsed / knock_duration, 0.0, 1.0)
	if knock_state == "stagger":
		return lerp(PI * 0.35, 0.0, t)
	var spin_frac := 0.22
	var recover_frac := 0.3
	if t < spin_frac:
		return lerp(0.0, PI, t / spin_frac)
	elif t > 1.0 - recover_frac:
		return lerp(PI, 0.0, (t - (1.0 - recover_frac)) / recover_frac)
	return PI


# A little randomness on attack timing so enemies don't all swing on the
# same rigid metronome.
func _jitter(base: float) -> float:
	return base * randf_range(0.85, 1.2)


func reacts_passively_to_hostage() -> bool:
	return personality == "circler" or personality == "coward" or personality == "sniper"


func update(delta: float, ctx: Dictionary, can_attack: bool) -> Dictionary:
	var result := {"melee_hit": false, "fire": false, "bled_out": false}
	var player_pos: Vector2 = ctx.get("player_pos", Vector2.ZERO)
	var enemies_ref: Array = ctx.get("enemies", [])
	var walls_ref: Array = ctx.get("walls", [])
	var can_see: bool = ctx.get("can_see", true)
	var hostage: bool = ctx.get("hostage", false)

	if bleed_ticks > 0:
		bleed_timer -= delta
		if bleed_timer <= 0.0:
			bleed_timer = bleed_interval
			bleed_ticks -= 1
			hits_left -= bleed_damage
			if hits_left <= 0.0:
				result.bled_out = true
				return result

	if grappled:
		queue_redraw()
		return result

	if not aware:
		position += inward_dir * speed * delta
		var inset := 10.0
		if position.x > inset and position.x < arena_size.x - inset and position.y > inset and position.y < arena_size.y - inset:
			aware = true
		queue_redraw()
		return result

	if stunned:
		stun_timer -= delta
		if stun_timer <= 0.0:
			stunned = false
		queue_redraw()
		return result

	if knock_state != "":
		knock_timer -= delta
		if knock_timer <= 0.0:
			knock_state = ""
		queue_redraw()
		return result

	if crippled:
		crippled_timer -= delta
		if crippled_timer <= 0.0:
			crippled = false
		queue_redraw()
		return result

	if can_see:
		last_known_player_pos = player_pos
		has_last_known = true
	elif has_last_known:
		# lost sight after having found them — go investigate, funneling
		# through the doorway and peeking before committing.
		result = update_blind_approach(delta, player_pos, walls_ref)
		queue_redraw()
		return result
	else:
		# never spotted the player at all — nothing to investigate yet,
		# just patrol near the spawn point.
		result = update_patrol(delta)
		queue_redraw()
		return result

	if hostage and reacts_passively_to_hostage():
		result = update_hostage_hesitation(delta, player_pos)
		queue_redraw()
		return result

	if etype == "shooter":
		var dist_to_player := position.distance_to(player_pos)
		if not panicking and dist_to_player < PANIC_TRIGGER_RANGE:
			panicking = true
			state = "chase"
		elif panicking and dist_to_player > PANIC_TRIGGER_RANGE + PANIC_RELEASE_MARGIN and (state == "chase" or state == "cooldown"):
			# got some distance back — stop butting with the gun, resume
			# standing off and shooting instead of chasing forever.
			panicking = false
			state = "position"
			state_timer = 0.3
		if not panicking:
			result.fire = update_shooter_ai(delta, player_pos, enemies_ref)
			queue_redraw()
			return result

	result.melee_hit = update_melee_ai(delta, player_pos, can_attack)
	queue_redraw()
	return result


# Never spotted anyone: wander loosely around the spawn point, pausing
# between legs, until something actually gives the player away.
func update_patrol(delta: float) -> Dictionary:
	var result := {"melee_hit": false, "fire": false, "bled_out": false}
	state = "patrol"
	if not has_patrol_target:
		if patrol_pause_timer > 0.0:
			patrol_pause_timer -= delta
			return result
		patrol_target = patrol_home + Vector2(randf_range(-PATROL_RADIUS, PATROL_RADIUS), randf_range(-PATROL_RADIUS, PATROL_RADIUS))
		has_patrol_target = true

	var to_target := patrol_target - position
	var dist := to_target.length()
	if dist > PATROL_ARRIVE_DIST:
		facing = to_target.normalized()
		position += to_target.normalized() * speed * PATROL_SPEED_MULT * delta
	else:
		has_patrol_target = false
		patrol_pause_timer = PATROL_PAUSE_TIME
	return result


# No line of sight (but has seen the player before): head for wherever
# they were last seen, funneling through the doorway if that path is
# currently blocked, and pause to "peek" before committing to cross it.
func update_blind_approach(delta: float, player_pos: Vector2, walls_ref: Array) -> Dictionary:
	var result := {"melee_hit": false, "fire": false, "bled_out": false}
	var target_pos: Vector2 = last_known_player_pos if has_last_known else doorway_waypoint
	var route_target := target_pos
	var needs_doorway: bool = Geometry.is_segment_blocked(position, target_pos, walls_ref)
	if needs_doorway:
		route_target = doorway_waypoint

	state = "investigate"
	var to_target := route_target - position
	var dist := to_target.length()
	if dist > 1.0:
		facing = to_target.normalized()

	var near_doorway: bool = position.distance_to(doorway_waypoint) < DOORWAY_ARRIVE_DIST
	if not near_doorway:
		peek_done = false

	if needs_doorway and near_doorway and not peek_done:
		doorway_peek_timer += delta
		if doorway_peek_timer >= DOORWAY_PEEK_TIME:
			doorway_peek_timer = 0.0
			peek_done = true
	else:
		doorway_peek_timer = 0.0
		if dist > 4.0:
			position += to_target.normalized() * speed * BLIND_APPROACH_SPEED_MULT * delta

	return result


# The player is holding a hostage — a cautious personality backs off and
# holds rather than closing in or opening fire near their own guy.
func update_hostage_hesitation(delta: float, player_pos: Vector2) -> Dictionary:
	var result := {"melee_hit": false, "fire": false, "bled_out": false}
	var to_player := player_pos - position
	var dist := to_player.length()
	if dist > 1.0:
		facing = to_player.normalized()
	state = "hesitate"
	var safe_dist: float = max(melee_range * 2.5, preferred_range)
	if dist < safe_dist and dist > 1.0:
		position -= facing * speed * 0.6 * delta
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
						state_timer = _jitter(raise_time * 0.6)
					else:
						state = "raise"
						state_timer = _jitter(raise_time)
				else:
					# someone else already has the attack token — pace
					# instead of freezing solid until it's free.
					state = "circle"
					state_timer = circle_time
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
				state_timer = _jitter(raise_time)
		"jab":
			state_timer -= delta
			if state_timer <= 0.0:
				state = "cooldown"
				state_timer = _jitter(attack_cooldown_time * 0.7)
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
				state_timer = _jitter(attack_cooldown_time)
			return hit
		"cooldown":
			state_timer -= delta
			if state_timer <= 0.0:
				state = "chase"
	return false


func update_shooter_ai(delta: float, player_pos: Vector2, enemies_ref: Array) -> bool:
	var any_other_alive: bool = enemies_ref.size() > 1
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
				if not has_clear_shot(player_pos, enemies_ref):
					state_timer = 0.25 # an ally's in the way — hold and recheck shortly
				elif personality == "coward" and not any_other_alive:
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
				if not has_clear_shot(player_pos, enemies_ref):
					state_timer = 0.2
					return false
				state_timer = fire_interval
				return true
	return false


# Never fire through a friendly standing in the way of the player.
func has_clear_shot(player_pos: Vector2, enemies_ref: Array) -> bool:
	var to_player: Vector2 = player_pos - position
	var dist: float = to_player.length()
	if dist < 1.0:
		return true
	var dir: Vector2 = to_player / dist
	for other in enemies_ref:
		if other == self or not other.aware or other.grappled:
			continue
		var to_other: Vector2 = other.position - position
		var proj: float = to_other.dot(dir)
		if proj <= 6.0 or proj >= dist - 6.0:
			continue
		var perp: float = (to_other - dir * proj).length()
		if perp < other.radius + 12.0:
			return false
	return true


func is_telegraphing() -> bool:
	return state == "raise" or state == "telegraph" or state == "jab"


# Crippled (a called-but-not-headshot precision hit) or knocked down
# (tripped) — either way, defenseless: any hit at all finishes them.
func take_hit(power: float) -> bool:
	if crippled or knock_state == "knockdown":
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

	if grappled:
		var gc := color.lerp(Color(0.7, 0.08, 0.08), 0.35)
		CharacterShape.draw(self, radius, gc, facing)
		if choke_progress > 0.0:
			draw_arc(Vector2.ZERO, radius + 8.0, -PI / 2.0, -PI / 2.0 + TAU * choke_progress, 20, Color(1, 0.25, 0.25, 0.9), 2.5)
		return

	if stunned:
		var wobble: float = sin(stun_timer * 9.0) * 0.3
		var dazed_facing := facing.rotated(wobble)
		CharacterShape.draw(self, radius, color.lightened(0.3), dazed_facing)
		_draw_dazed_mark()
		return

	var draw_facing := facing
	if knock_state != "":
		var cross_z: float = facing.cross(knock_dir)
		var turn_sign: float = 1.0 if cross_z >= 0.0 else -1.0
		draw_facing = facing.rotated(turn_sign * _current_turn_angle())

	var c := color
	if knock_state == "knockdown":
		c = c.darkened(0.25)
	elif crippled:
		c = c.lightened(0.55)
	elif state == "telegraph":
		c = c.lightened(0.4)
	elif state == "cooldown":
		c = c.darkened(0.15) # visibly recovering — this is the window to counter
	elif state == "investigate":
		c = c.darkened(0.1)
	if bleed_ticks > 0:
		c = c.lerp(Color(0.7, 0.05, 0.05), 0.35)
	CharacterShape.draw(self, radius, c, draw_facing)

	if knock_state != "":
		return

	if state == "raise":
		ItemVisuals.draw(self, weapon_visual, facing.rotated(-1.1))
		var wind_t: float = 1.0 - clamp(state_timer / raise_time, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 6.0 + wind_t * 4.0, 0.0, TAU, 16, Color(1.0, 0.75, 0.15, 0.35 + 0.4 * wind_t), 2.0)
	elif state == "charge" or state == "jab":
		ItemVisuals.draw(self, weapon_visual, facing)
	elif state == "telegraph":
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 2.0)
	elif state == "investigate" and doorway_peek_timer > 0.0 and not peek_done:
		_draw_peek_mark()


# A little zigzag instead of another circle/arc — "dazed."
func _draw_dazed_mark() -> void:
	var y := -radius - 10.0
	var pts := PackedVector2Array()
	for i in range(7):
		var x: float = -9.0 + float(i) * 3.0
		var yy: float = y + (2.0 if i % 2 == 0 else -2.0)
		pts.append(Vector2(x, yy))
	draw_polyline(pts, Color(1.0, 0.9, 0.3, 0.9), 1.6)


# A small chevron while paused at the doorway — "peeking around the edge."
func _draw_peek_mark() -> void:
	var y := -radius - 9.0
	draw_polyline(PackedVector2Array([Vector2(-4, y + 4), Vector2(0, y), Vector2(4, y + 4)]), Color(1, 1, 1, 0.6), 1.4)
