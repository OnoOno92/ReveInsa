extends Control
## Interactive aperture grid. Draws placed Gu, selection, and a placement preview.

signal cell_clicked(cell: Vector2i)

var selected := -1 # uid
var rot := 0
var hover := Vector2i(-1, -1)
var cell_px := 46.0
const GAP := 3.0
const PAD := 8.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP


func grid_size() -> int:
	return Game.ap_size()


func _process(_d: float) -> void:
	queue_redraw() # shiny shimmer
	var n := grid_size()
	var want := Vector2(PAD * 2 + n * cell_px + (n - 1) * GAP, PAD * 2 + n * cell_px + (n - 1) * GAP)
	if custom_minimum_size != want:
		custom_minimum_size = want


func _cell_at(pos: Vector2) -> Vector2i:
	var c := ((pos - Vector2(PAD, PAD)) / (cell_px + GAP)).floor()
	var n := grid_size()
	if c.x < 0 or c.y < 0 or c.x >= n or c.y >= n:
		return Vector2i(-1, -1)
	return Vector2i(c)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _cell_at(event.position)
		if c != hover:
			hover = c
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := _cell_at(event.position)
		if c.x >= 0:
			hover = c
			cell_clicked.emit(c)
			accept_event()


func _rect(x: int, y: int) -> Rect2:
	return Rect2(PAD + x * (cell_px + GAP), PAD + y * (cell_px + GAP), cell_px, cell_px)


func _draw() -> void:
	var n := grid_size()
	var p := Game.p
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1b1626"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.83, 0.66, 0.23, 0.45), false, 1.0)
	var occ := Aperture.occupancy(n, p["placed"], p["gu"])
	var inactive: Dictionary = Game.build["inactive"]
	var labeled := {}
	var font := ThemeDB.fallback_font
	for y in n:
		for x in n:
			var r := _rect(x, y)
			var uid := occ[y * n + x]
			if uid == 0:
				draw_rect(r, Color(1, 1, 1, 0.05))
				continue
			var inst := Aperture.find_inst(p["gu"], uid)
			var col := GuDB.color_of(inst["def"])
			if inactive.has(uid):
				col = col.darkened(0.6)
			# extend into gaps toward same-Gu neighbours so a Gu reads as one piece
			var rr := r
			if x + 1 < n and occ[y * n + x + 1] == uid: rr.size.x += GAP
			if y + 1 < n and occ[(y + 1) * n + x] == uid: rr.size.y += GAP
			draw_rect(rr, col)
			if uid == selected:
				draw_rect(r.grow(-1), Color.WHITE, false, 2.0)
			if inst.get("shiny", false):
				var tw := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004 + x + y)
				draw_rect(r.grow(-2), Color(1.0, 0.85, 0.4, 0.4 + 0.5 * tw), false, 2.0)
			if not labeled.has(uid):
				labeled[uid] = true
				var nm: String = GuDB.GU[inst["def"]]["name"]
				draw_string(font, r.position + Vector2(3, 14), _abbr(nm), HORIZONTAL_ALIGNMENT_LEFT, cell_px * 2, 11, Color(0.05, 0.05, 0.08))
	# placement preview
	if selected >= 0 and hover.x >= 0:
		var inst := Aperture.find_inst(p["gu"], selected)
		if not inst.is_empty():
			var ok := Aperture.can_place(n, p["placed"], p["gu"], inst["def"], hover.x, hover.y, rot, selected)
			var pc := Color(0.49, 0.99, 0.54, 0.9) if ok else Color(1, 0.42, 0.42, 0.9)
			for c in Aperture.shape_cells(inst["def"], rot):
				var cx := hover.x + c.x
				var cy := hover.y + c.y
				if cx < n and cy < n:
					draw_rect(_rect(cx, cy).grow(-2), pc, false, 3.0)


static func _abbr(nm: String) -> String:
	var w := nm.trim_suffix(" Gu").split(" ")
	if w.size() == 1:
		return w[0].substr(0, 6)
	var s := ""
	for part in w:
		s += part.substr(0, 1)
	return s.substr(0, 4)
