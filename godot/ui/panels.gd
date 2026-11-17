extends RefCounted
## Builds the contents of each HUD panel. Rebuilt whenever Game.changed fires.

const ApertureGridScript := preload("res://ui/aperture_grid.gd")

var hud: CanvasLayer
var selected := -1 # Gu uid selected in the aperture editor
var rot := 0
var grid: Control


func _init(h: CanvasLayer) -> void:
	hud = h


func title(kind: String) -> String:
	return {
		"aperture": "Aperture", "bag": "Bag", "craft": "Craft & Gu Refinement", "shop": "Trade",
		"elder": "Clan Elder", "plot": "Spirit Field", "caravan": "Caravan", "map": "Southern Border", "help": "Gu Master Guide",
	}.get(kind, kind)


func on_close() -> void:
	selected = -1
	rot = 0


func rotate() -> void:
	rot = (rot + 1) % 4
	hud._rebuild_panel()


func build(kind: String, box: VBoxContainer, args: Dictionary) -> void:
	match kind:
		"aperture": _aperture(box)
		"bag": _bag(box)
		"craft": _craft(box, args)
		"shop": _shop(box, args)
		"elder": _elder(box, args)
		"caravan": _caravan(box, args)
		"map": _map(box)
		"help": _help(box)
		"plot": _plot(box, args)


