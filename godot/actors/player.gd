extends CharacterBody2D
## The player only moves. Gu in the aperture attack automatically (see game/combat.gd).

var facing := Vector2.RIGHT
var moving := false
var _t := 0.0
var light: PointLight2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	light = Lights.make(150.0, Color(1.0, 0.95, 0.85))
	add_child(light)
	position = Game.p["pos"]


func _physics_process(delta: float) -> void:
	_t += delta
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = Game.stick
	moving = dir.length() > 0.05
	if moving:
		facing = dir.normalized()
	var tile := Game.world.tile_at_pos(position)
	var terrain := 1.0
	match tile:
		WorldData.T.SWAMP: terrain = 0.6
		WorldData.T.WATER: terrain = 0.55
		WorldData.T.ROAD: terrain = 1.15
	var hunger_mult := 0.8 if Game.p["hunger"] <= 0.0 else 1.0
	velocity = dir.limit_length(1.0) * Game.move_speed() * terrain * hunger_mult
	move_and_slide()
	Game.p["pos"] = position
	light.texture_scale = (150.0 + Game.stat("light_radius")) / Lights.BASE_RADIUS
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 12.0) * 1.5 if moving else 0.0
	var ec := Aperture.essence_color(Game.p["rank"])
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, 8), 11, Color(0, 0, 0, 0.3)) # shadow (squashed below)
	# essence aura
	var aura := ec
	aura.a = 0.22 + 0.08 * sin(_t * 3.0)
	draw_circle(Vector2(0, -6), 20, aura)
	if Game.shield > 1.0:
		draw_arc(Vector2(0, -6), 18, 0, TAU, 32, Color(0.4, 0.75, 1.0, 0.7), 2.0)
	# robe
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 7 + bob), Vector2(9, 7 + bob), Vector2(6, -10 + bob), Vector2(-6, -10 + bob)]), Color.html("#2d3e50"))
	draw_rect(Rect2(-7, -2 + bob, 14, 3), ec)
	# head + hair
	draw_circle(Vector2(0, -15 + bob), 6, Color.html("#f1d6b8"))
	draw_arc(Vector2(0, -16 + bob), 6, PI, TAU, 12, Color.html("#1b1b1b"), 4.0)
	draw_rect(Rect2(-1.5, -26 + bob, 3, 5), Color.html("#1b1b1b"))
	# orbiting motes, one per placed Gu (grey if starving)
	var placed: Array = Game.p["placed"]
	for i in placed.size():
		var inst := Aperture.find_inst(Game.p["gu"], placed[i]["uid"])
		if inst.is_empty():
			continue
		var a := _t * 1.6 + i * TAU / maxf(1.0, placed.size())
		var col := Color(0.35, 0.35, 0.35) if Aperture.is_starving(inst) else GuDB.color_of(inst["def"])
		draw_circle(Vector2(cos(a) * 22.0, -8.0 + sin(a) * 9.0), 2.6, col)
