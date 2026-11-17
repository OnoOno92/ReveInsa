extends Node
## Entry point: title screen -> world + HUD.
## Debug/screenshot args (via tools/godot.sh shot ... -- --autostart=1 ...):
##   --autostart=1 --seed=N --night=1 --at=ruins|city|forbidden|wild --enemies=N
##   --give=moon_glow,liquor_worm --rank=2 --panel=aperture|bag|craft|shop|elder|map|help --tab=missions
##   --trib=1 [--trib_t=45] [--autopilot=1 --time_scale=4 --quit_after=40] (balance sims, run headless)
##   --trib=1 [--trib_t=45] (start the breakthrough tribulation, optionally fast-forwarded)
##   --garden=1 (spirit fields at different growth stages)
##   --alchemy=1 (furnace + ingredients + active pill buffs)
##   --sighting=<gu id> [--in=1] (wild Gu sighting next to / around the player)
##   --ui_scale=1.35 (preview the phone UI scale)  --shiny=1 (Gu from --give are shiny)
##   --tide=1 (Day 5 night, beast tide running) --contrib=N --missions=1 (accept all offered)

const WorldView := preload("res://world/world_view.gd")

var world: Node2D
var hud: CanvasLayer


func _ready() -> void:
	InputSetup.ensure()
	var args: Dictionary = get_tree().root.get_meta("capture_args", {})
	if args.is_empty(): # also accept "-- --key=value" when run directly (headless balance sims)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--") and "=" in a:
				var kv := a.substr(2).split("=", true, 1)
				args[kv[0]] = kv[1]
	# Phones have dense screens: scale the whole UI up so text and buttons are thumb-sized.
	var ui_scale := 1.35 if OS.has_feature("mobile") else 1.0
	get_window().content_scale_factor = float(args.get("ui_scale", str(ui_scale)))
	if args.has("autostart"):
		Game.new_game("Shi Mo", int(args.get("seed", "12345")))
		_apply_debug_before(args)
		start_world()
		_apply_debug_after.call_deferred(args)
	else:
		show_title()


func show_title() -> void:
	var title_script: GDScript = load("res://ui/title.gd")
	var title: CanvasLayer = title_script.new()
	title.started.connect(func(result: Dictionary):
		title.queue_free()
		start_world()
		if result.has("grade"):
			hud.show_ceremony(result["grade"], result["aptitude"]))
	add_child(title)


func start_world() -> void:
	world = WorldView.new()
	add_child(world)
	var hud_script: GDScript = load("res://ui/hud.gd")
	hud = hud_script.new()
	hud.world = world
	add_child(hud)


func _apply_debug_before(args: Dictionary) -> void:
	if args.has("rank"):
		Game.p["rank"] = int(args["rank"])
	for g in str(args.get("give", "")).split(",", false):
		Game.add_gu(g, true, "wild", GuRoll.roll(Game.rng, "wild", args.has("shiny")))
	if args.has("at"):
		var at: String = args["at"]
		var pos: Vector2 = WorldData.poi_center("village") + Vector2(0, -16 * WorldData.TILE) if at == "wild" else WorldData.poi_center(at) + Vector2(0, 3 * WorldData.TILE)
		Game.p["pos"] = pos
	if args.has("night"):
		Game.time = floorf(Game.time) + 0.8
	if args.has("tide"):
		Game.time = 4.69
		Game.flags["tide_on"] = true
		Game.flags["tide_kills"] = 0
	Game.p["contrib"] = int(args.get("contrib", str(Game.p["contrib"])))
	if args.has("missions"):
		for q in Game.missions()["offered"].duplicate():
			Game.accept_mission(q["id"])
	Game.p["stones"] = int(args.get("stones", str(Game.p["stones"])))
	Game.rebuild()
	Game.p["essence"] = Game.max_essence()