# ------------------------------------------------------------------ aperture
func _aperture(box: VBoxContainer) -> void:
	var p := Game.p
	var n := Game.ap_size()
	var b: Dictionary = Game.build
	var info := Widgets.rich("%s aperture  -  %dx%d  -  [color=%s]%s essence[/color]" % [
		Aperture.RANK_NAMES[p["rank"]], n, n, Widgets.hex(Aperture.essence_color(p["rank"])), Aperture.ESSENCE_NAMES[p["rank"]]], 13)
	box.add_child(info)

	grid = ApertureGridScript.new()
	grid.selected = selected
	grid.rot = rot
	grid.cell_clicked.connect(_on_cell)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	var top := Widgets.row([grid, side], 14)
	box.add_child(top)

	var sel := Aperture.find_inst(p["gu"], selected)
	if sel.is_empty():
		side.add_child(Widgets.label("Tap a Gu in your pouch, then tap a cell to place it. Tap a placed Gu to move it. Gu that touch form synergies.", 13, UITheme.MUTED))
	else:
		var d: Dictionary = GuDB.GU[sel["def"]]
		side.add_child(Widgets.row([Widgets.GuIcon.new(sel["def"], rot), Widgets.label(d["name"], 15, UITheme.GOLD)]))
		side.add_child(Widgets.rich("[color=%s]%s[/color]  -  Rank %d  -  %s" % [Widgets.hex(GuDB.color_of(sel["def"])), GuDB.PATH_NAMES[d["path"]], d["rank"], d["role"]], 12))
		side.add_child(Widgets.label(d["desc"], 12, UITheme.MUTED))
		side.add_child(Widgets.rich("%s  -  Nature: %s  -  eats every %dd" % [_gu_title(sel), GuRoll.nature_label(sel), GuRoll.feed_every(sel)], 12))
		side.add_child(Widgets.PotentialBars.new(sel))
		var btns: Array = [Widgets.button("Rotate (R)", rotate, true, false, 13)]
		if Game.is_placed(selected):
			btns.append(Widgets.button("Return to pouch", func(): Game.unplace_gu(selected); selected = -1, true, false, 13))
		side.add_child(Widgets.row(btns))
		var food: String = d["food"]
		side.add_child(Widgets.row([
			Widgets.button("Feed (%s x%d)" % [ItemDB.ITEMS[food]["name"], Game.count(food)], func(): Game.feed_gu(selected), Game.count(food) > 0, false, 13),
			Widgets.button("Done", func(): selected = -1; hud._rebuild_panel(), true, false, 13),
		]))

	# pouch
	box.add_child(Widgets.header("Gu Pouch (unplaced)"))
	var unplaced: Array = p["gu"].filter(func(g): return not Game.is_placed(g["uid"]))
	if unplaced.is_empty():
		box.add_child(Widgets.label("All your Gu are refined into your aperture.", 13, UITheme.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for inst in unplaced:
		flow.add_child(_gu_card(inst, "select"))
	box.add_child(flow)

	# build summary
	box.add_child(Widgets.header("Active Gu Combination"))
	if b["attacks"].is_empty():
		box.add_child(Widgets.label("No attack Gu active - you cannot fight!", 13, UITheme.BAD))
	for a in b["attacks"]:
		var reach: float = a.get("radius", a["range"]) if a["kind"] == "nova" else a["range"]
		var line := "[b]%s[/b] - %s%s - %.1f dmg - %.2fs - %.1f essence - range %d%s" % [
			a["name"], a["kind"], ("x%d" % a["count"]) if a.has("count") else "", a["damage"], a["cooldown"], a["cost"], roundi(reach),
			(" - slow %d%%" % roundi(a["slow"] * 100)) if a.get("slow", 0.0) > 0.0 else ""]
		box.add_child(Widgets.rich(("[color=#ffe9a8]%s[/color]" % line) if a["is_killer"] else line, 13))
	var st: Dictionary = b["stats"]
	var parts: Array[String] = []
	if st["armor"] > 0: parts.append("Armor %d" % st["armor"])
	if st["max_hp"] > 0: parts.append("+%d HP" % st["max_hp"])
	if st["shield"] > 0: parts.append("Shield %d" % st["shield"])
	if st["damage_mult"] > 0: parts.append("+%d%% dmg" % roundi(st["damage_mult"] * 100))
	if st["hp_regen"] > 0: parts.append("+%.1f HP/s" % st["hp_regen"])
	if st["move_speed"] > 0: parts.append("+%d%% speed" % roundi(st["move_speed"] * 100))
	if st["reveal"] > 0: parts.append("Reveal +%d" % st["reveal"])
	box.add_child(Widgets.label("Passives: " + (", ".join(parts) if parts.size() else "none"), 13, UITheme.MUTED))
	if not b["synergies"].is_empty():
		box.add_child(Widgets.header("Synergies"))
		for s in b["synergies"]:
			box.add_child(Widgets.label("- " + s, 13, UITheme.JADE))

	# Dao combos: show every path you have placed, with pair progress
	var placed_paths := {}
	for pl in p["placed"]:
		placed_paths[GuDB.GU[Aperture.find_inst(p["gu"], pl["uid"])["def"]]["path"]] = true
	if not placed_paths.is_empty():
		box.add_child(Widgets.header("Dao Combos"))
		box.add_child(Widgets.label("Two or more pairs of touching same-path Gu awaken that path's Dao combo.", 12, UITheme.MUTED))
		var pairs: Dictionary = b.get("path_pairs", {})
		for path in placed_paths:
			if not GuDB.DAO_COMBOS.has(path):
				continue
			var c: Dictionary = GuDB.DAO_COMBOS[path]
			var np: int = mini(pairs.get(path, 0), 2)
			var on := np >= 2
			box.add_child(Widgets.rich("[color=%s]%s %s[/color] [color=#a69f8f](%s, pairs %d/2)[/color] - %s" % [
				"#ffe9a8" if on else Widgets.hex(GuDB.path_color(path)), "*" if on else "-", c["name"],
				GuDB.PATH_NAMES[path], np, c["desc"]], 13))

	box.add_child(Widgets.header("Killer Move Codex"))
	for km in GuDB.KILLER_MOVES:
		var active: bool = b["killer_moves"].has(km)
		var reqs: Array = km["requires"].map(func(r):
			var own: bool = p["gu"].any(func(g): return g["def"] == r)
			return "[color=%s]%s[/color]" % ["#6fd3a8" if own else "#a69f8f", GuDB.GU[r]["name"]])
		var txt := "%s[b]%s[/b]  [color=#a69f8f](Rank %d+)[/color]\n%s - must touch in the aperture\n[color=#a69f8f]%s[/color]" % [
			"* " if active else "", km["name"], km["min_rank"], " + ".join(reqs), km["desc"]]
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UITheme.box(Color(0.94, 0.81, 0.45, 0.12) if active else Color(1, 1, 1, 0.03), Color(0.94, 0.81, 0.45, 0.6) if active else Color(1, 1, 1, 0.06), 8, 1, 8))
		pc.add_child(Widgets.rich(("[color=#ffe9a8]%s[/color]" % txt) if active else txt, 13))
		box.add_child(pc)


func _on_cell(cell: Vector2i) -> void:
	var n := Game.ap_size()
	var occ := Aperture.occupancy(n, Game.p["placed"], Game.p["gu"])
	var here := occ[cell.y * n + cell.x]
	if selected >= 0 and (here == 0 or here == selected):
		if Game.place_gu(selected, cell.x, cell.y, rot):
			selected = -1
		else:
			Game.toast.emit("It doesn't fit there.", "bad")
			hud._rebuild_panel()
	elif here != 0:
		selected = here
		for pl in Game.p["placed"]:
			if pl["uid"] == here:
				rot = pl["rot"]
		hud._rebuild_panel()


func _gu_card(inst: Dictionary, mode: String) -> Control:
	var d: Dictionary = GuDB.GU[inst["def"]]
	var pc := PanelContainer.new()
	var is_sel: bool = inst["uid"] == selected
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(0.94, 0.81, 0.45, 0.12) if is_sel else Color(1, 1, 1, 0.03), GuDB.color_of(inst["def"]), 10, 1, 8))
	pc.custom_minimum_size = Vector2(220, 0)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var title := Widgets.rich(_gu_title(inst), 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Widgets.row([Widgets.GuIcon.new(inst["def"]), title]))
	var every := GuRoll.feed_every(inst)
	var hunger := "[color=#ff6b6b]Starving![/color]" if Aperture.is_starving(inst) else ("[color=#ffb347]Hungry[/color]" if inst["unfed"] >= every - 1 else "[color=#7cfc8a]Fed[/color]")
	var lock := "  [color=#ff6b6b]Rank %d - too high[/color]" % d["rank"] if d["rank"] > Game.p["rank"] else ""
	v.add_child(Widgets.rich("R%d - %s - %s\nEats %s every %dd - %s%s" % [d["rank"], GuDB.PATH_NAMES[d["path"]], d["role"], ItemDB.ITEMS[d["food"]]["name"], every, hunger, lock], 12))
	v.add_child(Widgets.PotentialBars.new(inst))
	if mode == "select":
		var uid: int = inst["uid"]
		v.add_child(Widgets.button("Selected" if is_sel else "Place", func():
			selected = -1 if selected == uid else uid
			rot = 0
			hud._rebuild_panel(), true, is_sel, 13))
	else:
		v.add_child(Widgets.button("Sell for %d" % GuRoll.sell_value(inst), func(): Game.sell_gu(inst["uid"]), true, false, 13))
	return pc


