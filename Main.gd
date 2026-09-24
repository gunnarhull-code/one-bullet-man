extends Node2D

const ARENA_SIZE := Vector2(960, 540)

const BULLET_POINT_BLANK := 50.0
const BULLET_RANGE := 1200.0
const BULLET_HEAD_TOLERANCE := 0.5
const BULLET_BODY_TOLERANCE := 1.3
const CRIPPLE_DURATION := 2.5

const ENEMY_STATS := {
	"switchblade": {"hits": 1.0, "speed": 130.0, "radius": 14.0, "color": Color(0.85, 0.2, 0.2), "damage": 12.0, "drop": "knife"},
	"shooter": {"hits": 2.0, "speed": 70.0, "radius": 14.0, "color": Color(0.9, 0.6, 0.1), "damage": 8.0, "drop": "pistol"},
	"bruiser": {"hits": 9.0, "speed": 58.0, "radius": 20.0, "color": Color(0.55, 0.15, 0.65), "damage": 20.0, "drop": "smg"},
}

const SWITCHBLADE_PERSONALITIES := ["rusher", "rusher", "circler"]
const SHOOTER_PERSONALITIES := ["coward", "showoff", "sniper"]
const SHOOTER_PERSONALITY_STATS := {
	"coward": {"preferred_range": 240.0, "fire_interval": 1.3, "telegraph_time": 0.25, "damage_mult": 1.0},
	"showoff": {"preferred_range": 120.0, "fire_interval": 0.8, "telegraph_time": 0.18, "damage_mult": 0.75},
	"sniper": {"preferred_range": 320.0, "fire_interval": 2.0, "telegraph_time": 0.4, "damage_mult": 1.7},
}

# "type" governs the LEFT-CLICK (in-hand) behavior. Every item is ALSO
# throwable via right-click regardless of type, using throw_speed/throw_life.
const ITEM_STATS := {
	"one_bullet": {"type": "precision_gun", "uses": 1, "power": 1.0, "throw_speed": 480.0, "throw_life": 0.7, "color": Color(0.2, 0.2, 0.24), "label": "Your Gun"},
	"knife": {"type": "melee", "uses": 4, "power": 1.0, "range": 24.0, "cooldown": 0.18, "knockback": 0.0, "bleed_ticks": 3, "bleed_damage": 0.3, "throw_speed": 620.0, "throw_life": 0.9, "color": Color(0.82, 0.82, 0.86), "label": "Kitchen Knife"},
	"chair_leg": {"type": "melee", "uses": 3, "power": 1.6, "range": 46.0, "cooldown": 0.42, "knockback": 110.0, "throw_speed": 360.0, "throw_life": 0.55, "color": Color(0.5, 0.35, 0.2), "label": "Chair Leg"},
	"bludgeon": {"type": "melee", "uses": 2, "power": 1.0, "range": 28.0, "cooldown": 0.34, "knockback": 50.0, "throw_speed": 430.0, "throw_life": 0.6, "color": Color(0.3, 0.3, 0.32), "label": "Spent Gun"},
	"pencil": {"type": "melee", "uses": 1, "power": 2.0, "range": 20.0, "cooldown": 0.25, "knockback": 0.0, "throw_speed": 680.0, "throw_life": 0.8, "color": Color(0.92, 0.8, 0.3), "label": "Pencil"},
	"pistol": {"type": "ranged", "uses": 5, "power": 1.5, "cooldown": 0.32, "throw_speed": 480.0, "throw_life": 0.7, "color": Color(0.2, 0.2, 0.24), "label": "Pistol"},
	"smg": {"type": "ranged", "uses": 10, "power": 0.6, "cooldown": 0.09, "auto": true, "throw_speed": 420.0, "throw_life": 0.6, "color": Color(0.15, 0.15, 0.2), "label": "Compact SMG"},
	"bottle": {"type": "melee", "uses": 3, "power": 1.0, "range": 30.0, "cooldown": 0.3, "knockback": 30.0, "throw_speed": 760.0, "throw_life": 1.0, "color": Color(0.3, 0.6, 0.42), "label": "Bottle"},
}

# A continuous rotation of squads — no waiting for the screen to clear.
const SPAWN_QUEUE := [
	{"type": "switchblade", "count": 3},
	{"type": "shooter", "count": 2},
	{"type": "switchblade", "count": 2},
	{"type": "shooter", "count": 1},
	{"type": "switchblade", "count": 2},
	{"type": "bruiser", "count": 1},
	{"type": "switchblade", "count": 1},
	{"type": "shooter", "count": 2},
	{"type": "bruiser", "count": 1},
]
const SPAWN_INTERVAL := 4.0
const MAX_ALIVE := 12

