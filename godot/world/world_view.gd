extends Node2D
## The playable world: terrain, props, player, enemies, combat, loot, lighting.

const PlayerScript := preload("res://actors/player.gd")
const PropScript := preload("res://world/props.gd")
const CombatScript := preload("res://game/combat.gd")
const FxScript := preload("res://game/fx.gd")
const PickupsScript := preload("res://game/pickups.gd")
const SightingLayerScript := preload("res://world/sighting_layer.gd")
const TribulationScript := preload("res://game/tribulation.gd")
const WandererScript := preload("res://actors/wanderer.gd")
const CHUNK_TILES := 16

var ground: TileMapLayer
var entities: Node2D
var ground_props: Node2D
var tribulation: Node2D
var player: CharacterBody2D
var camera: Camera2D
var combat: Node2D
var fx: Node2D
var pickups: Node2D
var night_tint: CanvasModulate
var chunks := {} # Vector2i -> Node2D
var props: Array = [] # all node props
var campfire_props: Array = []
var interact := {} # {kind: node|npc|sign, prop, label}
var _highlight: Node2D
var _chunk_t := 0.0
var _reveal_t := 0.0
var _wall_t := 0.0
var _action_cd := 0.0


func _ready() -> void:
	var w := Game.world
	ground = TileMapLayer.new()
	ground.tile_set = TilesetBuilder.build(w.seed_value)
	add_child(ground)
	for y in WorldData.H:
		for x in WorldData.W:
			var v := floori(WorldData.hash2(x, y, 31) * TilesetBuilder.VARIANTS)
			ground.set_cell(Vector2i(x, y), 0, Vector2i(v, w.tiles[y * WorldData.W + x]))

	pickups = PickupsScript.new()
	pickups.view = self
	add_child(pickups)

	ground_props = Node2D.new() # flat things on the ground: spirit fields
	add_child(ground_props)
	add_child(SightingLayerScript.new())

	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	for n in w.nodes:
		var prop := PropScript.new()
		prop.setup("node", n)
		_chunk_for(n["pos"]).add_child(prop)
		props.append(prop)
	for npc in w.npcs:
		var prop := PropScript.new()
		prop.setup("npc", npc)
		entities.add_child(prop)
	for s in w.signs:
		var prop := PropScript.new()
		prop.setup("sign", s)
		entities.add_child(prop)
	for poi in WorldData.POIS:
		if poi["id"] in ["village", "city"]:
			var l := Lights.make(poi["r"] * WorldData.TILE * 1.2, Color(1.0, 0.85, 0.6), 0.9)
			l.position = WorldData.poi_center(poi["id"])
			add_child(l)

	player = PlayerScript.new()
	entities.add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)

	combat = CombatScript.new()
	combat.view = self
	combat.z_index = 5
	add_child(combat)
	fx = FxScript.new()
	fx.z_index = 10
	add_child(fx)
	tribulation = TribulationScript.new()
	tribulation.view = self
	add_child(tribulation)
	night_tint = CanvasModulate.new()
	add_child(night_tint)

	Game.teleported.connect(_on_teleported)
	Game.died.connect(func(): combat.clear_enemies(); pickups.clear())
	Game.player_hurt.connect(func(d): fx.text(Game.p["pos"] + Vector2(0, -24), "-%d" % ceili(d), Color.html("#ff5252")))
	Game.new_day.connect(func(_d): combat.spawn_boss_if_needed())
	Game.changed.connect(_sync_campfires)
	combat.spawn_boss_if_needed()
	_sync_campfires()
	_update_chunks()
	_update_tint()


func _chunk_for(pos: Vector2) -> Node2D:
	var k := Vector2i(floori(pos.x / WorldData.TILE / CHUNK_TILES), floori(pos.y / WorldData.TILE / CHUNK_TILES))
	if not chunks.has(k):
		var c := Node2D.new()
		c.y_sort_enabled = true
		entities.add_child(c)
		chunks[k] = c
	return chunks[k]


func _update_chunks() -> void:
	var pk := Vector2(Game.p["pos"]) / (WorldData.TILE * CHUNK_TILES)
	for k in chunks:
		var vis: bool = absf(k.x + 0.5 - pk.x) < 2.5 and absf(k.y + 0.5 - pk.y) < 2.0
		var c: Node2D = chunks[k]
		c.visible = vis
		if vis:
			for prop in c.get_children():
				prop.refresh()


func _update_tint() -> void:
	var dark := Game.darkness()
	night_tint.color = Color.WHITE.lerp(Color(0.12, 0.14, 0.32), dark)
	if Game.in_tribulation:
		# Heaven's storm: the sky darkens towards the tribulation's colour
		var storm: Color = Color(tribulation.theme.get("color", "#d9c7ff")).darkened(0.55)
		night_tint.color = night_tint.color.lerp(storm, 0.5)
	var k := dark / 0.82
	for l in get_tree().get_nodes_in_group("night_lights"):
		l.energy = float(l.get_meta("base_energy", 1.0)) * k
		l.visible = k > 0.01


