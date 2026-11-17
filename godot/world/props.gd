extends Node2D
## Static world props drawn procedurally: resource nodes, NPCs, signs, campfires.
## kind: "node" | "npc" | "sign" | "campfire"

var kind := "node"
var data: Dictionary
var highlighted := false:
	set(v):
		if v != highlighted:
			highlighted = v
			queue_redraw()
var _avail := true
var _t := 0.0


func setup(k: String, d: Dictionary) -> void:
	kind = k
	data = d
	position = d["pos"]
	if kind == "campfire":
		add_child(Lights.make(230.0, Color(1.0, 0.7, 0.4), 1.1))
		set_process(true)
	else:
		set_process(false)
	if kind == "node":
		_avail = is_available()


func is_available() -> bool:
	if data["type"] == "chest":
		return not Game.flags.get("ruins_looted", false)
	return data["regrow_day"] <= Game.time


## Called periodically by the world so regrown nodes redraw.
func refresh() -> void:
	if kind == "node":
		var a := is_available()
		if a != _avail:
			_avail = a
			queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		"node": _draw_node()
		"npc": _draw_npc()
		"sign":
			draw_rect(Rect2(-2, -16, 4, 18), Color.html("#5a3b22"))
			draw_rect(Rect2(-12, -22, 24, 10), Color.html("#a77b4f"))
		"campfire" when data.get("kind", "campfire") == "furnace":
			# stone alchemy furnace with a glowing mouth and a bronze cauldron lid
			_shadow(16)
			draw_rect(Rect2(-14, -22, 28, 26), Color("#5f5a55"))
			draw_rect(Rect2(-14, -22, 28, 4), Color("#77716a"))
			var glow := 0.6 + 0.4 * sin(_t * 5.0)
			draw_rect(Rect2(-7, -10, 14, 10), Color(1.0, 0.55 + 0.2 * glow, 0.2))
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -22), Vector2(12, -22), Vector2(8, -30), Vector2(-8, -30)]), Color("#b0873a"))
			for i in 3:
				var sy := fmod(_t * 18.0 + i * 9.0, 26.0)
				draw_circle(Vector2(sin(_t * 2.0 + i) * 3.0, -32 - sy), 3.0 + sy * 0.15, Color(0.85, 0.85, 0.9, 0.35 * (1.0 - sy / 26.0)))
		"campfire":
			draw_rect(Rect2(-10, -2, 20, 4), Color.html("#4a3422"))
			var f := sin(_t * 12.0) * 2.0
			draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(0, -22 - f), Vector2(7, 0)]), Color.html("#ff9a3c"))
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(0, -12 + f), Vector2(3, 0)]), Color.html("#ffe08a"))


func _shadow(w := 12.0) -> void:
	draw_set_transform(Vector2(0, 4), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)


func _draw_node() -> void:
	_shadow()
	match data["type"]:
		"tree":
			draw_rect(Rect2(-3, -14, 6, 18), Color.html("#5a3b22"))
			if _avail:
				draw_circle(Vector2(0, -22), 15, Color.html("#2f5a2a"))
				draw_circle(Vector2(-4, -26), 10, Color.html("#3d7535"))
		"rock":
			if _avail:
				_ellipse(Vector2(0, -4), Vector2(12, 9), Color.html("#8a8a8a"))
				_ellipse(Vector2(-3, -7), Vector2(6, 4), Color.html("#a5a5a5"))
		"jade":
			if _avail:
				_ellipse(Vector2(0, -4), Vector2(12, 9), Color.html("#6c7a72"))
				draw_colored_polygon(PackedVector2Array([Vector2(-2, -16), Vector2(4, -6), Vector2(-5, -4)]), Color.html("#9ff0cf"))
		"bush":
			draw_circle(Vector2(0, -6), 10, Color.html("#2e6b34"))
			if _avail:
				for i in 4:
					draw_rect(Rect2(-6 + i * 4, -10 + (i % 2) * 5, 3, 3), Color.html("#d8336b"))
		"orchid":
			if _avail:
				draw_rect(Rect2(-1, -10, 2, 10), Color.html("#3d6b3a"))
				for i in 5:
					var a := i * TAU / 5.0
					draw_circle(Vector2(cos(a) * 4.0, -12 + sin(a) * 4.0), 3, Color.html("#cfe4ff"))
		"chest":
			draw_rect(Rect2(-16, -10, 32, 14), Color.html("#5c5246"))
			draw_circle(Vector2(0, -18), 7, Color.html("#d4a93a") if _avail else Color.html("#444444"))
			if _avail:
				draw_arc(Vector2(0, -18), 11, 0, TAU, 24, Color(1, 0.85, 0.4, 0.6), 2.0)
	if highlighted:
		draw_set_transform(Vector2(0, 4), 0, Vector2(1, 0.45))
		draw_arc(Vector2.ZERO, 16, 0, TAU, 24, Color(1, 0.94, 0.7, 0.9), 2.0)
		draw_set_transform(Vector2.ZERO)


func _draw_npc() -> void:
	var col := Color.html("#d4a93a") if data["role"] == "merchant" else (Color.html("#7fb3d5") if data["role"] == "elder" else Color.html("#a0785a"))
	_shadow(10)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 6), Vector2(10, 6), Vector2(6, -12), Vector2(-6, -12)]), col)
	draw_circle(Vector2(0, -17), 6, Color.html("#f1d6b8"))
	if data["role"] == "caravan":
		draw_rect(Rect2(12, -8, 22, 14), Color.html("#6b4a2b"))
		draw_circle(Vector2(16, 7), 4, Color.html("#333333"))
		draw_circle(Vector2(30, 7), 4, Color.html("#333333"))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-80, -28), data["name"], HORIZONTAL_ALIGNMENT_CENTER, 160, 11, 3, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-80, -28), data["name"], HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color.WHITE)
	if highlighted:
		draw_arc(Vector2(0, -6), 18, 0, TAU, 24, Color(1, 0.94, 0.7, 0.9), 2.0)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	draw_set_transform(c, 0, Vector2(1, r.y / r.x))
	draw_circle(Vector2.ZERO, r.x, col)
	draw_set_transform(Vector2.ZERO)