## "[Grade A] Moonlight Gu *" with grade colour and a shiny star.
func _gu_title(inst: Dictionary) -> String:
	var d: Dictionary = GuDB.GU[inst["def"]]
	var shiny := " [color=#ffd76b]* SHINY[/color]" if inst.get("shiny", false) else ""
	return "[color=%s][b]%s[/b][/color] %s%s" % [GuRoll.grade_color(inst), GuRoll.grade(inst), d["name"], shiny]


# ------------------------------------------------------------------ bag
func _bag(box: VBoxContainer) -> void:
	var p := Game.p
	box.add_child(Widgets.label("%d primeval stones  -  Kills %d  -  Hunger %d/100" % [p["stones"], p["kills"], ceili(p["hunger"])], 13, UITheme.MUTED))
	if p["inventory"].is_empty():
		box.add_child(Widgets.label("Your bag is empty.", 13, UITheme.MUTED))
	for id in p["inventory"]:
		var d: Dictionary = ItemDB.ITEMS[id]
		var eaters: Array = []
		for g in p["gu"]:
			var gd: Dictionary = GuDB.GU[g["def"]]
			if gd["food"] == id and not eaters.has(gd["name"]):
				eaters.append(gd["name"])
		var txt := "[color=%s]o[/color] [b]%s[/b] x%d\n[color=#a69f8f]%s[/color]" % [d["color"], d["name"], p["inventory"][id], d["desc"]]
		if eaters.size():
			txt += " [color=#7cfc8a]Food for: %s[/color]" % ", ".join(eaters)
		var r := Widgets.rich(txt, 13)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var items: Array = [r]
		if d.has("pill"):
			items.append(Widgets.button("Take", func(): Game.take_pill(id), true, true, 13))
		elif d.has("food") or d.has("heal"):
			items.append(Widgets.button("Eat", func(): Game.eat(id), true, false, 13))
		box.add_child(Widgets.row(items))
		box.add_child(HSeparator.new())


