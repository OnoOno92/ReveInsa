class_name Widgets
extends RefCounted
## Small UI building helpers + custom-drawn widgets (stat bar, minimap, Gu shape icon).


static func label(text: String, size := 15, color := UITheme.PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rich(bbcode: String, size := 14) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func button(text: String, cb: Callable, enabled := true, gold := false, size := 14) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	if gold and enabled:
		UITheme.gold_button(b)
	return b


static func row(children: Array, sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		h.add_child(c)
	return h


static func header(text: String) -> Label:
	var l := label(text, 16, UITheme.GOLD)
	return l


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


## A horizontal stat bar with text.
class StatBar extends Control:
	var value := 1.0
	var max_value := 1.0
	var overlay := 0.0 # e.g. shield, drawn on top
	var color := Color.RED
	var text := ""

	func _init(c: Color) -> void:
		color = c
		custom_minimum_size = Vector2(250, 17)
		mouse_filter = MOUSE_FILTER_IGNORE

	func set_values(v: float, m: float, t: String, ov := 0.0) -> void:
		value = v; max_value = maxf(m, 0.001); text = t; overlay = ov
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(value / max_value, 0, 1), size.y)), color)
		if overlay > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(overlay / max_value, 0, 1), size.y)), Color(0.43, 0.75, 1.0, 0.55))
		draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)
		var f := ThemeDB.fallback_font
		draw_string_outline(f, Vector2(6, size.y - 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(6, size.y - 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## Tiny drawing of a Gu's shape in its path colour.
class GuIcon extends Control:
	var def_id := ""
	var rot := 0
	const C := 9.0

	func _init(id: String, r := 0) -> void:
		def_id = id
		rot = r
		var cells := Aperture.shape_cells(def_id, rot)
		var w := 0
		var h := 0
		for c in cells:
			w = maxi(w, c.x + 1); h = maxi(h, c.y + 1)
		custom_minimum_size = Vector2(w * C, h * C)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for c in Aperture.shape_cells(def_id, rot):
			draw_rect(Rect2(c.x * C, c.y * C, C - 1, C - 1), GuDB.color_of(def_id))


## Minimap / world map with fog of war.
class MapView extends Control:
	var span := 70.0 # tiles shown; <= 0 means whole map
	var tex: ImageTexture
	var base: Image
	var labels := false

	func _init(tiles_shown: float, show_labels := false) -> void:
		span = tiles_shown
		labels = show_labels

	func refresh() -> void:
		var w := Game.world
		if base == null:
			base = Image.create(WorldData.W, WorldData.H, false, Image.FORMAT_RGB8)
		var fog := Color(0.055, 0.055, 0.086)
		for y in WorldData.H:
			for x in WorldData.W:
				var i := y * WorldData.W + x
				base.set_pixel(x, y, Color.html(WorldData.TILE_COLORS[w.tiles[i]]) if w.explored[i] else fog)
		if tex == null:
			tex = ImageTexture.create_from_image(base)
		else:
			tex.update(base)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.055, 0.086))
		if tex == null:
			return
		var ppos: Vector2 = Game.p["pos"] / WorldData.TILE
		var region: Rect2
		if span > 0.0:
			region = Rect2(ppos - Vector2(span, span) / 2.0, Vector2(span, span))
		else:
			region = Rect2(0, 0, WorldData.W, WorldData.H)
		var clipped := region.intersection(Rect2(0, 0, WorldData.W, WorldData.H))
		var sc := size / region.size
		if clipped.has_area():
			draw_texture_rect_region(tex, Rect2((clipped.position - region.position) * sc, clipped.size * sc), clipped)
		var f := ThemeDB.fallback_font
		for poi in WorldData.POIS:
			if not Game.world.explored[poi["ty"] * WorldData.W + poi["tx"]]:
				continue
			var pp := (Vector2(poi["tx"], poi["ty"]) - region.position) * sc
			if not Rect2(Vector2.ZERO, size).has_point(pp):
				continue
			var col := Color("#ff4d6d") if poi["id"] == "forbidden" else (Color("#ffd76b") if poi["id"] == "ruins" else Color.WHITE)
			draw_rect(Rect2(pp - Vector2(3, 3), Vector2(6, 6)), col)
			if labels:
				draw_string_outline(f, pp + Vector2(-90, -8), poi["name"], HORIZONTAL_ALIGNMENT_CENTER, 180, 12, 3, Color.BLACK)
				draw_string(f, pp + Vector2(-90, -8), poi["name"], HORIZONTAL_ALIGNMENT_CENTER, 180, 12, col)
		# wild Gu sightings: pulsing dots in the Gu's path colour
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
		for sg in Game.sightings:
			var sp: Vector2 = ((sg["pos"] as Vector2) / WorldData.TILE - region.position) * sc
			sp = sp.clamp(Vector2(4, 4), size - Vector2(4, 4)) # off-map rumours pin to the edge
			var sc_col := GuDB.color_of(sg["def"])
			draw_circle(sp, 6.0 * pulse + 2.0, Color(0, 0, 0, 0.6))
			draw_circle(sp, 5.0 * pulse + 1.5, sc_col)
		# the nemesis: a red diamond where he was last seen (live while he hunts you)
		var nem: Dictionary = Game.nemesis
		if not nem.is_empty() and nem["alive"]:
			var at: Vector2 = nem["pos"] if Game.nemesis_present else nem["last_seen"]
			var np: Vector2 = (at / WorldData.TILE - region.position) * sc
			np = np.clamp(Vector2(5, 5), size - Vector2(5, 5))
			var d := 5.0 + 1.5 * pulse
			draw_colored_polygon(PackedVector2Array([np + Vector2(0, -d - 1), np + Vector2(d + 1, 0), np + Vector2(0, d + 1), np + Vector2(-d - 1, 0)]), Color(0, 0, 0, 0.7))
			draw_colored_polygon(PackedVector2Array([np + Vector2(0, -d), np + Vector2(d, 0), np + Vector2(0, d), np + Vector2(-d, 0)]), Color("#ff4d6d"))
		draw_circle((ppos - region.position) * sc, 3.5, Color.YELLOW)
		if labels:
			var wc := Color(0.8, 0.75, 1.0)
			draw_string(f, Vector2(0, 14), "Central Continent", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, wc)
			draw_string(f, Vector2(4, size.y / 2), "Western Desert", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, wc)
			draw_string(f, Vector2(0, size.y / 2), "Eastern Sea", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 11, wc)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.83, 0.66, 0.23, 0.5), false, 1.0)


