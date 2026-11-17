class_name UITheme
extends RefCounted
## Ink-and-gold theme built in code. Swap for a .tres theme in the editor later if desired.

const INK := Color("#12101a")
const PANEL := Color(0.07, 0.06, 0.1, 0.97)
const GOLD := Color("#d4a93a")
const JADE := Color("#6fd3a8")
const PAPER := Color("#f3ead7")
const MUTED := Color("#a69f8f")
const BAD := Color("#ff6b6b")
const GOOD := Color("#7cfc8a")
const WARN := Color("#ffb347")

static var _theme: Theme


static func box(bg: Color, border := Color(0.83, 0.66, 0.23, 0.45), radius := 10, bw := 1, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", PAPER)
	t.set_color("default_color", "RichTextLabel", PAPER)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, GOLD, 14, 1, 12))
	t.set_stylebox("panel", "Panel", box(PANEL, GOLD, 14, 1, 12))
	t.set_stylebox("normal", "Button", box(Color("#241f31"), Color(0.83, 0.66, 0.23, 0.35), 8, 1, 8))
	t.set_stylebox("hover", "Button", box(Color("#2f2840"), Color(0.83, 0.66, 0.23, 0.7), 8, 1, 8))
	t.set_stylebox("pressed", "Button", box(Color("#3a3150"), GOLD, 8, 1, 8))
	t.set_stylebox("disabled", "Button", box(Color("#1a1722"), Color(1, 1, 1, 0.08), 8, 1, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.58, 0.55, 0.6))
	t.set_stylebox("normal", "LineEdit", box(Color("#15121e"), GOLD, 8, 1, 10))
	t.set_stylebox("focus", "LineEdit", box(Color("#15121e"), GOLD, 8, 2, 10))
	t.set_color("font_color", "LineEdit", PAPER)
	_theme = t
	return t


static func gold_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(Color("#8a661b"), Color("#f0cf72"), 8, 1, 8))
	b.add_theme_stylebox_override("hover", box(Color("#a17a22"), Color("#f0cf72"), 8, 1, 8))
	b.add_theme_stylebox_override("pressed", box(Color("#6e5115"), Color("#f0cf72"), 8, 2, 8))
	b.add_theme_color_override("font_color", Color("#fff6dd"))


static func round_button(b: Button, d: float) -> void:
	b.custom_minimum_size = Vector2(d, d)
	for st in ["normal", "hover", "pressed"]:
		var s := box(Color(0.12, 0.1, 0.17, 0.82), Color(0.83, 0.66, 0.23, 0.55 if st == "normal" else 0.9), int(d / 2), 2, 4)
		b.add_theme_stylebox_override(st, s)


static func kind_color(kind: String) -> Color:
	match kind:
		"good": return GOOD
		"bad": return Color("#ffd0d0")
		"gold": return Color("#ffe9a8")
	return PAPER