# ------------------------------------------------------------------ craft
func _craft(box: VBoxContainer, args: Dictionary) -> void:
	var tab: String = args.get("tab", "craft")
	if not tab in ["craft", "refine", "alchemy"]:
		tab = "craft"
	var tabs: Array = []
	for t in [["craft", "Crafting"], ["refine", "Gu Refinement"], ["alchemy", "Alchemy"]]:
		var key: String = t[0]
		tabs.append(Widgets.button(t[1], func(): args["tab"] = key; hud._rebuild_panel(), true, tab == key, 13))
	box.add_child(Widgets.row(tabs))
	match tab:
		"refine":
			box.add_child(Widgets.label("Gu refinement may fail. Higher aptitude improves the odds. A refined Gu keeps the nature, shiny and potentials of the Gu it came from.", 13, UITheme.MUTED))
		"alchemy":
			var at_furnace := Game.near_furnace(Game.p["pos"])
			box.add_child(Widgets.rich("Alchemy mastery [b]%d[/b] (%d pills brewed)  -  success %d%%  -  perfect brew (2 pills) %d%%\n%s" % [
				Game.alchemy_level(), Game.p.get("alchemy_xp", 0), roundi(Game.alchemy_success() * 100), roundi(Game.alchemy_double() * 100),
				"[color=#7cfc8a]A furnace is at hand.[/color]" if at_furnace else "[color=#ff6b6b]You need an alchemy furnace: settlements have one, or build one in the Crafting tab.[/color]"], 13))
			var active: Array[String] = []
			for id in Game.p["buffs"]:
				active.append("%s %ds" % [ItemDB.ITEMS[id]["name"], ceili(Game.buff_seconds(id))])
			if Game.p.get("breakthrough_aid", false):
				active.append("Breakthrough Aid (next cultivation)")
			if active.size():
				box.add_child(Widgets.label("Active: " + ", ".join(active), 13, UITheme.JADE))
	for r in ItemDB.RECIPES:
		if ItemDB.category(r) != tab:
			continue
		var why := Game.can_craft(r)
		var needs: Array[String] = []
		for k in r["needs"]:
			needs.append("[color=%s]%d %s[/color]" % ["#7cfc8a" if Game.count(k) >= r["needs"][k] else "#ff6b6b", r["needs"][k], ItemDB.ITEMS[k]["name"]])
		if r.has("stones"):
			needs.append("[color=%s]%d stones[/color]" % ["#7cfc8a" if Game.p["stones"] >= r["stones"] else "#ff6b6b", r["stones"]])
		if r.has("gu_input"):
			needs.append("[color=%s]%s[/color]" % ["#7cfc8a" if Game.p["gu"].any(func(g): return g["def"] == r["gu_input"]) else "#ff6b6b", GuDB.GU[r["gu_input"]]["name"]])
		if r.get("near_fire", false):
			needs.append("[color=%s]near fire[/color]" % ("#7cfc8a" if Game.near_fire(Game.p["pos"]) else "#ff6b6b"))
		if r.get("station", "") == "furnace":
			needs.append("[color=%s]furnace[/color]" % ("#7cfc8a" if Game.near_furnace(Game.p["pos"]) else "#ff6b6b"))
			var have := Game.count(r["output"]["item"])
			if have > 0:
				needs.append("[color=#a69f8f]have %d[/color]" % have)
		if r.has("min_rank"):
			needs.append("[color=%s]rank %d[/color]" % ["#7cfc8a" if Game.p["rank"] >= r["min_rank"] else "#ff6b6b", r["min_rank"]])
		var txt := Widgets.rich("[b]%s[/b]  [color=#a69f8f]%s[/color]\n%s" % [r["name"], r["desc"], " - ".join(needs)], 13)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var facing: Vector2 = hud.world.player.facing if hud.world else Vector2.RIGHT
		var verb := "Refine" if r["output"].has("gu") else ("Brew" if tab == "alchemy" else ("Build" if r["output"].has("place") else "Make"))
		var b := Widgets.button(verb, func(): Game.craft(r["id"], facing), why == "", true, 13)
		b.tooltip_text = why
		box.add_child(Widgets.row([txt, b]))
		box.add_child(HSeparator.new())


