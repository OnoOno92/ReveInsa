extends CanvasLayer
## In-game HUD: stat bars, clock, minimap, buttons, virtual stick, toasts, panels, modal.
## Runs while the tree is paused (panels pause the world).

const PanelsScript := preload("res://ui/panels.gd")

var world: Node2D
var root: Control
var name_label: Label
var hp_bar: Widgets.StatBar
var ess_bar: Widgets.StatBar
var hun_bar: Widgets.StatBar
var clock_label: Label
var mission_label: RichTextLabel
var buff_label: RichTextLabel
var tide_label: Label
var skill_bar: Control
var capture_label: Label
var zone_label: Label
var minimap: Widgets.MapView
var stones_btn: Button
var action_btn: Button
var absorb_btn: Button
var toasts: VBoxContainer
var panel_root: Control
var panel: PanelContainer
var panel_title: Label
var panel_scroll: ScrollContainer
var panel_body: VBoxContainer
var modal_root: Control
var panels: RefCounted
var current_panel := ""
var panel_args := {}

# virtual stick
var stick_index := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
const STICK_R := 60.0
var _map_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	panels = PanelsScript.new(self)
	root = Control.new()
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.draw.connect(_draw_stick)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area.call_deferred()

	# --- top-left: identity + bars
	var tl := VBoxContainer.new()
	tl.position = Vector2(14, 10)
	tl.add_theme_constant_override("separation", 4)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	name_label = Widgets.label("", 13)
	tl.add_child(name_label)
	hp_bar = Widgets.StatBar.new(Color("#d0392b"))
	ess_bar = Widgets.StatBar.new(Color("#3fae6a"))
	hun_bar = Widgets.StatBar.new(Color("#d08a2a"))
	for b in [hp_bar, ess_bar, hun_bar]:
		tl.add_child(b)
	buff_label = Widgets.rich("", 12)
	buff_label.custom_minimum_size = Vector2(260, 0)
	buff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(buff_label)
	mission_label = Widgets.rich("", 12)
	mission_label.custom_minimum_size = Vector2(260, 0)
	mission_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(mission_label)

	# --- top-center: clock + zone
	var tc := VBoxContainer.new()
	tc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tc.position = Vector2(-160, 10)
	tc.custom_minimum_size = Vector2(320, 0)
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc)
	clock_label = Widgets.label("", 14)
	zone_label = Widgets.label("", 12, UITheme.MUTED)
	tide_label = Widgets.label("", 18, Color("#ff8080"))
	tide_label.add_theme_constant_override("outline_size", 6)
	tide_label.add_theme_color_override("font_outline_color", Color(0.15, 0, 0))
	for l in [clock_label, zone_label, tide_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tc.add_child(l)

	# --- top-right: minimap, stones, dock
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-134, 10)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.add_theme_constant_override("separation", 6)
	root.add_child(tr)
	minimap = Widgets.MapView.new(70.0)
	minimap.custom_minimum_size = Vector2(120, 120)
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: toggle_panel("map"))
	tr.add_child(minimap)
	stones_btn = Widgets.button("", func(): Game.absorb_stone(), true, false, 13)
	stones_btn.flat = true
	stones_btn.add_theme_color_override("font_color", Color("#9be7ff"))
	stones_btn.tooltip_text = "Absorb a primeval stone to restore essence (Q)"
	tr.add_child(stones_btn)
	var dock := VBoxContainer.new()
	dock.add_theme_constant_override("separation", 6)
	dock.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(dock)
	for spec in [["Aperture", "aperture"], ["Bag", "bag"], ["Refine", "craft"], ["Guide", "help"]]:
		var b := Widgets.button(spec[0], toggle_panel.bind(spec[1]), true, false, 11)
		UITheme.round_button(b, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		dock.add_child(b)

	# --- bottom-right: absorb + action (touch-handled in _input for multi-touch)
	absorb_btn = Button.new()
	absorb_btn.text = "Absorb"
	absorb_btn.add_theme_font_size_override("font_size", 12)
	absorb_btn.clip_text = true
	UITheme.round_button(absorb_btn, 68)
	absorb_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	absorb_btn.add_theme_color_override("font_color", Color("#9be7ff"))
	absorb_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_btn = Button.new()
	action_btn.text = "-"
	UITheme.round_button(action_btn, 96)
	action_btn.add_theme_font_size_override("font_size", 18)
	action_btn.clip_text = true
	action_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var br := Widgets.row([absorb_btn, action_btn], 14)
	br.alignment = BoxContainer.ALIGNMENT_END
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-200, -120)
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(br)

	# --- skill bar (bottom centre): active Gu with cooldowns
	skill_bar = Widgets.SkillBar.new()
	skill_bar.combat = world.combat if world else null
	skill_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.add_child(skill_bar)
	capture_label = Widgets.label("", 15, Color("#ffe9a8"))
	capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_label.add_theme_constant_override("outline_size", 5)
	capture_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	capture_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	capture_label.offset_left = -200
	capture_label.offset_right = 200
	capture_label.offset_top = -100
	capture_label.offset_bottom = -74
	root.add_child(capture_label)

	# --- toasts
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-250, 64)
	toasts.custom_minimum_size = Vector2(500, 0)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 6)
	root.add_child(toasts)

	# --- panel
	panel_root = _overlay()
	panel = PanelContainer.new()
	panel_root.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	panel.add_child(pv)
	panel_title = Widgets.label("", 19, UITheme.GOLD)
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(Widgets.row([panel_title, Widgets.button("Close", close_panel, true, false, 13)]))
	pv.add_child(HSeparator.new())
	panel_scroll = ScrollContainer.new()
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(panel_scroll)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(panel_body)

	modal_root = _overlay()

	Game.toast.connect(toast)
	Game.changed.connect(_on_changed)
	Game.npc_interact.connect(_on_npc)
	Game.plot_interact.connect(func(pl): open_panel("plot", {"plot": pl["id"]}))
	minimap.refresh()