func _sync_campfires() -> void:
	_sync_plots()
	if campfire_props.size() == Game.campfires.size():
		return
	for c in campfire_props:
		c.queue_free()
	campfire_props.clear()
	for c in Game.campfires:
		var prop := PropScript.new()
		prop.setup("campfire", c)
		entities.add_child(prop)
		campfire_props.append(prop)


var plot_props: Array = []
func _sync_plots() -> void:
	if plot_props.size() == Game.plots.size():
		return
	for pp in plot_props:
		pp.queue_free()
	plot_props.clear()
	for pl in Game.plots:
		var prop := PropScript.new()
		prop.setup("plot", pl)
		ground_props.add_child(prop)
		plot_props.append(prop)


func _on_teleported(pos: Vector2) -> void:
	player.position = pos
	camera.reset_smoothing()
	combat.clear_enemies()
	pickups.clear()
	_update_chunks()


func _process(delta: float) -> void:
	Game.tick(delta)
	var vis := get_viewport_rect().size
	var z := clampf(minf(vis.x, vis.y) / 620.0, 0.75, 2.4)
	camera.zoom = Vector2(z, z)
	_update_tint()
	_chunk_t -= delta
	if _chunk_t <= 0.0:
		_chunk_t = 0.5
		_update_people_presence()
		_update_chunks()
		_sync_campfires()
	_reveal_t -= delta
	if _reveal_t <= 0.0:
		_reveal_t = 0.25
		Game.world.reveal(Game.p["pos"], 9.0 + Game.stat("reveal"))
	_wall_check(delta)
	_find_interactable()
	_action_cd = maxf(0.0, _action_cd - delta)
	if Input.is_action_just_pressed("interact") or Game.action_requested:
		Game.action_requested = false
		do_action()


func _wall_check(delta: float) -> void:
	_wall_t -= delta
	if _wall_t > 0.0:
		return
	var t := WorldData.to_tile(Game.p["pos"])
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if Game.world.tile_at(t + d) == WorldData.T.WALL:
			Game.toast.emit(Game.world.wall_name(Game.p["pos"]) + ". Only a Gu Immortal could pass.", "info")
			_wall_t = 8.0
			return


# ------------------------------------------------------------------ interaction
var person_actors := {} # person id -> Node (wanderer or enemy)

## People near the player become actors; far ones return to the abstract simulation.
func _update_people_presence() -> void:
	var ppos: Vector2 = Game.p["pos"]
	for pp in Game.people:
		var id: int = pp["id"]
		var a: Node = person_actors.get(id)
		if a != null and not is_instance_valid(a):
			person_actors.erase(id)
			Game.people_present.erase(id)
			a = null
		var is_companion: bool = int(Game.p.get("companion", {}).get("id", -1)) == id
		if a != null:
			if a.has_meta("person_id"):
				pp["pos"] = a.position # hostile actors move on their own
			if not pp["alive"] or is_companion or (pp["pos"] as Vector2).distance_to(ppos) > People.LEAVE_RADIUS:
				a.queue_free()
				person_actors.erase(id)
				Game.people_present.erase(id)
			continue
		if is_companion:
			pp["pos"] = ppos # travelling with you (drawn by the companion ally)
			continue
		if not pp["alive"] or Game.in_tribulation or id == Game.duel_id:
			continue
		if (pp["pos"] as Vector2).distance_to(ppos) > People.MEET_RADIUS:
			continue
		if People.is_hostile(pp):
			if Game.world.is_safe(pp["pos"]):
				continue
			a = combat.spawn("demonic_master", pp["pos"])
			var st := People.combat_stats(pp)
			a.max_hp = st["hp"]; a.hp = a.max_hp; a.dmg_scale = st["dmg_scale"]
			a.display_name = pp["name"]
			a.set_meta("person_id", id)
		else:
			a = WandererScript.new()
			a.setup(pp)
			entities.add_child(a)
		if not pp["met"]:
			pp["met"] = true
			Game.log_event("You met %s, a %s." % [pp["name"], People.AFFILIATION_NAMES[pp["affiliation"]].to_lower()])
		person_actors[id] = a
		Game.people_present[id] = true


