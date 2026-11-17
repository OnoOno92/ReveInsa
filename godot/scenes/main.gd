extends Node2D
## Placeholder entry scene. The real game will be ported here from the web prototype.

func _ready() -> void:
	var label := Label.new()
	label.text = "Gu Wilds — Godot project ready"
	label.position = Vector2(40, 40)
	label.add_theme_font_size_override("font_size", 32)
	add_child(label)

func _draw() -> void:
	draw_rect(Rect2(40, 100, 300, 160), Color(0.37, 0.56, 0.24))
	draw_circle(Vector2(190, 180), 40, Color(0.62, 0.8, 1.0))