func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(dim)
	root.add_child(o)
	return o


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	var p := Game.p
	if p.is_empty():
		return
	name_label.text = "%s  |  %s %s  (Grade %s)" % [p["name"], Aperture.RANK_NAMES[p["rank"]], Aperture.STAGE_NAMES[p["stage"]], Game.grade_of(p["aptitude"])]
	hp_bar.set_values(p["hp"], Game.max_hp(), "HP %d / %d" % [ceili(p["hp"]), roundi(Game.max_hp())], Game.shield)
	ess_bar.color = Aperture.essence_color(p["rank"])
	ess_bar.set_values(p["essence"], Game.max_essence(), "Essence %d / %d" % [floori(p["essence"]), roundi(Game.max_essence())])
	hun_bar.set_values(p["hunger"], 100.0, "Hunger %d" % ceili(p["hunger"]))
	var t := Game.tod()
	var phase := "Dawn" if t < 0.04 else ("Day" if t < 0.58 else ("Dusk" if t < 0.68 else "Night"))
	var hours := int(fmod(t * 24.0 + 6.0, 24.0))
	clock_label.text = "Day %d  -  %02d:00  %s" % [Game.day() + 1, hours, phase]
	var z := Game.world.zone_at(p["pos"])
	var zone_name: String = {"wild": "Southern Border Wilds", "deep": "Deep Wilderness - dangerous", "wall": "Regional Wall"}.get(z, "")
	for poi in WorldData.POIS:
		if WorldData.ZONE_IDS[poi["zone"]] == z:
			zone_name = poi["name"]
	zone_label.text = zone_name
	zone_label.add_theme_color_override("font_color", UITheme.BAD if z == "forbidden" else (UITheme.JADE if z in ["village", "city"] else UITheme.MUTED))
	stones_btn.text = "%d primeval stones" % p["stones"]
	var ch := Game.channelling()
	capture_label.text = "" if ch.is_empty() else "Binding %s... %d%%  (stay in the ring)" % [GuDB.GU[ch["def"]]["name"], roundi(100.0 * ch["progress"] / ch["need"])]
	minimap.queue_redraw() # sighting markers pulse
	# beast tide banner
	if Game.tide_active():
		tide_label.text = "BEAST TIDE - %d slain" % int(Game.flags.get("tide_kills", 0))
		tide_label.modulate.a = 0.65 + 0.35 * sin(Game.clock * 5.0)
	elif Game.is_tide_day():
		tide_label.text = "Beast tide tonight"
		tide_label.modulate.a = 0.8
	else:
		tide_label.text = ""
	# active pill buffs
	var bl: Array[String] = []
	for id in p["buffs"]:
		bl.append("[color=%s]%s %ds[/color]" % [ItemDB.ITEMS[id]["color"], ItemDB.ITEMS[id]["name"].trim_suffix(" Pill"), ceili(Game.buff_seconds(id))])
	if p.get("breakthrough_aid", false):
		bl.append("[color=#ffd76b]Breakthrough Aid ready[/color]")
	var bt := "  ".join(bl)
	if buff_label.text != bt:
		buff_label.text = bt
	# mission tracker
	var lines: Array[String] = []
	for q in p["quests"]["active"]:
		var done := Quests.is_complete(q, p["inventory"])
		lines.append("[color=%s]%s %s %d/%d[/color]" % ["#7cfc8a" if done else "#e8dfc8", "v" if done else "-", q["title"], Quests.progress(q, p["inventory"]), q["count"]])
	var mt := "\n".join(lines)
	if mission_label.text != mt:
		mission_label.text = mt
	var label: String = world.interact.get("label", "-") if world else "-"
	action_btn.text = label
	action_btn.modulate = Color.WHITE if label != "-" else Color(1, 1, 1, 0.6)
	_map_t -= delta
	if _map_t <= 0.0:
		_map_t = 0.5
		minimap.refresh()
	if panel_root.visible:
		var vs := root.size
		var w := minf(780.0, vs.x - 24.0)
		var h := vs.y - 24.0
		panel.position = Vector2((vs.x - w) / 2.0, 12)
		panel.size = Vector2(w, h)
	root.queue_redraw()


