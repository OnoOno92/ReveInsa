extends CharacterBody2D
## A beast bound by an enslavement Gu (follows the player and bites), or a clan guard
## Gu Master who holds a post in Shi Lan Village during a beast tide and shoots moonlight.

signal shoot(from: Vector2, dir: Vector2)

var mode := "beast" # beast | guard
var post := Vector2.ZERO

var key := "" # summon key from the build (one Gu can command several)
var hp := 60.0
var max_hp := 60.0
var damage := 7.0
var speed := 165.0
var radius := 12.0
var atk_t := 0.0
var flash := 0.0
var _offset := Vector2.ZERO
var _t := 0.0


func setup(spec: Dictionary, index: int, pos: Vector2) -> void:
	key = spec["key"]
	max_hp = spec["hp"] * (1.0 + Game.day() * 0.03)
	hp = max_hp
	damage = spec["damage"]
	speed = spec["speed"]
	position = pos
	_offset = Vector2.from_angle(index * 2.1 + 0.6) * 46.0


func setup_guard(at: Vector2) -> void:
	mode = "guard"
	key = "guard"
	post = at
	position = at
	max_hp = 160.0 + Game.day() * 8.0
	hp = max_hp
	damage = 9.0 + Game.day() * 0.6
	speed = 120.0


func _ready() -> void:
	add_to_group("allies")
	collision_layer = 8
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius * 0.8
	shape.shape = c
	add_child(shape)


func take_damage(dmg: float) -> void:
	hp -= dmg
	flash = 0.12


func _physics_process(delta: float) -> void:
	if mode == "guard":
		_guard_process(delta)
		return
	_t += delta
	atk_t -= delta
	flash = maxf(0.0, flash - delta)
	var ppos: Vector2 = Game.p["pos"]
	var target: Node2D = null
	var best := 240.0 * 240.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.hp <= 0.0 or e.position.distance_squared_to(ppos) > 320.0 * 320.0:
			continue
		var d: float = e.position.distance_squared_to(position)
		if d < best:
			best = d
			target = e
	var goal := ppos + _offset
	if target:
		goal = target.position
		if position.distance_to(target.position) < radius + target.radius + 6.0 and atk_t <= 0.0:
			atk_t = 0.9
			target.take_damage(damage)
	var to := goal - position
	if position.distance_to(ppos) > 700.0:
		position = ppos + _offset # teleport back if left far behind
	velocity = Vector2.ZERO if to.length() < 8.0 else to.normalized() * speed * (1.0 if target or to.length() > 60.0 else 0.6)
	move_and_slide()
	queue_redraw()


func _guard_process(delta: float) -> void:
	atk_t -= delta
	flash = maxf(0.0, flash - delta)
	var target: Node2D = null
	var best := 260.0 * 260.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.position.distance_squared_to(position)
		if e.hp > 0.0 and d < best:
			best = d
			target = e
	if target and atk_t <= 0.0:
		atk_t = 1.1
		shoot.emit(position, (target.position - position).normalized())
	var to := post - position
	velocity = to.normalized() * speed if to.length() > 6.0 else Vector2.ZERO
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	if mode == "guard":
		_draw_guard()
		return
	var r := radius
	var flip := -1.0 if velocity.x < -1.0 else 1.0
	draw_set_transform(Vector2(0, r * 0.6), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.3))
	var col := Color.WHITE if flash > 0.0 else Color("#b9a98c")
	draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 0.65))
	draw_circle(Vector2.ZERO, r, col)
	draw_set_transform(Vector2(flip * r * 0.8, -r * 0.3), 0, Vector2(flip, 0.85))
	draw_circle(Vector2.ZERO, r * 0.45, col)
	draw_set_transform(Vector2.ZERO, 0, Vector2(flip, 1))
	draw_rect(Rect2(r * 0.95, -r * 0.45, 3, 3), Color("#7cfc8a"))
	# enslavement mark: a pink collar glow
	draw_arc(Vector2(r * 0.45, -r * 0.2), 5, 0, TAU, 12, Color("#d16ba5"), 2.0)
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp:
		draw_rect(Rect2(-14, -r - 10, 28, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -r - 10, 28 * maxf(0.0, hp / max_hp), 3), Color("#7cfc8a"))


func _draw_guard() -> void:
	draw_set_transform(Vector2(0, 8), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var robe := Color.WHITE if flash > 0.0 else Color("#3d6a8a")
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 7), Vector2(9, 7), Vector2(6, -10), Vector2(-6, -10)]), robe)
	draw_rect(Rect2(-7, -2, 14, 3), Color("#9ecbff"))
	draw_circle(Vector2(0, -15), 6, Color("#f1d6b8"))
	draw_arc(Vector2(0, -16), 6, PI, TAU, 12, Color("#1b1b1b"), 4.0)
	if hp < max_hp:
		draw_rect(Rect2(-14, -30, 28, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -30, 28 * maxf(0.0, hp / max_hp), 3), Color("#7cfc8a"))