# ------------------------------------------------------------------ shop
func _shop(box: VBoxContainer, args: Dictionary) -> void:
	var shop: Dictionary = ItemDB.SHOPS[args.get("shop", "village")]
	var tab: String = args.get("tab", "gu")
	box.add_child(Widgets.label("%s  -  you have %d primeval stones" % [shop["name"], Game.p["stones"]], 13, UITheme.MUTED))
	var tabs: Array = []
	for t in [["gu", "Buy Gu"], ["items", "Buy Goods"], ["sell", "Sell"]]:
		var key: String = t[0]
		tabs.append(Widgets.button(t[1], func(): args["tab"] = key; hud._rebuild_panel(), true, tab == key, 13))
	box.add_child(Widgets.row(tabs))
	match tab:
		"gu":
			for id in shop["gu"]:
				var d: Dictionary = GuDB.GU[id]
				var r := Widgets.rich("[b]%s[/b]  [color=%s]R%d %s[/color]\n[color=#a69f8f]%s Eats %s.[/color]" % [d["name"], Widgets.hex(GuDB.color_of(id)), d["rank"], GuDB.PATH_NAMES[d["path"]], d["desc"], ItemDB.ITEMS[d["food"]]["name"]], 13)
				r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				box.add_child(Widgets.row([Widgets.GuIcon.new(id), r, Widgets.button("%d stones" % d["price"], func(): Game.buy_gu(id), Game.p["stones"] >= d["price"], true, 13)]))
				box.add_child(HSeparator.new())
		"items":
			for id in shop["items"]:
				var d: Dictionary = ItemDB.ITEMS[id]
				var price: int = d["price"] * 2
				var r := Widgets.rich("[b]%s[/b] (have %d)\n[color=#a69f8f]%s[/color]" % [d["name"], Game.count(id), d["desc"]], 13)
				r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				box.add_child(Widgets.row([r, Widgets.button("%d" % price, func(): Game.buy_item(id, 1), Game.p["stones"] >= price, false, 13),
					Widgets.button("x5: %d" % (price * 5), func(): Game.buy_item(id, 5), Game.p["stones"] >= price * 5, false, 13)]))
				box.add_child(HSeparator.new())
		"sell":
			box.add_child(Widgets.header("Goods"))
			for id in Game.p["inventory"]:
				var d: Dictionary = ItemDB.ITEMS[id]
				var n: int = Game.p["inventory"][id]
				var l := Widgets.label("%s x%d" % [d["name"], n], 13)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				box.add_child(Widgets.row([l, Widgets.button("Sell 1: %d" % d["price"], func(): Game.sell_item(id, 1), true, false, 13),
					Widgets.button("All: %d" % (d["price"] * n), func(): Game.sell_item(id, n), true, false, 13)]))
			box.add_child(Widgets.header("Gu"))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			for inst in Game.p["gu"]:
				flow.add_child(_gu_card(inst, "sell"))
			box.add_child(flow)


# ------------------------------------------------------------------ elder / caravan / map / help
func _elder(box: VBoxContainer, args: Dictionary) -> void:
	var tab: String = args.get("tab", "cultivate")
	if args.get("clan", false):
		var tabs: Array = []
		for t in [["cultivate", "Cultivate"], ["missions", "Clan Missions"], ["treasury", "Clan Treasury"]]:
			var key: String = t[0]
			tabs.append(Widgets.button(t[1], func(): args["tab"] = key; hud._rebuild_panel(), true, tab == key, 13))
		box.add_child(Widgets.row(tabs))
	match tab:
		"missions": _missions(box)
		"treasury": _treasury(box)
		_: _cultivate(box)