const ENV_ITEMS := ["pencil", "bottle", "chair_leg"]
const ENV_PICKUP_COUNT := 2
const ENV_RESPAWN_TIME := 12.0
const INTERACT_RANGE := 46.0

var player: Player
var enemies: Array = []
var enemy_projectiles: Array = []
var player_projectiles: Array = []
var pickups: Array = []
var hit_flashes: Array = []
var melee_attack_token: Enemy = null

var state: String = "RUNNING"
var loop_count: int = 0
var spawn_index: int = 0
var spawn_timer: float = 1.0
var env_respawn_timer: float = ENV_RESPAWN_TIME

var quotes: Array = []

var hud_health_fill: ColorRect
var hud_dur_fill: ColorRect
var hud_label: Label
var hud_wave_label: Label

var death_layer: CanvasLayer
var death_quote_label: Label


func _ready() -> void:
	randomize()
	load_quotes()
	build_background()
	build_hud()
	build_death_screen()
	player = Player.new()
	add_child(player)
	start_run()


func load_quotes() -> void:
	var f := FileAccess.open("res://death-quotes.txt", FileAccess.READ)
	if f:
		while not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line != "":
				quotes.append(line)
		f.close()
	if quotes.is_empty():
		quotes = ["Can somebody get this man a gun?"]


func build_background() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = ARENA_SIZE
	bg.color = Color(0.09, 0.09, 0.1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var health_bg := ColorRect.new()
	health_bg.position = Vector2(20, 20)
	health_bg.size = Vector2(200, 16)
	health_bg.color = Color(0.15, 0.15, 0.15)
	health_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(health_bg)

	hud_health_fill = ColorRect.new()
	hud_health_fill.position = Vector2(20, 20)
	hud_health_fill.size = Vector2(200, 16)
	hud_health_fill.color = Color(0.75, 0.15, 0.15)
	hud_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_health_fill)

	var dur_bg := ColorRect.new()
	dur_bg.position = Vector2(20, 42)
	dur_bg.size = Vector2(200, 10)
	dur_bg.color = Color(0.15, 0.15, 0.15)
	dur_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dur_bg)

	hud_dur_fill = ColorRect.new()
	hud_dur_fill.position = Vector2(20, 42)
	hud_dur_fill.size = Vector2(0, 10)
	hud_dur_fill.color = Color(0.2, 0.5, 0.85)
	hud_dur_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_dur_fill)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 58)
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_label)

	hud_wave_label = Label.new()
	hud_wave_label.position = Vector2(700, 20)
	hud_wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_wave_label)

	var hint_label := Label.new()
	hint_label.text = "E: pick up   LMB: attack   RMB: throw held item   Space: dash"
	hint_label.position = Vector2(20, 500)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint_label)


func build_death_screen() -> void:
	death_layer = CanvasLayer.new()
	add_child(death_layer)

	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = ARENA_SIZE
	bg.color = Color(0.05, 0.05, 0.06, 0.92)
	death_layer.add_child(bg)

	var title := Label.new()
	title.text = "ONE BULLET MAN"
	title.position = Vector2(80, 160)
	title.add_theme_font_size_override("font_size", 32)
	death_layer.add_child(title)

	death_quote_label = Label.new()
	death_quote_label.position = Vector2(80, 230)
	death_quote_label.size = Vector2(800, 60)
	death_quote_label.add_theme_font_size_override("font_size", 22)
	death_layer.add_child(death_quote_label)

	var restart_label := Label.new()
	restart_label.text = "Press SPACE to restart"
	restart_label.position = Vector2(80, 310)
	death_layer.add_child(restart_label)

	death_layer.visible = false


func start_run() -> void:
	state = "RUNNING"
	loop_count = 0
	spawn_index = 0
	spawn_timer = 1.0
	env_respawn_timer = ENV_RESPAWN_TIME
	melee_attack_token = null

	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	for p in enemy_projectiles.duplicate():
		p.queue_free()
	enemy_projectiles.clear()
	for pp in player_projectiles.duplicate():
		pp.queue_free()
	player_projectiles.clear()
	for pk in pickups.duplicate():
		pk.queue_free()
	pickups.clear()
	for hf in hit_flashes.duplicate():
		hf.queue_free()
	hit_flashes.clear()

	player.reset(ARENA_SIZE / 2.0)
	death_layer.visible = false

	for i in range(ENV_PICKUP_COUNT):
		spawn_env_pickup()


