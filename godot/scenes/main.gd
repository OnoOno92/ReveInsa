extends Node
## Entry point: title screen -> world + HUD.
## Debug/screenshot args (via tools/godot.sh shot ... -- --autostart=1 ...):
##   --autostart=1 --seed=N --night=1 --at=ruins|city|forbidden|wild --enemies=N
##   --give=moon_glow,liquor_worm --rank=2 --panel=aperture|bag|craft|shop|elder|map|help

const WorldView := preload("res://world/world_view.gd")

var world: Node2D
var hud: CanvasLayer


func _ready() -> void:
	InputSetup.ensure()
	var args: Dictionary = get_tree().root.get_meta("capture_args", {})
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
		Game.add_gu(g, true)
	if args.has("at"):
		var at: String = args["at"]
		var pos: Vector2 = WorldData.poi_center("village") + Vector2(0, -16 * WorldData.TILE) if at == "wild" else WorldData.poi_center(at) + Vector2(0, 3 * WorldData.TILE)
		Game.p["pos"] = pos
	if args.has("night"):
		Game.time = floorf(Game.time) + 0.8
	Game.p["stones"] = int(args.get("stones", str(Game.p["stones"])))
	Game.rebuild()
	Game.p["essence"] = Game.max_essence()


func _apply_debug_after(args: Dictionary) -> void:
	var n := int(args.get("enemies", "0"))
	for i in n:
		var e: Node = world.combat.spawn("wolf", Game.p["pos"] + Vector2.from_angle(i * TAU / n) * 170.0)
		e.aggro = true
	if args.has("panel") and hud:
		hud.open_panel(args["panel"], {"shop": args.get("shop", "village"), "tab": args.get("tab", "gu"), "dest": "city"})
	_report = args.has("report")
	if args.has("act"):
		await get_tree().create_timer(0.3).timeout
		Game.action_requested = true


var _report := false

func _exit_tree() -> void:
	if _report and not Game.p.is_empty():
		print("report: hp=%.0f/%.0f essence=%.0f kills=%d enemies=%d stones=%d pos=%s zone=%s" % [
			Game.p["hp"], Game.max_hp(), Game.p["essence"], Game.p["kills"],
			get_tree().get_nodes_in_group("enemies").size(), Game.p["stones"], Game.p["pos"], Game.world.zone_at(Game.p["pos"])])