func _missions(box: VBoxContainer) -> void:
	var p := Game.p
	box.add_child(Widgets.rich("Clan contribution: [color=#ffd76b][b]%d[/b][/color]  -  New missions are posted every dawn." % p["contrib"], 13))
	box.add_child(Widgets.header("Your missions (%d/%d)" % [p["quests"]["active"].size(), Quests.MAX_ACTIVE]))
	if p["quests"]["active"].is_empty():
		box.add_child(Widgets.label("No missions accepted.", 13, UITheme.MUTED))
	for q in p["quests"]["active"]:
		var done := Quests.is_complete(q, p["inventory"])
		var txt := Widgets.rich("[b]%s[/b]  (%d/%d)\n[color=#a69f8f]%s Reward: %d stones, %d contribution.[/color]" % [
			q["title"], Quests.progress(q, p["inventory"]), q["count"], Quests.describe(q), q["stones"], q["contrib"]], 13)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var qid: int = q["id"]
		var btns: Array = [txt]
		if done:
			btns.append(Widgets.button("Report", func(): Game.claim_mission(qid), true, true, 13))
		btns.append(Widgets.button("Abandon", func(): Game.abandon_mission(qid), true, false, 12))
		box.add_child(Widgets.row(btns))
		box.add_child(HSeparator.new())
	box.add_child(Widgets.header("Mission board"))
	if p["quests"]["offered"].is_empty():
		box.add_child(Widgets.label("The board is empty. Report finished missions, or wait for dawn.", 13, UITheme.MUTED))
	for q in p["quests"]["offered"]:
		var txt := Widgets.rich("[b]%s[/b]\n[color=#a69f8f]%s Reward: %d stones, %d contribution.[/color]" % [q["title"], Quests.describe(q), q["stones"], q["contrib"]], 13)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var qid: int = q["id"]
		box.add_child(Widgets.row([txt, Widgets.button("Accept", func(): Game.accept_mission(qid), p["quests"]["active"].size() < Quests.MAX_ACTIVE, true, 13)]))
		box.add_child(HSeparator.new())


func _treasury(box: VBoxContainer) -> void:
	var p := Game.p
	box.add_child(Widgets.rich("Clan contribution: [color=#ffd76b][b]%d[/b][/color]  -  Earn it through missions and by defending the village from beast tides." % p["contrib"], 13))
	for e in Quests.TREASURY:
		var nm: String
		var desc: String
		var icon: Control = Control.new()
		if e["kind"] == "gu":
			var d: Dictionary = GuDB.GU[e["id"]]
			nm = "%s  [color=%s]R%d %s[/color]" % [d["name"], Widgets.hex(GuDB.color_of(e["id"])), d["rank"], GuDB.PATH_NAMES[d["path"]]]
			desc = d["desc"]
			icon = Widgets.GuIcon.new(e["id"])
		else:
			nm = e["name"]
			desc = e["desc"]
		var txt := Widgets.rich("[b]%s[/b]\n[color=#a69f8f]%s[/color]" % [nm, desc], 13)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var eid: String = e["id"]
		box.add_child(Widgets.row([icon, txt, Widgets.button("%d contribution" % e["cost"], func(): Game.buy_treasury(eid), p["contrib"] >= e["cost"], true, 13)]))
		box.add_child(HSeparator.new())


