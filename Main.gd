extends Node2D

const ARENA_SIZE := Vector2(1920, 1080)

const BULLET_POINT_BLANK := 50.0
const BULLET_RANGE := 1200.0
const BULLET_HEAD_TOLERANCE := 0.5
const BULLET_BODY_TOLERANCE := 1.3
const CRIPPLE_DURATION := 2.5

# Grapple / chokehold — the "advanced" layer of the dodge-and-brawl system.
# Bare-handed only: grab a nearby enemy with Q, then LMB strikes, RMB throws
# them, Q again starts a chokehold, Space shoves free early.
const GRAPPLE_RANGE := 44.0
const GRAPPLE_HOLD_DIST := 26.0
const GRAPPLE_STRIKE_DAMAGE := 1.4
const GRAPPLE_STRIKE_COOLDOWN := 0.4
const CHOKEHOLD_TIME := 1.3
const GRAPPLE_THROW_DIST := 150.0
const GRAPPLE_THROW_KNOCKBACK := 200.0
const GRAPPLE_COLLATERAL_RADIUS := 34.0

# Reward for a well-timed dodge through an attack: instead of taking the
# hit, the attacker gets sent into a full knockdown.
const DODGE_PUNISH_FORCE := 220.0

# Arena layout — one dividing wall with a doorway gap. The bottom segment
# is soft cover (drywall) specifically so there's always a spot to wallbang
# someone lurking just past the doorway before they round the corner.
const WALL_THICKNESS := 40.0
const DOORWAY_HALF_GAP := 90.0
const DOORWAY_WAYPOINT := Vector2(960.0, 540.0)
const PLAYER_SPAWN := Vector2(280.0, 540.0)

