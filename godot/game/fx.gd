extends Node2D
## Lightweight effects layer: floating numbers, rings, lightning arcs, bursts.
## One node draws everything to keep draw calls low.

var effects: Array = [] # {kind, pos, pos2, text, color, t, life, r}


func add(kind: String, pos: Vector2, color: Color, life: float, extra := {}) -> void:
	var e := {"kind": kind, "pos": pos, "color": color, "t": 0.0, "life": life}
	e.merge(extra)
	effects.append(e)


func text(pos: Vector2, s: String, color: Color, life := 0.8) -> void:
	add("text", pos, color, life, {"text": s})


func _process(delta: float) -> void:
	for e in effects:
		e["t"] += delta
	effects = effects.filter(func(e): return e["t"] < e["life"])
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for e in effects:
		var k: float = e["t"] / e["life"]
		var col: Color = e["color"]
		col.a = 1.0 - k
		var p: Vector2 = e["pos"]
		match e["kind"]:
			"text":
				var tp := p + Vector2(-60, -k * 24.0)
				draw_string_outline(font, tp, e["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 3, Color(0, 0, 0, 0.7 * (1.0 - k)))
				draw_string(font, tp, e["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 13, col)
			"ring":
				draw_arc(p, e.get("r", 40.0) * (0.3 + k * 0.7), 0, TAU, 48, col, 4.0 * (1.0 - k) + 1.0)
			"line":
				var a: Vector2 = p
				var b: Vector2 = e["pos2"]
				var pts := PackedVector2Array([a])
				for i in range(1, 5):
					pts.append(a.lerp(b, i / 5.0) + Vector2(randf_range(-7, 7), randf_range(-7, 7)))
				pts.append(b)
				draw_polyline(pts, col, 3.0)
			"burst":
				for i in 6:
					var d := Vector2.from_angle(i * TAU / 6.0) * k * 20.0
					draw_rect(Rect2(p + d - Vector2(2, 2), Vector2(4, 4)), col)