func difficulty_mult() -> float:
	return 1.0 + 0.18 * float(loop_count)


func spawn_group(etype: String, count: int) -> void:
	var base_pos := random_edge_position()
	for i in range(count):
		var offset := Vector2(randf_range(-35.0, 35.0), randf_range(-35.0, 35.0))
		spawn_enemy(etype, base_pos + offset)


func spawn_enemy(etype: String, pos: Vector2) -> void:
	var stats: Dictionary = ENEMY_STATS[etype]
	var e := Enemy.new()
	e.etype = etype
	e.radius = stats["radius"]
	e.color = stats["color"]
	e.speed = stats["speed"] * difficulty_mult()
	e.hits_left = stats["hits"]
	e.damage = stats["damage"]
	e.drop = stats["drop"]

	match etype:
		"switchblade":
			e.weapon_visual = "knife"
			e.personality = SWITCHBLADE_PERSONALITIES[randi() % SWITCHBLADE_PERSONALITIES.size()]
			e.melee_range = 30.0
		"bruiser":
			e.weapon_visual = "chair_leg"
			e.melee_range = 34.0
			e.raise_time = 0.4
			e.charge_time = 0.2
			e.charge_speed_mult = 2.4
			e.attack_cooldown_time = 0.6
		"shooter":
			e.weapon_visual = "pistol"
			e.state = "position"
			e.state_timer = 0.3
			e.melee_range = 36.0
			e.raise_time = 0.2
			e.charge_time = 0.14
			e.charge_speed_mult = 2.6
			e.attack_cooldown_time = 0.5
			e.personality = SHOOTER_PERSONALITIES[randi() % SHOOTER_PERSONALITIES.size()]
			var p: Dictionary = SHOOTER_PERSONALITY_STATS[e.personality]
			e.preferred_range = p["preferred_range"]
			e.fire_interval = float(p["fire_interval"]) / clamp(difficulty_mult(), 1.0, 1.6)
			e.telegraph_time = p["telegraph_time"]
			e.damage = stats["damage"] * float(p["damage_mult"])

	e.position = pos
	e.arena_size = ARENA_SIZE
	var arena_center := ARENA_SIZE / 2.0
	e.inward_dir = (arena_center - pos).normalized()
	e.facing = e.inward_dir
	e.aware = false

	add_child(e)
	enemies.append(e)


func random_edge_position() -> Vector2:
	var margin := 60.0
	var side := randi() % 4
	match side:
		0:
			return Vector2(randf_range(0, ARENA_SIZE.x), -margin)
		1:
			return Vector2(randf_range(0, ARENA_SIZE.x), ARENA_SIZE.y + margin)
		2:
			return Vector2(-margin, randf_range(0, ARENA_SIZE.y))
		_:
			return Vector2(ARENA_SIZE.x + margin, randf_range(0, ARENA_SIZE.y))


func spawn_env_pickup() -> void:
	var item_name: String = ENV_ITEMS[randi() % ENV_ITEMS.size()]
	var margin := 60.0
	var pos := Vector2(
		randf_range(margin, ARENA_SIZE.x - margin),
		randf_range(margin, ARENA_SIZE.y - margin)
	)
	spawn_pickup(item_name, pos)


func spawn_pickup(item_name: String, pos: Vector2) -> void:
	var stats: Dictionary = ITEM_STATS[item_name]
	var pk := Pickup.new()
	pk.item_name = item_name
	pk.uses = stats["uses"]
	pk.color = stats["color"]
	pk.label = stats["label"]
	pk.position = pos
	add_child(pk)
	pickups.append(pk)


func spawn_hit_flash(pos: Vector2) -> void:
	var hf := HitFlash.new()
	hf.position = pos
	add_child(hf)
	hit_flashes.append(hf)


func _process(delta: float) -> void:
	if state != "RUNNING":
		return

	player.handle_input(delta)
	player.position.x = clamp(player.position.x, 0, ARENA_SIZE.x)
	player.position.y = clamp(player.position.y, 0, ARENA_SIZE.y)
	update_player_range_indicator()

	update_enemies(delta)
	update_enemy_projectiles(delta)
	update_player_projectiles(delta)
	update_auto_fire()
	update_hit_flashes(delta)
	update_spawning(delta)

	env_respawn_timer -= delta
	if env_respawn_timer <= 0.0:
		env_respawn_timer = ENV_RESPAWN_TIME
		if pickups.size() < ENV_PICKUP_COUNT + 2:
			spawn_env_pickup()

	update_hud()

	if player.health <= 0.0:
		die()