func _apply_debug_after(args: Dictionary) -> void:
	var n := int(args.get("enemies", "0"))
	for i in n:
		var e: Node = world.combat.spawn("wolf", Game.p["pos"] + Vector2.from_angle(i * TAU / n) * 170.0)
		e.aggro = true
	if args.has("garden"):
		# --garden=1: village fields planted at different stages, plus a ripe field by you
		Game.add_item("moon_orchid", 2); Game.add_item("spirit_rice", 3); Game.add_item("berries", 2)
		Game.plant(Game.plots[0]["id"], "moon_orchid")
		Game.plots[0]["growth"] = 0.45
		Game.plant(Game.plots[1]["id"], "spirit_rice")
		Game.plots[1]["growth"] = 1.0
		var extra := Game.add_plot(Game.p["pos"] + Vector2(70, 10))
		Game.plant(extra["id"], "berries")
		extra["growth"] = 0.1
	if args.has("alchemy"):
		# --alchemy=1: a furnace next to you, ingredients, and two active pill buffs
		Game.campfires.append({"pos": Game.p["pos"] + Vector2(60, -10), "until": 1.0e9, "kind": "furnace"})
		for it in ["herb", "berries", "moon_orchid", "meat", "stone", "bone", "thunder_crystal"]:
			Game.add_item(it, 8)
		for pill in ["pill_iron", "pill_fury", "pill_vitality"]:
			Game.add_item(pill, 2)
		Game.take_pill("pill_iron")
		Game.take_pill("pill_fury")
		Game.changed.emit()
	if args.has("sighting"):
		# --sighting=<gu id>: a sighting right next to the player (inside the ring if --in=1)
		var off := Vector2(0, -30) if args.has("in") else Vector2(160, -60)
		Game.spawn_sighting(args["sighting"], Game.p["pos"] + off)
		Game.spawn_sighting() # plus a random rumour elsewhere
	if args.has("trib"):
		# --trib=1 [--trib_t=seconds]: Peak Stage, start the tribulation (optionally fast-forwarded)
		Game.p["stage"] = 3
		Game.p["cultivation"] = 100.0
		Game.p["trib_ready"] = true
		Game.p["hp"] = Game.max_hp()
		Game.start_tribulation()
		world.tribulation.t = float(args.get("trib_t", "0"))
		world.tribulation.autopilot = args.has("autopilot")
		Game.tribulation_ended.connect(func(ok): print("tribulation: %s after %.0fs, hits=%d, hp=%.0f" % ["SUCCESS" if ok else "FAILED", world.tribulation.t, Game._trib_hits, Game.p["hp"]]))
	if args.has("time_scale"):
		Engine.time_scale = float(args["time_scale"])
		Engine.physics_ticks_per_second = int(60 * Engine.time_scale) # keep physics steps small
	if args.has("quit_after"):
		get_tree().create_timer(float(args["quit_after"]), true, false, true).timeout.connect(get_tree().quit)
	if args.has("panel") and hud:
		hud.open_panel(args["panel"], {"shop": args.get("shop", "village"), "tab": args.get("tab", "gu"), "dest": "city", "clan": true,
			"plot": Game.add_plot(Game.p["pos"] + Vector2(-70, 10))["id"] if args["panel"] == "plot" else -1})
	_report = args.has("report")
	if _report:
		get_tree().create_timer(float(args.get("report_at", "5"))).timeout.connect(func():
			print("report@t: enemies=%d allies=%d kills=%d hp=%.0f" % [get_tree().get_nodes_in_group("enemies").size(),
				get_tree().get_nodes_in_group("allies").size(), Game.p["kills"], Game.p["hp"]]))
	if args.has("act"):
		await get_tree().create_timer(0.3).timeout
		Game.action_requested = true


var _report := false

func _exit_tree() -> void:
	if _report and not Game.p.is_empty():
		print("report: hp=%.0f/%.0f essence=%.0f kills=%d stones=%d zone=%s" % [
			Game.p["hp"], Game.max_hp(), Game.p["essence"], Game.p["kills"], Game.p["stones"], Game.world.zone_at(Game.p["pos"])])