func _draw_stick() -> void:
	if stick_index < 0:
		return
	root.draw_circle(stick_origin, STICK_R, Color(1, 1, 1, 0.18))
	root.draw_arc(stick_origin, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	var off := (stick_pos - stick_origin).limit_length(STICK_R)
	root.draw_circle(stick_origin + off, 26, Color(1, 1, 1, 0.55))


## Keep the HUD clear of phone notches / rounded corners.
func _apply_safe_area() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if not OS.has_feature("mobile") or safe.size == Vector2i.ZERO or win.x <= 0.0:
		return
	var k := get_viewport().get_visible_rect().size / win
	root.offset_left = safe.position.x * k.x
	root.offset_top = safe.position.y * k.y
	root.offset_right = -(win.x - safe.end.x) * k.x
	root.offset_bottom = -(win.y - safe.end.y) * k.y


## Android back button closes the open panel instead of quitting.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current_panel != "":
			close_panel()


# ------------------------------------------------------------------ input
func _hit(c: Control, pos: Vector2) -> bool:
	return c.is_visible_in_tree() and c.get_global_rect().has_point(pos)


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		if stick_index >= 0:
			stick_index = -1
			Game.stick = Vector2.ZERO
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _hit(action_btn, event.position):
				Game.action_requested = true
				get_viewport().set_input_as_handled()
				return
			if _hit(absorb_btn, event.position):
				Game.absorb_stone()
				get_viewport().set_input_as_handled()
				return
			if stick_index < 0 and event.position.x < root.size.x * 0.5 and event.position.y > 90:
				stick_index = event.index
				stick_origin = event.position
				stick_pos = event.position
				Game.stick = Vector2.ZERO
		elif event.index == stick_index:
			stick_index = -1
			Game.stick = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == stick_index:
		stick_pos = event.position
		var off: Vector2 = stick_pos - stick_origin
		Game.stick = Vector2.ZERO if off.length() < 6.0 else off.limit_length(STICK_R) / STICK_R


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if modal_root.visible:
		return
	if event.is_action("open_aperture"): toggle_panel("aperture")
	elif event.is_action("open_bag"): toggle_panel("bag")
	elif event.is_action("open_craft"): toggle_panel("craft")
	elif event.is_action("open_map"): toggle_panel("map")
	elif event.is_action("absorb"): Game.absorb_stone()
	elif event.is_action("cancel"): close_panel()
	elif event.is_action("rotate") and current_panel == "aperture": panels.rotate()
	else: return
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ panels & modal
func toggle_panel(kind: String) -> void:
	if current_panel == kind:
		close_panel()
	else:
		open_panel(kind)


func open_panel(kind: String, args := {}) -> void:
	current_panel = kind
	panel_args = args
	panel_root.visible = true
	get_tree().paused = true
	panel_scroll.scroll_vertical = 0
	_rebuild_panel()


func close_panel() -> void:
	if current_panel == "":
		return
	current_panel = ""
	panels.on_close()
	panel_root.visible = false
	get_tree().paused = modal_root.visible
	Game.save_game()


func _rebuild_panel() -> void:
	var keep := panel_scroll.scroll_vertical
	for c in panel_body.get_children():
		panel_body.remove_child(c)
		c.queue_free()
	panel_title.text = panels.title(current_panel)
	panels.build(current_panel, panel_body, panel_args)
	await get_tree().process_frame
	panel_scroll.scroll_vertical = keep


func _on_changed() -> void:
	if current_panel != "":
		_rebuild_panel()


func _on_npc(npc: Dictionary) -> void:
	match npc["role"]:
		"merchant": open_panel("shop", {"shop": npc["shop"], "tab": "gu"})
		"elder": open_panel("elder", {"clan": npc["poi"] == "village", "tab": "cultivate"})
		"caravan": open_panel("caravan", {"dest": npc["dest"]})


func show_modal(title_text: String, body: Array, button_text: String) -> void:
	for c in modal_root.get_children().slice(1):
		c.queue_free()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(minf(480.0, root.size.x - 32.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var t := Widgets.label(title_text, 22, UITheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for c in body:
		v.add_child(c)
	var b := Widgets.button(button_text, func():
		modal_root.visible = false
		get_tree().paused = current_panel != "", true, true, 16)
	v.add_child(b)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(card)
	modal_root.add_child(center)
	modal_root.visible = true
	get_tree().paused = true


func show_ceremony(grade: String, aptitude: float) -> void:
	var starters: Array = Game.p["gu"].map(func(g): return GuDB.GU[g["def"]]["name"])
	var grade_col: String = {"A": "#ffd76b", "B": "#9ecbff", "C": "#7cfc8a", "D": "#aaaaaa"}[grade]
	show_modal("Aperture Awakening Ceremony", [
		Widgets.rich("On the clan's sacred day, the elders release a [b]Hope Gu[/b] into your body. Light pours into your belly - your aperture opens."),
		Widgets.rich("[center][font_size=30][color=%s]Grade %s aptitude[/color][/font_size]\n[color=#a69f8f]%d%% primeval sea[/color][/center]" % [grade_col, grade, roundi(aptitude * 100)]),
		Widgets.rich("The clan grants you [b]%s[/b] and 30 primeval stones. Gu must be fed or they will starve and die." % " and ".join(starters)),
		Widgets.rich("[color=#a69f8f]Survive. Hunt. Refine Gu. Advance your cultivation. Somewhere in the northwest lies an unclaimed inheritance...[/color]"),
	], "Step out into the world")


# ------------------------------------------------------------------ toasts
func toast(msg: String, kind := "info") -> void:
	var pc := PanelContainer.new()
	var border: Color = {"good": UITheme.GOOD, "bad": UITheme.BAD, "gold": UITheme.GOLD}.get(kind, Color(0.83, 0.66, 0.23, 0.4))
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.05, 0.08, 0.88), border, 8, 1, 6))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Widgets.label(msg, 13, UITheme.kind_color(kind))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	toasts.add_child(pc)
	while toasts.get_child_count() > 5:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(3.6)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)