func _cultivate(box: VBoxContainer) -> void:
	var p := Game.p
	var cost := Game.cultivation_cost()
	box.add_child(Widgets.rich("[b]%s %s[/b]  -  Grade %s aptitude (%d%%)" % [Aperture.RANK_NAMES[p["rank"]], Aperture.STAGE_NAMES[p["stage"]], Game.grade_of(p["aptitude"]), roundi(p["aptitude"] * 100)], 15))
	var bar := Widgets.StatBar.new(Aperture.essence_color(p["rank"]))
	bar.custom_minimum_size = Vector2(300, 24)
	bar.set_values(p["cultivation"], 100.0, "Cultivation %d%%" % floori(p["cultivation"]))
	box.add_child(bar)
	box.add_child(Widgets.label("Sit in seclusion and absorb primeval stones to nourish your aperture walls. Each session costs %d stones and some time. When Peak Stage is full, Heaven tests you: survive a tribulation to break through to the next rank (more grid space, stronger essence, higher-rank Gu)." % cost, 13, UITheme.MUTED))
	if Game.in_deviation():
		box.add_child(Widgets.label("Qi deviation: cultivation is halved and your essence is weakened for %.1f more hours." % ((p["deviation_until"] - Game.time) * 24.0), 13, UITheme.BAD))
	if p.get("trib_ready", false):
		var th := Game.tribulation_theme()
		var why := Game.can_start_tribulation()
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UITheme.box(Color(0.5, 0.1, 0.1, 0.25), Color(th["color"]), 10, 2, 10))
		var v := VBoxContainer.new()
		pc.add_child(v)
		v.add_child(Widgets.rich("[b][color=%s]%s[/color][/b]  -  breakthrough to Rank %d\nYour strongest Dao path shapes the storm. Dodge the red warning circles, survive the spirits, then destroy the [b]%s[/b] within 2 minutes. Leaving the ring counts as fleeing. Failure brings qi deviation, not death.%s" % [
			th["color"], th["name"], th["rank"], th["avatar"],
			"\n[color=#9ecbff]A Tribulation Ward Pill (Alchemy) softens Heaven's strikes.[/color]" if Game.count("pill_ward") == 0 else "\n[color=#7cfc8a]You carry %d Tribulation Ward Pill(s).[/color]" % Game.count("pill_ward")], 13))
		var b := Widgets.button("Face the Tribulation", func(): hud.close_panel(); Game.start_tribulation(), why == "", true, 15)
		v.add_child(b)
		if why != "":
			v.add_child(Widgets.label(why, 13, UITheme.BAD))
		box.add_child(pc)
	box.add_child(Widgets.row([
		Widgets.button("Cultivate (%d stones)" % cost, func(): Game.cultivate(), p["stones"] >= cost, true, 14),
		Widgets.button("Rest until dawn", func(): Game.rest_until_dawn(); hud.close_panel(), true, false, 14),
	]))
	box.add_child(Widgets.header("Aperture by rank"))
	for r in range(1, 6):
		var txt := "Rank %d: %dx%d grid - [color=%s]%s[/color] essence" % [r, 3 + r, 3 + r, Aperture.ESSENCE_COLORS[r], Aperture.ESSENCE_NAMES[r]]
		box.add_child(Widgets.rich(("[b]> %s[/b]" % txt) if r == p["rank"] else txt, 13))


func _caravan(box: VBoxContainer, args: Dictionary) -> void:
	var dest := WorldData.poi(args.get("dest", "city"))
	box.add_child(Widgets.rich("The caravan travels the road to [b]%s[/b]. Fee: 15 primeval stones. The journey takes about a third of a day." % dest["name"], 14))
	box.add_child(Widgets.label(dest["desc"], 13, UITheme.MUTED))
	box.add_child(Widgets.button("Travel to %s" % dest["name"], func(): hud.close_panel(); Game.travel(dest["id"]), Game.p["stones"] >= 15, true, 15))


func _map(box: VBoxContainer) -> void:
	var m := Widgets.MapView.new(0.0, true)
	var side := minf(460.0, hud.root.size.y - 140.0)
	m.custom_minimum_size = Vector2(side, side)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.refresh()
	box.add_child(m)
	box.add_child(Widgets.label("Unexplored land stays dark. Regional Walls (violet) seal the Southern Border from the other regions.", 13, UITheme.MUTED))


func _plot(box: VBoxContainer, args: Dictionary) -> void:
	var pl := Game.find_plot(args.get("plot", -1))
	if pl.is_empty():
		return
	if pl["crop"] != "":
		box.add_child(Widgets.label("%s - %s (%d%%), quality %d/3." % [ItemDB.ITEMS[pl["crop"]]["name"], Game.plot_stage(pl), roundi(pl["growth"] * 100), pl["quality"]], 14))
		return
	box.add_child(Widgets.label("Choose what to sow. Planting uses one of the crop. Tend the field while it grows for a bigger harvest. Ripe crops rot after a day, and beast tides can trample young fields.", 13, UITheme.MUTED))
	if Game.plot_growth_mult(pl) > 1.0 and not Game.is_night():
		box.add_child(Widgets.label("Water nearby: this field grows 25% faster.", 13, UITheme.JADE))
	for crop in ItemDB.CROPS:
		var c: Dictionary = ItemDB.CROPS[crop]
		var d: Dictionary = ItemDB.ITEMS[crop]
		var eaters: Array = []
		for g in GuDB.GU.values():
			if g["food"] == crop:
				eaters.append(g["name"].trim_suffix(" Gu"))
		var txt := Widgets.rich("[color=%s]o[/color] [b]%s[/b] (have %d)  -  ripe in %.1f days, harvest %d-%d%s\n[color=#a69f8f]%s[/color]" % [
			d["color"], d["name"], Game.count(crop), c["grow"], c["yield"], c["yield"] + 3,
			"  -  grows faster at night" if c["night"] > 1.0 else "",
			("Feeds: " + ", ".join(eaters.slice(0, 4))) if eaters.size() else d["desc"]], 13)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pid: int = pl["id"]
		box.add_child(Widgets.row([txt, Widgets.button("Plant", func(): Game.plant(pid, crop); hud.close_panel(), Game.count(crop) > 0, true, 13)]))
		box.add_child(HSeparator.new())


