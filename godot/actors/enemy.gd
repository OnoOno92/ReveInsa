extends CharacterBody2D
## Beasts and demonic cultivators. They chase, bite and shoot the player or bound beasts.\n## Settlements block them, except Shi Lan Village during a beast tide.

signal fired(from: Vector2, dir: Vector2, spec: Dictionary)

var id := ""
var def: Dictionary
var hp := 1.0
var max_hp := 1.0
var atk_t := 0.0
var ranged_t := 1.0
var slow_t := 0.0
var slow_amt := 0.0
var flash := 0.0
var wander_dir := Vector2.ZERO
var wander_t := 0.0
var aggro := false
var home := Vector2.INF
var radius := 12.0
var knock := Vector2.ZERO
## Beast-tide raider: marches on the village instead of wandering.
var raider := false


func setup(enemy_id: String, pos: Vector2, day: int, home_pos := Vector2.INF) -> void:
	id = enemy_id
	def = EnemyDB.ENEMIES[enemy_id]
	position = pos
	home = home_pos
	radius = def["radius"]
	var scale_hp := 1.0 if def.get("boss", false) else 1.0 + day * 0.04 # the world grows more dangerous
	max_hp = def["hp"] * scale_hp
	hp = max_hp
	ranged_t = 1.0 + randf() * 2.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius * 0.8
	shape.shape = c
	add_child(shape)


func is_boss() -> bool:
	return def.get("boss", false)


func take_damage(dmg: float, slow := 0.0) -> void:
	hp -= dmg
	flash = 0.12
	aggro = true
	if slow > 0.0:
		slow_t = 1.6
		slow_amt = maxf(slow_amt, slow)


func push(impulse: Vector2) -> void:
	if not is_boss():
		knock += impulse


func _physics_process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	atk_t -= delta
	ranged_t -= delta
	slow_t -= delta
	if slow_t <= 0.0:
		slow_amt = 0.0
	var ppos: Vector2 = Game.p["pos"]
	var night_mult := 1.25 if Game.is_night() else 1.0
	var aggro_r: float = def["aggro"] * night_mult * (1.6 if raider else 1.0)
	# Target: the player (unless sheltered in a settlement) or the nearest bound beast.
	var target: Node2D = null
	var tpos := Vector2.INF
	if not Game.blocks_enemies(ppos) and position.distance_to(ppos) < aggro_r \
			and not (home != Vector2.INF and ppos.distance_to(home) > 650.0):
		tpos = ppos
	for a in get_tree().get_nodes_in_group("allies"):
		var ad: float = position.distance_to(a.position)
		if ad < aggro_r * 0.8 and (tpos == Vector2.INF or ad < position.distance_to(tpos)):
			target = a
			tpos = a.position
	aggro = tpos != Vector2.INF
	var leash := home != Vector2.INF and position.distance_to(home) > 500.0 and not raider
	var speed: float = def["speed"] * (1.0 - slow_amt)
	var move := Vector2.ZERO
	if aggro:
		var to_t := tpos - position
		var d := maxf(0.001, to_t.length())
		var dir := to_t / d
		if def.has("ranged"):
			var rr: float = def["ranged"]["range"]
			if d < rr * 0.6:
				move = -dir
			elif d > rr * 0.8:
				move = dir
			if d < rr and ranged_t <= 0.0:
				ranged_t = def["ranged"]["cd"]
				fired.emit(position, dir, def["ranged"])
		else:
			move = dir
		var reach: float = radius + (target.radius if target else 0.0) + 14.0
		if d < reach and atk_t <= 0.0:
			atk_t = def["attack_cd"]
			var dmg: float = def["damage"] * (1.0 if is_boss() else 1.0 + Game.day() * 0.03)
			if target:
				target.take_damage(dmg)
			else:
				Game.hurt_player(dmg, def["name"])
	elif raider:
		# Beast tide: march on the village heart.
		var heart := WorldData.poi_center("village")
		if position.distance_to(heart) > 40.0:
			move = (heart - position).normalized()
	elif leash:
		move = (home - position).normalized()
	else:
		wander_t -= delta
		if wander_t <= 0.0:
			wander_t = 1.5 + randf() * 2.5
			wander_dir = Vector2.ZERO if randf() < 0.4 else Vector2.from_angle(randf() * TAU) * 0.4
		move = wander_dir
	velocity = move * speed
	# Settlements are impassable for monsters (except the village during a beast tide).
	if velocity != Vector2.ZERO and Game.blocks_enemies(position + velocity.normalized() * (radius + 6.0)):
		velocity = Vector2.ZERO
		wander_t = 0.0
	velocity += knock
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	var r := radius
	var col := Color.WHITE if flash > 0.0 else Color.html(def["color"])
	draw_set_transform(Vector2(0, r * 0.6), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.3))
	var flip := -1.0 if Game.p["pos"].x < position.x else 1.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 1))
	if def["faction"] == "demonic":
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 8), Vector2(10, 8), Vector2(6, -10), Vector2(-6, -10)]), col)
		draw_circle(Vector2(0, -15), 6, Color.html("#e8c8a8"))
		draw_rect(Rect2(-1, -24, 2, 4), Color.html("#ff3366"))
	else:
		draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 0.65))
		draw_circle(Vector2.ZERO, r, col)
		draw_set_transform(Vector2(flip * r * 0.8, -r * 0.3), 0, Vector2(flip, 0.85))
		draw_circle(Vector2.ZERO, r * 0.45, col)
		draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 1))
		draw_rect(Rect2(r * 0.95, -r * 0.45, 3, 3), Color.html("#ff4040") if aggro else Color.html("#ffd040"))
		if id == "thunder_wolf":
			draw_polyline(PackedVector2Array([Vector2(r * 0.6, -r * 0.7), Vector2(r * 0.8, -r * 1.1), Vector2(r, -r * 0.7)]), Color.html("#e3d0ff"), 2.0)
		if is_boss():
			draw_rect(Rect2(r * 0.5, -r * 0.9, r * 0.6, 4), Color.html("#ffcc33"))
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp or is_boss():
		var w := 70.0 if is_boss() else 28.0
		draw_rect(Rect2(-w / 2, -r - 12, w, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, -r - 12, w * maxf(0.0, hp / max_hp), 4), Color.html("#e74c3c"))
		if is_boss():
			draw_string(ThemeDB.fallback_font, Vector2(-w, -r - 16), def["name"], HORIZONTAL_ALIGNMENT_CENTER, w * 2, 12, Color.html("#ffcc33"))