func update_spawning(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL / clamp(difficulty_mult(), 1.0, 1.8)
		if enemies.size() < MAX_ALIVE:
			var group: Dictionary = SPAWN_QUEUE[spawn_index]
			var count: int = group["count"] + int(floor(float(loop_count) * 0.5))
			spawn_group(group["type"], count)
			spawn_index += 1
			if spawn_index >= SPAWN_QUEUE.size():
				spawn_index = 0
				loop_count += 1


func update_player_range_indicator() -> void:
	if player.held_item == "":
		player.current_range = Player.BARE_HANDS_RANGE
		return
	var stats: Dictionary = ITEM_STATS[player.held_item]
	player.current_range = stats["range"] if stats.get("type", "") == "melee" else 0.0


func update_hit_flashes(delta: float) -> void:
	for hf in hit_flashes.duplicate():
		if hf.update(delta):
			hit_flashes.erase(hf)
			hf.queue_free()


func update_enemies(delta: float) -> void:
	if melee_attack_token != null and not enemies.has(melee_attack_token):
		melee_attack_token = null

	var any_other_alive: bool = enemies.size() > 1
	for e in enemies.duplicate():
		var can_attack: bool = melee_attack_token == null or melee_attack_token == e
		var result: Dictionary = e.update(delta, player.position, any_other_alive, can_attack)

		if result.get("bled_out", false):
			kill_enemy(e)
			continue

		if e.aware:
			e.position.x = clamp(e.position.x, 0.0, ARENA_SIZE.x)
			e.position.y = clamp(e.position.y, 0.0, ARENA_SIZE.y)

		if e.state == "raise" or e.state == "charge" or e.state == "jab":
			melee_attack_token = e
		elif melee_attack_token == e:
			melee_attack_token = null

		if result.get("fire", false):
			fire_enemy_projectile(e)
		if result.get("melee_hit", false):
			player.take_damage(e.damage)


func update_enemy_projectiles(delta: float) -> void:
	for p in enemy_projectiles.duplicate():
		var dead: bool = p.update(delta)
		if not dead and p.position.distance_to(player.position) < p.radius + player.radius:
			player.take_damage(p.damage)
			dead = true
		if dead:
			enemy_projectiles.erase(p)
			p.queue_free()


func update_player_projectiles(delta: float) -> void:
	for pp in player_projectiles.duplicate():
		var dead: bool = pp.update(delta)
		if not dead:
			for e in enemies.duplicate():
				if pp.position.distance_to(e.position) < pp.radius + e.radius:
					spawn_hit_flash(e.position)
					if e.take_hit(pp.power):
						kill_enemy(e)
					dead = true
					break
		if dead:
			player_projectiles.erase(pp)
			pp.queue_free()


func update_auto_fire() -> void:
	if player.held_item == "":
		return
	var stats: Dictionary = ITEM_STATS[player.held_item]
	if stats.get("auto", false) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fire_held_ranged(stats)


func _unhandled_input(event: InputEvent) -> void:
	if state == "DEAD":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
			start_run()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			player.try_dash()
		elif event.physical_keycode == KEY_E:
			try_pickup()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			do_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			do_throw_held()


func try_pickup() -> void:
	var nearest: Pickup = null
	var nearest_dist := INTERACT_RANGE
	for pk in pickups:
		var d: float = pk.position.distance_to(player.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = pk
	if nearest:
		player.pick_up(nearest.item_name, nearest.uses)
		pickups.erase(nearest)
		nearest.queue_free()


func do_attack() -> void:
	var stats: Dictionary = {}
	if player.held_item != "":
		stats = ITEM_STATS[player.held_item]
	match stats.get("type", "melee"):
		"precision_gun":
			do_precision_shot(stats)
		"ranged":
			fire_held_ranged(stats)
		_:
			do_melee(stats)


func do_melee(stats: Dictionary) -> void:
	var cooldown: float = stats.get("cooldown", Player.BARE_HANDS_COOLDOWN)
	if not player.try_action(cooldown):
		return
	player.start_swing(min(cooldown, 0.22))

	var range_v: float = stats.get("range", Player.BARE_HANDS_RANGE)
	var power: float = stats.get("power", 0.4)
	var knockback: float = stats.get("knockback", 20.0)
	var hit_something := false

	for e in enemies.duplicate():
		var to_e: Vector2 = e.position - player.position
		var dist: float = to_e.length()
		if dist > range_v + e.radius:
			continue
		if dist > 1.0 and to_e.normalized().dot(player.aim_dir) < 0.35:
			continue

		hit_something = true
		spawn_hit_flash(e.position)
		if e.take_hit(power):
			kill_enemy(e)
		else:
			if knockback > 0.0 and dist > 0.5:
				e.position += to_e.normalized() * knockback
			if stats.has("bleed_ticks"):
				e.apply_bleed(stats["bleed_ticks"], stats["bleed_damage"])

	if hit_something and player.held_item != "":
		player.consume_held_item()


func fire_held_ranged(stats: Dictionary) -> void:
	if player.held_item == "":
		return
	var cooldown: float = stats.get("cooldown", 0.35)
	if not player.try_action(cooldown):
		return
	var power: float = stats.get("power", 1.0)
	var target: Enemy = find_closest_in_cone(player.position, player.aim_dir, 700.0, 0.85)
	if target:
		spawn_hit_flash(target.position)
		if target.take_hit(power):
			kill_enemy(target)
		player.consume_held_item()


func do_precision_shot(stats: Dictionary) -> void:
	if not player.try_action(0.35):
		return

	var hit := false
	var closest_pb: Enemy = null
	var closest_pb_dist := BULLET_POINT_BLANK
	for e in enemies:
		var d: float = player.position.distance_to(e.position)
		if d < closest_pb_dist:
			closest_pb_dist = d
			closest_pb = e

	if closest_pb:
		hit = true
		spawn_hit_flash(closest_pb.position)
		kill_enemy(closest_pb)
	else:
		var best: Enemy = null
		var best_perp := INF
		var best_dist := BULLET_RANGE
		for e in enemies:
			var to_e: Vector2 = e.position - player.position
			var dist: float = to_e.length()
			if dist > BULLET_RANGE:
				continue
			var proj: float = to_e.dot(player.aim_dir)
			if proj < 0.0:
				continue
			var perp: float = (to_e - player.aim_dir * proj).length()
			if perp <= e.radius * BULLET_BODY_TOLERANCE and dist < best_dist:
				best_dist = dist
				best = e
				best_perp = perp
		if best:
			hit = true
			spawn_hit_flash(best.position)
			if best_perp <= best.radius * BULLET_HEAD_TOLERANCE:
				kill_enemy(best)
			else:
				best.cripple(CRIPPLE_DURATION)

	if hit:
		player.pick_up("bludgeon", ITEM_STATS["bludgeon"]["uses"])


func do_throw_held() -> void:
	if player.held_item == "":
		return
	var stats: Dictionary = ITEM_STATS[player.held_item]
	var proj := PlayerProjectile.new()
	proj.position = player.position
	proj.velocity = player.aim_dir * float(stats.get("throw_speed", 500.0))
	proj.power = stats.get("power", 1.0)
	proj.item_name = player.held_item
	proj.life = float(stats.get("throw_life", 0.7))
	add_child(proj)
	player_projectiles.append(proj)

	player.held_item = ""
	player.held_uses = 0
	player.start_swing(0.12)


func find_closest_in_cone(from: Vector2, dir: Vector2, max_range: float, min_dot: float) -> Enemy:
	var best: Enemy = null
	var best_dist := max_range
	for e in enemies:
		var to_e: Vector2 = e.position - from
		var dist: float = to_e.length()
		if dist > max_range or dist < 0.001:
			continue
		if to_e.normalized().dot(dir) < min_dot:
			continue
		if dist < best_dist:
			best_dist = dist
			best = e
	return best


func kill_enemy(e: Enemy) -> void:
	if melee_attack_token == e:
		melee_attack_token = null
	spawn_pickup(e.drop, e.position)
	enemies.erase(e)
	e.queue_free()


func fire_enemy_projectile(e: Enemy) -> void:
	var p := EnemyProjectile.new()
	p.position = e.position
	p.velocity = (player.position - e.position).normalized() * 260.0
	p.damage = e.damage
	add_child(p)
	enemy_projectiles.append(p)


func update_hud() -> void:
	hud_health_fill.size.x = 200.0 * clamp(player.health / player.max_health, 0.0, 1.0)
	if player.held_item == "":
		hud_dur_fill.size.x = 0.0
		hud_label.text = "Holding: Bare Hands"
	else:
		var stats: Dictionary = ITEM_STATS[player.held_item]
		hud_dur_fill.size.x = 200.0 * clamp(float(player.held_uses) / float(stats["uses"]), 0.0, 1.0)
		hud_label.text = "Holding: " + str(stats["label"])
	hud_wave_label.text = "Loop %d" % [loop_count + 1]


func die() -> void:
	state = "DEAD"
	death_quote_label.text = quotes[randi() % quotes.size()]
	death_layer.visible = true