func _help(box: VBoxContainer) -> void:
	var lines := [
		"[b]Move[/b] with WASD or by dragging on the left half of the screen. Your Gu attack [b]automatically[/b] when enemies are in range, consuming primeval essence.",
		"[b]Aperture[/b]: a grid inside you. Place Gu in it to activate them. Higher ranks mean bigger grids.",
		"[b]Synergy[/b]: support Gu (Liquor Worm, Spider Silk...) empower attack Gu they touch. Same-path Gu touching each other resonate for +15% damage.",
		"[b]Killer moves[/b]: certain Gu touching each other unlock powerful combined attacks. See the codex in the Aperture panel.",
		"[b]Feeding[/b]: every Gu eats a specific food every few days at dawn. Hungry Gu stop working; 3 days later they die.",
		"[b]Survival[/b]: watch Hunger. Night is dark and dangerous; build a campfire (Refine panel) and cook meat.",
		"[b]Primeval stones[/b] are money and essence. Tap Absorb or press Q to restore essence mid-fight.",
		"[b]Tribulations[/b]: when Peak Stage is full, face a tribulation from the Clan Elder. Dodge Heaven's strikes and destroy the Calamity Avatar to break through. Failing causes a day of qi deviation.",
		"[b]Cultivate[/b] with the Clan Elder to rank up. Use the caravan to reach Shang Clan City for rarer Gu.",
		"[b]Clan missions[/b]: the village elder posts hunts, deliveries and scouting jobs. They pay stones and [b]clan contribution[/b], which buys rare Gu and pills in the Clan Treasury.",
		"[b]Beast tides[/b]: every 5th night beasts storm Shi Lan Village. Clan guards hold the corners; every beast you slay earns stones and contribution at dawn.",
		"[b]Spirit fields[/b]: build a Spirit Field Plot (Crafting tab) or use the two fields in Shi Lan Village. Plant moon orchids, herbs, berries or spirit rice, tend them for bigger harvests, and harvest before they rot. Your Gu eat from your bag automatically at dawn.",
		"[b]Alchemy[/b]: build an Alchemy Furnace (or use the one in any settlement) and brew pills in the Refine panel: healing, essence, a pill that feeds every Gu, timed battle buffs, and a Breakthrough Aid for cultivation. Brewing raises your alchemy mastery.",
		"[b]Wild Gu sightings[/b]: rumours point you to wild Gu (shown on the map). Stand in the glowing ring to bind it. Leaving the ring or taking hits sets you back, and the Gu may still break free.",
		"[b]Unique Gu[/b]: every Gu has a grade (F-S), a nature and four potentials (power, speed, efficiency, durability). Wild Gu can be shiny (1 in 512).",
		"[b]Enslavement path[/b]: the Wolf Enslavement Gu binds a wolf that fights beside you and returns after it falls.",
		"[b]Regional Walls[/b] seal the Southern Border on the north, west and east. Mortals cannot pass.",
		"The [b]Myriad Beast Mire[/b] (southwest) is forbidden ground ruled by a Beast King. The [b]ruins[/b] (northwest) hide an inheritance.",
		"[color=#a69f8f]Keys: E/Space interact - Tab aperture - B bag - C refine - M map - Q absorb - R rotate - Esc close[/color]",
	]
	for l in lines:
		box.add_child(Widgets.rich(l, 14))
