class_name Lights
extends RefCounted
## Shared radial light texture for PointLight2D (player, campfires, settlements, projectiles).

const BASE_RADIUS := 128.0
static var _tex: Texture2D


static func texture() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.75))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 256
		t.height = 256
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_tex = t
	return _tex


## Lights only show at night: the world scales their energy by darkness (group "night_lights").
static func make(radius: float, color := Color.WHITE, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.add_to_group("night_lights")
	l.set_meta("base_energy", energy)
	l.texture = texture()
	l.texture_scale = radius / BASE_RADIUS
	l.color = color
	l.energy = energy
	return l