func _find_interactable() -> void:
	var ppos: Vector2 = Game.p["pos"]
	var best := {}
	var best_d := 60.0 * 60.0
	for prop in entities.get_children():
		if prop.get("kind") == "npc":
			var d: float = prop.position.distance_squared_to(ppos)
			if d < best_d:
				best_d = d
				var role: String = prop.data["role"]
				best = {"kind": "npc", "prop": prop, "label": {"merchant": "Trade", "elder": "Cultivate", "caravan": "Travel"}[role]}
	for a in person_actors.values():
		if is_instance_valid(a) and a.get("kind") == "person":
			var d: float = a.position.distance_squared_to(ppos)
			if d < best_d:
				best_d = d
				best = {"kind": "person", "prop": a, "label": "Talk"}
	if best.is_empty():
		var candidates: Array = []
		for n in Game.world.nodes_near(ppos, 52.0):
			candidates.append(n)
		for prop in _props_near(candidates):
			if not prop.is_available():
				continue
			var d: float = prop.position.distance_squared_to(ppos)
			if d < best_d:
				best_d = d
				best = {"kind": "node", "prop": prop, "label": WorldData.NODE_INFO[prop.data["type"]]["verb"]}
	if best.is_empty():
		for prop in plot_props:
			var d: float = prop.position.distance_squared_to(ppos)
			if d < best_d:
				best_d = d
				var pl: Dictionary = prop.data
				var stage := Game.plot_stage(pl)
				var label := "Plant" if stage == "Empty" else ("Harvest" if stage in ["Ripe", "Overripe"] else ("Tend" if Game.can_tend(pl) else "Growing"))
				best = {"kind": "plot", "prop": prop, "label": label}
	if best.is_empty():
		for prop in entities.get_children():
			if prop.get("kind") == "sign" and prop.position.distance_squared_to(ppos) < best_d:
				best = {"kind": "sign", "prop": prop, "label": "Read"}
	var new_hl: Node2D = best.get("prop")
	if new_hl != _highlight:
		if is_instance_valid(_highlight):
			_highlight.highlighted = false
		if new_hl:
			new_hl.highlighted = true
		_highlight = new_hl
	interact = best


var _prop_index := {}
func _props_near(node_dicts: Array) -> Array:
	if _prop_index.is_empty():
		for prop in props:
			_prop_index[prop.data["id"]] = prop
	var out: Array = []
	for n in node_dicts:
		out.append(_prop_index[n["id"]])
	return out


func do_action() -> void:
	if interact.is_empty() or _action_cd > 0.0:
		return
	_action_cd = 0.35
	var prop: Node2D = interact["prop"]
	match interact["kind"]:
		"npc":
			Game.npc_interact.emit(prop.data)
		"sign":
			Game.toast.emit(prop.data["text"], "info")
		"node":
			_gather(prop)
		"person":
			Game.person_interact.emit(prop.data)
		"plot":
			var pl: Dictionary = prop.data
			match interact["label"]:
				"Plant": Game.plot_interact.emit(pl)
				"Harvest":
					var n := Game.harvest(pl["id"])
					fx.text(pl["pos"] + Vector2(0, -20), "+%d" % n, Color("#ffe9a8"))
				"Tend":
					Game.tend(pl["id"])
					fx.add("burst", pl["pos"], Color("#7fd0ff"), 0.4)
				_:
					Game.toast.emit("The %s is %s (%d%%). You can tend it again soon." % [ItemDB.ITEMS[pl["crop"]]["name"], Game.plot_stage(pl).to_lower(), roundi(pl["growth"] * 100)], "info")


func _gather(prop: Node2D) -> void:
	var n: Dictionary = prop.data
	if n["type"] == "chest":
		Game.loot_inheritance()
		fx.add("ring", n["pos"], Color.html("#ffd76b"), 1.5, {"r": 160.0})
		prop.refresh()
		return
	n["hp"] -= 1
	fx.add("burst", n["pos"] + Vector2(0, -10), Color.html("#a77b4f") if n["type"] == "tree" else Color(0.8, 0.8, 0.8), 0.3)
	if n["hp"] > 0:
		return
	var at: Vector2 = n["pos"]
	var drop := func(item: String, c: int) -> void:
		if c > 0:
			pickups.drop(at + Vector2(randf_range(-10, 10), randf_range(-10, 10)), item, c)
	match n["type"]:
		"tree": drop.call("wood", randi_range(2, 3))
		"rock":
			drop.call("stone", randi_range(1, 3))
			if randf() < 0.06: drop.call("jade_shard", 1)
			if randf() < 0.15: pickups.drop(at, "", 0, randi_range(1, 3))
		"bush":
			drop.call("berries", randi_range(1, 3))
			if randf() < 0.4: drop.call("herb", 1)
		"orchid":
			drop.call("moon_orchid", 1)
			if randf() < 0.3: drop.call("herb", 1)
		"jade":
			drop.call("jade_shard", randi_range(1, 2))
			drop.call("stone", 1)
	n["hp"] = WorldData.NODE_INFO[n["type"]]["hp"]
	n["regrow_day"] = Game.time + WorldData.NODE_INFO[n["type"]]["regrow"]
	prop.refresh()
