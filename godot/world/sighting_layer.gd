extends Node2D
## Draws wild Gu sightings: a glowing ring in the Gu's path colour, a wriggling Gu,
## its name, and a progress arc while the player channels a capture.

var _t := 0.0


func _ready() -> void:
	Game.sighting_resolved.connect(_on_resolved)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_resolved(sg: Dictionary, caught: bool) -> void:
	var fx: Node = get_parent().get("fx")
	if fx:
		fx.add("ring", sg["pos"], Color("#ffd76b") if caught else Color("#ff6b6b"), 0.9, {"r": Sightings.RADIUS * 1.4})
		fx.add("burst", sg["pos"], GuDB.color_of(sg["def"]), 0.6)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for sg in Game.sightings:
		var c: Vector2 = sg["pos"]
		var col := GuDB.color_of(sg["def"])
		var pulse := 0.5 + 0.5 * sin(_t * 3.0 + sg["id"])
		var fill := col
		fill.a = 0.08 + 0.06 * pulse
		draw_circle(c, Sightings.RADIUS, fill)
		var ring := col
		ring.a = 0.45 + 0.35 * pulse
		draw_arc(c, Sightings.RADIUS, 0, TAU, 48, ring, 2.0)
		# the Gu itself: a little segmented worm wriggling in place
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(c + Vector2(-10 + i * 4, sin(_t * 6.0 + i * 0.9) * 3.0))
		draw_polyline(pts, col.lightened(0.3), 5.0)
		draw_circle(pts[5], 3.5, col.lightened(0.5))
		var glow := col
		glow.a = 0.25
		draw_circle(c, 14 + 3 * pulse, glow)
		# name
		var nm: String = GuDB.GU[sg["def"]]["name"]
		draw_string_outline(font, c + Vector2(-90, -22), nm, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, 3, Color(0, 0, 0, 0.8))
		draw_string(font, c + Vector2(-90, -22), nm, HORIZONTAL_ALIGNMENT_CENTER, 180, 12, col.lightened(0.4))
		# capture progress
		if sg["progress"] > 0.0:
			var k: float = clampf(sg["progress"] / sg["need"], 0.0, 1.0)
			draw_arc(c, Sightings.RADIUS + 6, -PI / 2, -PI / 2 + TAU * k, 48, Color("#ffd76b"), 4.0)