# "drop_chance" keeps guns rare — melee drops are guaranteed, gun drops
# are a coin-flip-ish chance so finding one still feels like a moment.
const ENEMY_STATS := {
	"switchblade": {"hits": 3.0, "speed": 130.0, "radius": 14.0, "color": Color(0.85, 0.2, 0.2), "damage": 12.0, "drop": "knife", "drop_chance": 1.0, "hit_push": 22.0},
	"brawler": {"hits": 5.0, "speed": 110.0, "radius": 15.0, "color": Color(0.75, 0.4, 0.15), "damage": 16.0, "drop": "bottle", "drop_chance": 1.0, "hit_push": 30.0},
	"bruiser": {"hits": 16.0, "speed": 58.0, "radius": 20.0, "color": Color(0.55, 0.15, 0.65), "damage": 20.0, "drop": "smg", "drop_chance": 0.4, "hit_push": 55.0},
	"shooter": {"hits": 5.0, "speed": 70.0, "radius": 14.0, "color": Color(0.9, 0.6, 0.1), "damage": 8.0, "drop": "pistol", "drop_chance": 0.4, "hit_push": 18.0},
	"gunner": {"hits": 4.0, "speed": 90.0, "radius": 14.0, "color": Color(0.3, 0.4, 0.75), "damage": 6.0, "drop": "uzi", "drop_chance": 0.4, "hit_push": 16.0},
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
# Throw speed/distance/knockback scale with each item's size/weight: small
# light things (pencil, knife) fly fast and far but barely stagger; big
# heavy things (chair leg, SMG) are thrown slower and shorter but hit hard
# enough to knock a target down outright. "tumble_speed" is how fast the
# item spins in the air while thrown — heavier items tumble lazily.
# "style" is the melee attack shape: "thrust" (a stab, straight forward, no
# rotation) for pointy things, "swing" (a wide arc) for blunt/heavy things.
# "arc_dot" is how wide that swing's hit-cone is — lower is wider — and
# "swing_arc" is how far the weapon itself visibly rotates through that
# swing, so a chair leg actually LOOKS like a wide haymaker, not just hits
# like one.
const ITEM_STATS := {
	"one_bullet": {"type": "precision_gun", "uses": 1, "power": 1.0, "throw_speed": 520.0, "throw_life": 0.673, "throw_knockback": 80.0, "tumble_speed": 7.0, "color": Color(0.2, 0.2, 0.24), "label": "Your Gun"},
	"knife": {"type": "melee", "uses": 4, "power": 1.0, "range": 24.0, "cooldown": 0.16, "knockback": 0.0, "style": "thrust", "arc_dot": 0.55, "swing_arc": 0.5, "bleed_ticks": 3, "bleed_damage": 0.3, "throw_speed": 760.0, "throw_life": 0.632, "throw_knockback": 30.0, "tumble_speed": 15.0, "color": Color(0.82, 0.82, 0.86), "label": "Kitchen Knife"},
	"chair_leg": {"type": "melee", "uses": 3, "power": 1.6, "range": 50.0, "cooldown": 0.56, "knockback": 160.0, "style": "swing", "arc_dot": -0.1, "swing_arc": 2.0, "throw_speed": 300.0, "throw_life": 0.733, "throw_knockback": 190.0, "tumble_speed": 4.0, "color": Color(0.5, 0.35, 0.2), "label": "Chair Leg"},
	"bludgeon": {"type": "melee", "uses": 2, "power": 1.0, "range": 28.0, "cooldown": 0.32, "knockback": 50.0, "style": "swing", "arc_dot": 0.35, "swing_arc": 1.1, "throw_speed": 560.0, "throw_life": 0.589, "throw_knockback": 100.0, "tumble_speed": 8.0, "color": Color(0.3, 0.3, 0.32), "label": "Spent Gun"},
	"pencil": {"type": "melee", "uses": 1, "power": 2.0, "range": 20.0, "cooldown": 0.14, "knockback": 0.0, "style": "thrust", "arc_dot": 0.6, "swing_arc": 0.4, "throw_speed": 900.0, "throw_life": 0.533, "throw_knockback": 0.0, "tumble_speed": 20.0, "color": Color(0.92, 0.8, 0.3), "label": "Pencil"},
	"pistol": {"type": "ranged", "uses": 5, "power": 4.0, "cooldown": 0.32, "throw_speed": 520.0, "throw_life": 0.673, "throw_knockback": 80.0, "tumble_speed": 7.0, "color": Color(0.2, 0.2, 0.24), "label": "Pistol"},
	"smg": {"type": "ranged", "uses": 10, "power": 1.8, "cooldown": 0.09, "auto": true, "throw_speed": 360.0, "throw_life": 0.694, "throw_knockback": 160.0, "tumble_speed": 5.0, "color": Color(0.15, 0.15, 0.2), "label": "Compact SMG"},
	"uzi": {"type": "ranged", "uses": 14, "power": 1.2, "cooldown": 0.07, "auto": true, "throw_speed": 480.0, "throw_life": 0.65, "throw_knockback": 90.0, "tumble_speed": 9.0, "color": Color(0.12, 0.12, 0.16), "label": "Uzi"},
	"bottle": {"type": "melee", "uses": 3, "power": 1.1, "range": 30.0, "cooldown": 0.22, "knockback": 40.0, "style": "thrust", "arc_dot": 0.55, "swing_arc": 0.5, "throw_speed": 620.0, "throw_life": 0.645, "throw_knockback": 70.0, "tumble_speed": 10.0, "color": Color(0.3, 0.6, 0.42), "label": "Bottle"},
}

# A short authored sequence instead of an infinite scaling loop — fewer,
# tougher enemies per encounter, some starting already visible in the
# front room, some placed in the back room behind the wall so they have to
# be discovered (or wallbanged) rather than just walking in from an edge.
# Entries sharing a "group" id spawn clustered together (a squad arriving
# as one), entries without one are scattered independently in the room.
const ENCOUNTERS := [
	{"enemies": [
		{"type": "switchblade", "room": "front", "group": 1},
		{"type": "switchblade", "room": "front", "group": 1},
	]},
	{"enemies": [
		{"type": "shooter", "room": "back"},
		{"type": "brawler", "room": "back"},
	]},
	{"enemies": [
		{"type": "bruiser", "room": "back"},
		{"type": "gunner", "room": "front"},
	]},
	{"enemies": [
		{"type": "switchblade", "room": "front", "group": 2},
		{"type": "brawler", "room": "front", "group": 2},
		{"type": "shooter", "room": "back"},
		{"type": "bruiser", "room": "back"},
	]},
]
const ENCOUNTER_START_DELAY := 1.2
const ENCOUNTER_PAUSE := 2.5

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
var muzzle_flashes: Array = []
var bullet_tracers: Array = []
var walls: Array = []
var melee_attack_token: Enemy = null
var sfx: SoundFX

var grapple_target: Enemy = null
var choke_timer: float = 0.0

var state: String = "RUNNING"
var encounter_index: int = 0
var encounter_timer: float = ENCOUNTER_START_DELAY
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
	build_arena_layout()
	build_hud()
	build_death_screen()
	sfx = SoundFX.new()
	add_child(sfx)
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


# One dividing wall, one doorway gap. The bottom half is soft (drywall) so
# there's always a wallbang opportunity right next to where enemies have
# to funnel through. Built once — the layout doesn't change between runs.
func build_arena_layout() -> void:
	var divider_x := ARENA_SIZE.x / 2.0
	var gap_top: float = ARENA_SIZE.y / 2.0 - DOORWAY_HALF_GAP
	var gap_bottom: float = ARENA_SIZE.y / 2.0 + DOORWAY_HALF_GAP

	var top_wall := Wall.new()
	top_wall.position = Vector2(divider_x, gap_top / 2.0)
	top_wall.size = Vector2(WALL_THICKNESS, gap_top)
	top_wall.wall_material = "solid"
	add_child(top_wall)
	walls.append(top_wall)

	var bottom_h: float = ARENA_SIZE.y - gap_bottom
	var bottom_wall := Wall.new()
	bottom_wall.position = Vector2(divider_x, gap_bottom + bottom_h / 2.0)
	bottom_wall.size = Vector2(WALL_THICKNESS, bottom_h)
	bottom_wall.wall_material = "soft"
	add_child(bottom_wall)
	walls.append(bottom_wall)


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
	hint_label.text = "E: pick up   LMB: attack   RMB: throw   Q: grapple (bare-handed), hold to choke   Space: dash / break free"
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
	encounter_index = 0
	encounter_timer = ENCOUNTER_START_DELAY
	env_respawn_timer = ENV_RESPAWN_TIME
	melee_attack_token = null
	grapple_target = null
	choke_timer = 0.0

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
	for mf in muzzle_flashes.duplicate():
		mf.queue_free()
	muzzle_flashes.clear()
	for bt in bullet_tracers.duplicate():
		bt.queue_free()
	bullet_tracers.clear()

	player.reset(PLAYER_SPAWN)
	death_layer.visible = false

	for i in range(ENV_PICKUP_COUNT):
		spawn_env_pickup()


func spawn_enemy(etype: String, pos: Vector2) -> void:
	var stats: Dictionary = ENEMY_STATS[etype]
	var e := Enemy.new()
	e.etype = etype
	e.radius = stats["radius"]
	e.color = stats["color"]
	e.speed = stats["speed"]
	e.hits_left = stats["hits"]
	e.damage = stats["damage"]
	e.drop = stats["drop"]
	e.drop_chance = stats.get("drop_chance", 1.0)
	e.hit_push = stats.get("hit_push", 20.0)

	match etype:
		"switchblade":
			e.weapon_visual = "knife"
			e.personality = SWITCHBLADE_PERSONALITIES[randi() % SWITCHBLADE_PERSONALITIES.size()]
			e.melee_range = 30.0
		"brawler":
			e.weapon_visual = "bottle"
			e.personality = "rusher"
			e.melee_range = 34.0
			e.raise_time = 0.5
			e.charge_time = 0.16
			e.charge_speed_mult = 3.2
			e.attack_cooldown_time = 0.75
		"bruiser":
			e.weapon_visual = "chair_leg"
			e.melee_range = 34.0
			e.raise_time = 0.6
			e.charge_time = 0.22
			e.charge_speed_mult = 3.0
			e.attack_cooldown_time = 0.9
		"shooter":
			e.weapon_visual = "pistol"
			e.state = "position"
			e.state_timer = 0.3
			e.melee_range = 36.0
			e.raise_time = 0.35
			e.charge_time = 0.12
			e.charge_speed_mult = 3.4
			e.attack_cooldown_time = 0.75
			e.personality = SHOOTER_PERSONALITIES[randi() % SHOOTER_PERSONALITIES.size()]
			var p: Dictionary = SHOOTER_PERSONALITY_STATS[e.personality]
			e.preferred_range = p["preferred_range"]
			e.fire_interval = float(p["fire_interval"])
			e.telegraph_time = p["telegraph_time"]
			e.damage = stats["damage"] * float(p["damage_mult"])
		"gunner":
			e.weapon_visual = "uzi"
			e.state = "position"
			e.state_timer = 0.3
			e.personality = "showoff" # always aggressive — closes in and sprays, never backs off
			e.preferred_range = 140.0
			e.fire_interval = 0.5
			e.telegraph_time = 0.15
			e.melee_range = 32.0
			e.raise_time = 0.3
			e.charge_time = 0.12
			e.charge_speed_mult = 3.2
			e.attack_cooldown_time = 0.65

	e.position = pos
	e.patrol_home = pos
	e.arena_size = ARENA_SIZE
	e.doorway_waypoint = DOORWAY_WAYPOINT
	e.facing = (ARENA_SIZE / 2.0 - pos).normalized()
	e.aware = true

	add_child(e)
	enemies.append(e)


# Front room is the player's starting side (x < divider); back room is
# behind the wall, out of sight until the player crosses the doorway or
# wallbangs through the soft segment.
func room_spawn_position(room: String) -> Vector2:
	if room == "back":
		return Vector2(randf_range(1060.0, 1860.0), randf_range(140.0, 940.0))
	return Vector2(randf_range(120.0, 860.0), randf_range(140.0, 940.0))


func spawn_env_pickup() -> void:
	var item_name: String = ENV_ITEMS[randi() % ENV_ITEMS.size()]
	spawn_pickup(item_name, room_spawn_position("front"))


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


func spawn_muzzle_flash(pos: Vector2, dir: Vector2) -> void:
	var mf := MuzzleFlash.new()
	mf.position = pos
	mf.dir = dir
	add_child(mf)
	muzzle_flashes.append(mf)


func spawn_bullet_tracer(from: Vector2, to: Vector2) -> void:
	var bt := BulletTracer.new()
	bt.start_pos = from
	bt.end_pos = to
	add_child(bt)
	bullet_tracers.append(bt)


# Single chokepoint used everywhere something's position might have moved
# into a wall (knockback, throws, pushes) — run every frame for the player
# and every aware enemy, so nothing stays stuck inside geometry for more
# than a frame.
func resolve_against_walls(pos: Vector2, radius: float) -> Vector2:
	var p := pos
	for w in walls:
		p = Geometry.resolve_circle_vs_rect(p, radius, w.get_rect())
	return p


# Clips a ray to where it's stopped by a solid wall, for tracer visuals.
func clip_to_wall(from: Vector2, to: Vector2) -> Vector2:
	var rc := Geometry.raycast_walls(from, to, walls)
	var solid_t: float = rc["solid_t"]
	if solid_t < 1.0:
		return from.lerp(to, solid_t)
	return to


func _process(delta: float) -> void:
	if state != "RUNNING":
		return

	player.handle_input(delta)
	player.position.x = clamp(player.position.x, 0, ARENA_SIZE.x)
	player.position.y = clamp(player.position.y, 0, ARENA_SIZE.y)
	player.position = resolve_against_walls(player.position, player.radius)
	update_grapple(delta)
	update_player_range_indicator()

	update_enemies(delta)
	update_enemy_projectiles(delta)
	update_player_projectiles(delta)
	update_auto_fire()
	update_hit_flashes(delta)
	update_muzzle_flashes(delta)
	update_bullet_tracers(delta)
	update_encounters(delta)

	env_respawn_timer -= delta
	if env_respawn_timer <= 0.0:
		env_respawn_timer = ENV_RESPAWN_TIME
		if pickups.size() < ENV_PICKUP_COUNT + 2:
			spawn_env_pickup()

	update_hud()

	if player.health <= 0.0:
		die()


func update_encounters(delta: float) -> void:
	if encounter_index >= ENCOUNTERS.size():
		return
	if not enemies.is_empty():
		return
	encounter_timer -= delta
	if encounter_timer <= 0.0:
		spawn_encounter(encounter_index)
		encounter_index += 1
		encounter_timer = ENCOUNTER_PAUSE


func spawn_encounter(index: int) -> void:
	var enc: Dictionary = ENCOUNTERS[index]
	var group_bases: Dictionary = {}
	for enemy_def in enc["enemies"]:
		var room: String = enemy_def.get("room", "front")
		var pos: Vector2
		if enemy_def.has("group"):
			var gkey: String = str(enemy_def["group"]) + "_" + room
			if not group_bases.has(gkey):
				group_bases[gkey] = room_spawn_position(room)
			pos = group_bases[gkey] + Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
		else:
			pos = room_spawn_position(room)
		spawn_enemy(enemy_def["type"], pos)


func update_player_range_indicator() -> void:
	if player.held_item == "":
		player.current_range = Player.BARE_HANDS_RANGE
		player.current_arc_half_angle = Player.MELEE_HALF_ANGLE
		return
	var stats: Dictionary = ITEM_STATS[player.held_item]
	if stats.get("type", "") == "melee":
		player.current_range = stats["range"]
		player.current_arc_half_angle = acos(clamp(stats.get("arc_dot", 0.35), -1.0, 1.0))
	else:
		player.current_range = 0.0


func update_hit_flashes(delta: float) -> void:
	for hf in hit_flashes.duplicate():
		if hf.update(delta):
			hit_flashes.erase(hf)
			hf.queue_free()


func update_muzzle_flashes(delta: float) -> void:
	for mf in muzzle_flashes.duplicate():
		if mf.update(delta):
			muzzle_flashes.erase(mf)
			mf.queue_free()


func update_bullet_tracers(delta: float) -> void:
	for bt in bullet_tracers.duplicate():
		if bt.update(delta):
			bullet_tracers.erase(bt)
			bt.queue_free()


func update_grapple(delta: float) -> void:
	if grapple_target == null:
		return
	grapple_target.position = player.position + player.aim_dir * GRAPPLE_HOLD_DIST
	grapple_target.facing = -player.aim_dir

	# Hold Q to choke — release early and it resets, so committing to the
	# kill means committing to standing still and taking the risk.
	if Input.is_physical_key_pressed(KEY_Q):
		if not player.is_choking:
			player.is_choking = true
			choke_timer = 0.0
			sfx.play("chokehold_start", -2.0)
		choke_timer += delta
		grapple_target.choke_progress = clamp(choke_timer / CHOKEHOLD_TIME, 0.0, 1.0)
		if choke_timer >= CHOKEHOLD_TIME:
			var dead := grapple_target
			grapple_target = null
			player.is_grappling = false
			player.is_choking = false
			sfx.play("chokehold_kill")
			kill_enemy(dead)
	else:
		if player.is_choking:
			player.is_choking = false
			choke_timer = 0.0
		grapple_target.choke_progress = 0.0


func update_enemies(delta: float) -> void:
	if melee_attack_token != null and not enemies.has(melee_attack_token):
		melee_attack_token = null

	for e in enemies.duplicate():
		var can_attack: bool = melee_attack_token == null or melee_attack_token == e
		var can_see: bool = not Geometry.is_segment_blocked(e.position, player.position, walls)
		var ctx := {
			"player_pos": player.position,
			"enemies": enemies,
			"walls": walls,
			"can_see": can_see,
			"hostage": player.is_grappling,
		}
		var result: Dictionary = e.update(delta, ctx, can_attack)

		if result.get("bled_out", false):
			if grapple_target == e:
				grapple_target = null
				player.is_grappling = false
				player.is_choking = false
				choke_timer = 0.0
			kill_enemy(e)
			continue

		if e.aware:
			e.position.x = clamp(e.position.x, 0.0, ARENA_SIZE.x)
			e.position.y = clamp(e.position.y, 0.0, ARENA_SIZE.y)
			e.position = resolve_against_walls(e.position, e.radius)

		if e.state == "raise" or e.state == "charge" or e.state == "jab":
			melee_attack_token = e
		elif melee_attack_token == e:
			melee_attack_token = null

		if result.get("fire", false):
			fire_enemy_projectile(e)
		if result.get("melee_hit", false):
			if player.invulnerable:
				var away: Vector2 = e.position - player.position
				var dir: Vector2 = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
				e.apply_knockback(dir, DODGE_PUNISH_FORCE)
				spawn_hit_flash(e.position)
				sfx.play("dodge_punish")
			else:
				damage_player(e.damage)
				# a reduced, reciprocal version of the player's own toolkit —
				# a real shove and a brief lockout, clearly weaker than what
				# the player can dish out.
				var push: Vector2 = player.position - e.position
				var push_dir: Vector2 = push.normalized() if push.length() > 0.001 else Vector2.RIGHT
				player.position += push_dir * e.hit_push
				player.position = resolve_against_walls(player.position, player.radius)
				player.action_cooldown_timer = max(player.action_cooldown_timer, 0.3)


func update_enemy_projectiles(delta: float) -> void:
	for p in enemy_projectiles.duplicate():
		var prev_pos: Vector2 = p.position
		var dead: bool = p.update(delta)
		if not dead:
			var blocked := false
			for w in walls:
				var seg: Array = Geometry.segment_vs_rect(prev_pos, p.position, w.get_rect())
				if seg.is_empty():
					continue
				if w.wall_material == "solid":
					blocked = true
					break
				else:
					p.damage *= 0.6
			if blocked:
				dead = true
			elif grapple_target != null and p.position.distance_to(grapple_target.position) < p.radius + grapple_target.radius:
				# a human shield — a bullet meant for the player kills the
				# hostage outright instead and frees the grapple.
				kill_enemy(grapple_target)
				dead = true
			elif p.position.distance_to(player.position) < p.radius + player.radius:
				damage_player(p.damage)
				dead = true
		if dead:
			enemy_projectiles.erase(p)
			p.queue_free()


func update_player_projectiles(delta: float) -> void:
	for pp in player_projectiles.duplicate():
		var prev_pos: Vector2 = pp.position
		var dead: bool = pp.update(delta)
		if not dead:
			var blocked := false
			for w in walls:
				var seg: Array = Geometry.segment_vs_rect(prev_pos, pp.position, w.get_rect())
				if seg.is_empty():
					continue
				if w.wall_material == "solid":
					blocked = true
					spawn_hit_flash(pp.position)
					break
				else:
					pp.power *= 0.6
			if blocked:
				dead = true
			else:
				for e in enemies.duplicate():
					if e.grappled:
						continue
					if pp.position.distance_to(e.position) < pp.radius + e.radius:
						spawn_hit_flash(e.position)
						if e.take_hit(pp.power):
							kill_enemy(e)
						else:
							var stats: Dictionary = ITEM_STATS.get(pp.item_name, {})
							var kb: float = stats.get("throw_knockback", 0.0)
							if kb > 0.0:
								var dir: Vector2 = pp.velocity.normalized() if pp.velocity.length() > 0.001 else (e.position - player.position).normalized()
								e.apply_knockback(dir, kb)
								sfx.play("knockdown" if kb >= Enemy.STAGGER_KNOCKBACK_THRESHOLD else "stagger", -3.0)
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
			if grapple_target != null:
				break_grapple(true)
			elif player.try_dash():
				sfx.play("dash", -6.0)
		elif event.physical_keycode == KEY_E:
			try_pickup()
		elif event.physical_keycode == KEY_Q:
			try_grapple_input()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if grapple_target != null:
				grapple_strike()
			else:
				do_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if grapple_target != null:
				grapple_throw()
			else:
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
		sfx.play("pickup", -4.0)


func find_grapple_target() -> Enemy:
	var best: Enemy = null
	var best_dist := GRAPPLE_RANGE
	for e in enemies:
		if not e.aware or e.grappled:
			continue
		var to_e: Vector2 = e.position - player.position
		var dist: float = to_e.length()
		if dist > GRAPPLE_RANGE or dist < 0.001:
			continue
		if to_e.normalized().dot(player.aim_dir) < 0.45:
			continue
		if dist < best_dist:
			best_dist = dist
			best = e
	return best


func try_grapple_input() -> void:
	if player.action_cooldown_timer > 0.0:
		return
	if grapple_target != null:
		return # already grabbed someone — hold Q to choke instead of pressing it again
	if player.held_item != "":
		return
	var target := find_grapple_target()
	if target == null:
		return
	grapple_target = target
	target.grappled = true
	target.state = "chase"
	target.state_timer = 0.0
	target.knock_state = ""
	if melee_attack_token == target:
		melee_attack_token = null
	player.is_grappling = true
	sfx.play("grapple_grab", -2.0)


func break_grapple(shove: bool) -> void:
	if grapple_target == null:
		return
	var t := grapple_target
	grapple_target = null
	player.is_grappling = false
	player.is_choking = false
	choke_timer = 0.0
	t.grappled = false
	t.choke_progress = 0.0
	if shove:
		t.apply_knockback(player.aim_dir, 90.0)
		player.dash_dir = -player.aim_dir
		player.dash_is_lunge = false
		player.dash_timer = Player.DASH_TIME
		player.dash_cooldown_timer = Player.DASH_COOLDOWN
		sfx.play("grapple_break", -3.0)


func grapple_strike() -> void:
	if grapple_target == null:
		return
	if not player.try_action(GRAPPLE_STRIKE_COOLDOWN):
		return
	player.start_swing(0.16)
	var target := grapple_target
	spawn_hit_flash(target.position)
	sfx.play("impact", -1.0, 1.1)
	if target.take_hit(GRAPPLE_STRIKE_DAMAGE):
		break_grapple(false)
		kill_enemy(target)


func grapple_throw() -> void:
	if grapple_target == null:
		return
	var t := grapple_target
	var dir := player.aim_dir
	grapple_target = null
	player.is_grappling = false
	player.is_choking = false
	choke_timer = 0.0
	t.grappled = false
	t.choke_progress = 0.0
	t.position += dir * GRAPPLE_THROW_DIST
	t.position.x = clamp(t.position.x, 0.0, ARENA_SIZE.x)
	t.position.y = clamp(t.position.y, 0.0, ARENA_SIZE.y)
	spawn_hit_flash(t.position)
	sfx.play("throw", -1.0, 0.75)
	if t.take_hit(0.6):
		kill_enemy(t)
		return
	t.apply_knockback(dir, GRAPPLE_THROW_KNOCKBACK)
	sfx.play("knockdown", -2.0)
	for other in enemies.duplicate():
		if other == t:
			continue
		if other.position.distance_to(t.position) < GRAPPLE_COLLATERAL_RADIUS:
			var away: Vector2 = other.position - t.position
			var away_dir: Vector2 = away.normalized() if away.length() > 0.001 else dir
			if other.take_hit(0.4):
				kill_enemy(other)
			else:
				other.apply_knockback(away_dir, GRAPPLE_THROW_KNOCKBACK)


func damage_player(amount: float) -> void:
	if player.invulnerable:
		return
	player.take_damage(amount)
	sfx.play("player_hit", -3.0)
	if player.is_choking and grapple_target != null:
		var t := grapple_target
		break_grapple(false)
		t.apply_knockback(-player.aim_dir, 90.0)
		sfx.play("grapple_interrupted", -2.0)


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
	var style: String = stats.get("style", "swing")
	var swing_arc: float = stats.get("swing_arc", 1.0)
	player.start_swing(cooldown, style, swing_arc) # the swing IS the cooldown — heavy items visibly swing slower

	var range_v: float = stats.get("range", Player.BARE_HANDS_RANGE)
	var power: float = stats.get("power", 0.4)
	var knockback: float = stats.get("knockback", 0.0)
	var arc_dot: float = stats.get("arc_dot", 0.35)
	var unarmed: bool = player.held_item == ""
	sfx.play("melee_swing", -4.0, randf_range(0.95, 1.08))
	var hit_something := false

	for e in enemies.duplicate():
		var to_e: Vector2 = e.position - player.position
		var dist: float = to_e.length()
		if dist > range_v + e.radius:
			continue
		if dist > 1.0 and to_e.normalized().dot(player.aim_dir) < arc_dot:
			continue

		hit_something = true
		spawn_hit_flash(e.position)
		if e.take_hit(power):
			kill_enemy(e)
		else:
			if unarmed:
				# hands are the control tool — stun to set up a combo,
				# not a knockdown.
				e.apply_stun(Enemy.STUN_DURATION)
				sfx.play("stun", -2.0)
			elif knockback > 0.0 and dist > 0.5:
				e.apply_knockback(to_e.normalized(), knockback)
				sfx.play("knockdown" if knockback >= Enemy.STAGGER_KNOCKBACK_THRESHOLD else "stagger", -3.0)
			if stats.has("bleed_ticks"):
				e.apply_bleed(stats["bleed_ticks"], stats["bleed_damage"])

	if hit_something:
		sfx.play("impact", -2.0)
		if player.held_item != "":
			player.consume_held_item()


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
		if dist >= best_dist:
			continue
		if Geometry.raycast_walls(from, e.position, walls)["solid_t"] < 0.999:
			continue # a solid wall sits between the shooter and this candidate
		best_dist = dist
		best = e
	return best


func fire_held_ranged(stats: Dictionary) -> void:
	if player.held_item == "":
		return
	var item_name: String = player.held_item
	var cooldown: float = stats.get("cooldown", 0.35)
	if not player.try_action(cooldown):
		return
	var power: float = stats.get("power", 1.0)
	var muzzle_pos: Vector2 = player.position + player.aim_dir * 18.0
	spawn_muzzle_flash(muzzle_pos, player.aim_dir)
	player.start_swing(0.08)

	var target: Enemy = find_closest_in_cone(player.position, player.aim_dir, 700.0, 0.85)
	var full_end: Vector2 = player.position + player.aim_dir * 700.0
	var end_point: Vector2 = clip_to_wall(muzzle_pos, full_end)
	if target:
		end_point = target.position
		spawn_hit_flash(target.position)
		var soft_crossings: int = Geometry.raycast_walls(player.position, target.position, walls)["soft_crossings"]
		var eff_power: float = power * (0.5 if soft_crossings > 0 else 1.0) # a wallbang — weaker but still lethal
		if target.take_hit(eff_power):
			kill_enemy(target)

	# guns are the one weapon type that burns durability on every trigger
	# pull, hit or miss — you're spending a real bullet either way.
	player.consume_held_item()

	spawn_bullet_tracer(muzzle_pos, end_point)
	var pitch := 1.0
	if item_name == "smg":
		pitch = 1.15
	elif item_name == "uzi":
		pitch = 1.28
	sfx.play("gunshot", -2.0, pitch)


func do_precision_shot(stats: Dictionary) -> void:
	if not player.try_action(0.35):
		return

	var muzzle_pos: Vector2 = player.position + player.aim_dir * 20.0
	spawn_muzzle_flash(muzzle_pos, player.aim_dir)
	player.start_swing(0.1)

	var hit := false
	var full_end: Vector2 = player.position + player.aim_dir * BULLET_RANGE
	var end_point: Vector2 = clip_to_wall(muzzle_pos, full_end)

	var closest_pb: Enemy = null
	var closest_pb_dist := BULLET_POINT_BLANK
	for e in enemies:
		var d: float = player.position.distance_to(e.position)
		if d < closest_pb_dist and not Geometry.is_segment_blocked(player.position, e.position, walls):
			closest_pb_dist = d
			closest_pb = e

	if closest_pb:
		hit = true
		end_point = closest_pb.position
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
			if perp > e.radius * BULLET_BODY_TOLERANCE or dist >= best_dist:
				continue
			if Geometry.raycast_walls(player.position, e.position, walls)["solid_t"] < 0.999:
				continue # a solid wall blocks this candidate — a soft wall doesn't
			best_dist = dist
			best = e
			best_perp = perp
		if best:
			hit = true
			end_point = best.position
			spawn_hit_flash(best.position)
			if best_perp <= best.radius * BULLET_HEAD_TOLERANCE:
				kill_enemy(best)
			else:
				best.cripple(CRIPPLE_DURATION)
				sfx.play("cripple")

	spawn_bullet_tracer(muzzle_pos, end_point)
	sfx.play("gunshot", 2.0, 0.85)

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
	proj.spin_speed = float(stats.get("tumble_speed", 8.0)) * (1.0 if randf() < 0.5 else -1.0)
	add_child(proj)
	player_projectiles.append(proj)

	sfx.play("throw", -3.0, randf_range(0.92, 1.05))

	player.held_item = ""
	player.held_uses = 0
	player.start_swing(0.12)


func kill_enemy(e: Enemy) -> void:
	if melee_attack_token == e:
		melee_attack_token = null
	if grapple_target == e:
		grapple_target = null
		player.is_grappling = false
		player.is_choking = false
		choke_timer = 0.0
	if randf() <= e.drop_chance:
		spawn_pickup(e.drop, e.position)
	enemies.erase(e)
	e.queue_free()
	sfx.play("enemy_death", -2.0, randf_range(0.9, 1.1))


func fire_enemy_projectile(e: Enemy) -> void:
	var p := EnemyProjectile.new()
	p.position = e.position
	var dir: Vector2 = (player.position - e.position).normalized()
	p.velocity = dir * 300.0
	p.damage = e.damage
	add_child(p)
	enemy_projectiles.append(p)
	spawn_muzzle_flash(e.position + dir * (e.radius + 4.0), dir)
	sfx.play("gunshot", -8.0, 1.05)


func update_hud() -> void:
	hud_health_fill.size.x = 200.0 * clamp(player.health / player.max_health, 0.0, 1.0)
	if grapple_target != null:
		hud_dur_fill.size.x = 0.0
		if player.is_choking:
			hud_label.text = "CHOKING... keep holding Q (letting go or getting hit breaks it)"
		else:
			hud_label.text = "Grappling — LMB: strike  RMB: throw  HOLD Q: chokehold  Space: break free"
	elif player.held_item == "":
		hud_dur_fill.size.x = 0.0
		hud_label.text = "Holding: Bare Hands"
	else:
		var stats: Dictionary = ITEM_STATS[player.held_item]
		hud_dur_fill.size.x = 200.0 * clamp(float(player.held_uses) / float(stats["uses"]), 0.0, 1.0)
		hud_label.text = "Holding: " + str(stats["label"])

	if encounter_index >= ENCOUNTERS.size() and enemies.is_empty():
		hud_wave_label.text = "All clear"
	else:
		hud_wave_label.text = "Encounter %d / %d" % [clamp(encounter_index + 1, 1, ENCOUNTERS.size()), ENCOUNTERS.size()]


func die() -> void:
	state = "DEAD"
	death_quote_label.text = quotes[randi() % quotes.size()]
	death_layer.visible = true
	sfx.play("player_death")