## Skill bar: one icon per active attack / heal, with a cooldown shade + countdown,
## red when essence is short, gold frame for killer moves.
class SkillBar extends Control:
	const S := 44.0
	const GAP := 6.0
	var combat: Node # world combat node (owns cooldown timers)

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _skills() -> Array:
		var out: Array = []
		if Game.build.is_empty():
			return out
		for a in Game.build["attacks"]:
			out.append(a)
		for h in Game.build["heals"]:
			out.append(h)
		return out

	func _process(_d: float) -> void:
		var n := _skills().size()
		var w := maxf(0.0, n * S + (n - 1) * GAP)
		if custom_minimum_size.x != w:
			custom_minimum_size = Vector2(w, S)
			# centred on the bottom-centre anchor, 18px above the bottom edge
			offset_left = -w / 2.0
			offset_right = w / 2.0
			offset_top = -S - 18.0
			offset_bottom = -18.0
		queue_redraw()

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var i := 0
		for a in _skills():
			var r := Rect2(i * (S + GAP), 0, S, S)
			i += 1
			var is_heal: bool = not a.has("kind")
			var killer: bool = a.get("is_killer", false)
			var col: Color = Color("#7cfc8a") if is_heal else (GuDB.path_color(a["path"]) if a.has("path") else Color("#ffd76b"))
			draw_rect(r, Color(0.06, 0.05, 0.09, 0.85))
			draw_rect(r.grow(-3), col.darkened(0.25))
			# label: first letters of the name
			var words: PackedStringArray = str(a["name"]).trim_suffix(" Gu").split(" ")
			var abbr := ""
			for wd in words:
				abbr += wd.substr(0, 1)
			draw_string_outline(f, r.position + Vector2(0, 17), abbr.substr(0, 3), HORIZONTAL_ALIGNMENT_CENTER, S, 13, 3, Color(0, 0, 0, 0.8))
			draw_string(f, r.position + Vector2(0, 17), abbr.substr(0, 3), HORIZONTAL_ALIGNMENT_CENTER, S, 13, Color.WHITE)
			# cooldown shade (drains from the top as it recharges)
			var t: float = combat.timers.get(a["key"], 0.0) if combat else 0.0
			var cd: float = maxf(0.01, a["cooldown"])
			var k := clampf(t / cd, 0.0, 1.0)
			if k > 0.02:
				draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(S - 6, (S - 6) * k)), Color(0, 0, 0, 0.6))
				if t > 0.5:
					var txt := "%.1f" % t
					draw_string_outline(f, r.position + Vector2(0, S - 6), txt, HORIZONTAL_ALIGNMENT_CENTER, S, 12, 3, Color(0, 0, 0, 0.9))
					draw_string(f, r.position + Vector2(0, S - 6), txt, HORIZONTAL_ALIGNMENT_CENTER, S, 12, Color.WHITE)
			# not enough essence
			if Game.p["essence"] < a["cost"]:
				draw_rect(r.grow(-3), Color(0.9, 0.15, 0.15, 0.35))
			var border := Color("#ffd76b") if killer else Color(1, 1, 1, 0.25)
			draw_rect(r, border, false, 2.0 if killer else 1.0)



## Four small bars for a Gu's potentials (0-31): Power, Speed, Efficiency, Durability.
class PotentialBars extends Control:
	var inst: Dictionary
	const COLS := {"power": Color("#ff8a6b"), "speed": Color("#9ecbff"), "eff": Color("#7cfc8a"), "dur": Color("#e0c070")}
	const LABELS := {"power": "PWR", "speed": "SPD", "eff": "EFF", "dur": "DUR"}

	func _init(gu_inst: Dictionary) -> void:
		inst = gu_inst
		custom_minimum_size = Vector2(200, 4 * 13)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var y := 0.0
		var nat: Array = GuRoll.NATURES.get(inst.get("nature", "steady"), ["", ""])
		for k in GuRoll.KEYS:
			var v: int = inst.get("pot", {}).get(k, 0)
			var tag := " +" if nat[0] == k else (" -" if nat[1] == k else "")
			draw_string(f, Vector2(0, y + 10), LABELS[k] + tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.78, 0.7))
			var bx := 44.0
			var bw := size.x - bx - 26.0
			draw_rect(Rect2(bx, y + 3, bw, 7), Color(0, 0, 0, 0.45))
			draw_rect(Rect2(bx, y + 3, bw * v / 31.0, 7), COLS[k])
			draw_string(f, Vector2(size.x - 22, y + 10), str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			y += 13.0
