extends "res://tests/test_case.gd"
## Alchemy furnace, pills, buffs.

func _game():
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	g.p["pos"] = WorldData.poi_center("village") + Vector2(0, -16 * WorldData.TILE) # out in the wilds
	return g

func test_every_pill_has_a_recipe_and_valid_ingredients() -> void:
	var brewed := {}
	for r in ItemDB.RECIPES:
		for k in r["needs"]:
			assert_true(ItemDB.ITEMS.has(k), "%s needs unknown item %s" % [r["id"], k])
		if ItemDB.category(r) == "alchemy":
			brewed[r["output"]["item"]] = true
	for id in ItemDB.ITEMS:
		if ItemDB.ITEMS[id].has("pill"):
			assert_true(brewed.has(id), "no recipe brews %s" % id)

func test_brewing_needs_a_furnace() -> void:
	var g = _game()
	var r := ItemDB.recipe("a_vitality")
	g.add_item("herb", 10); g.add_item("berries", 10)
	assert_eq(g.can_craft(r), "Needs an alchemy furnace")
	g.p["pos"] = WorldData.poi_center("village")
	assert_eq(g.can_craft(r), "", "settlements have a furnace")
	g.free()

func test_built_furnace_is_permanent_and_works_as_station() -> void:
	var g = _game()
	g.add_item("stone", 10); g.add_item("wood", 6); g.add_item("bone", 2)
	g.craft("furnace")
	assert_true(g.near_furnace(g.p["pos"]))
	g.advance_time(5.0)
	assert_true(g.near_furnace(g.p["pos"]), "furnaces never burn out")
	assert_true(g.near_fire(g.p["pos"]), "you can cook at it too")
	g.free()

func test_brewing_gives_pills_and_mastery() -> void:
	var g = _game()
	g.p["pos"] = WorldData.poi_center("village")
	g.add_item("herb", 60); g.add_item("berries", 40)
	for i in 20:
		g.craft("a_vitality")
	assert_eq(g.p["alchemy_xp"], 20)
	assert_true(g.count("pill_vitality") >= 10, "most brews succeed: %d" % g.count("pill_vitality"))
	assert_true(g.alchemy_level() >= 2)
	assert_true(g.alchemy_success() > 0.7)
	g.free()

func test_instant_pills() -> void:
	var g = _game()
	g.p["hp"] = 10.0
	g.add_item("pill_vitality", 1)
	g.take_pill("pill_vitality")
	assert_near(g.p["hp"], 10.0 + g.max_hp() * 0.4)
	for gu in g.p["gu"]:
		gu["unfed"] = 9
	g.add_item("pill_nourish", 1)
	g.take_pill("pill_nourish")
	for gu in g.p["gu"]:
		assert_eq(gu["unfed"], 0, "all Gu fed")
	g.free()

func test_buff_pill_adds_stats_then_expires() -> void:
	var g = _game()
	var armor: float = g.stat("armor")
	g.add_item("pill_iron", 2)
	g.take_pill("pill_iron")
	assert_near(g.stat("armor"), armor + 15.0)
	assert_near(g.buff_seconds("pill_iron"), 90.0, 0.5)
	g.take_pill("pill_iron")
	assert_near(g.stat("armor"), armor + 15.0, 0.001, "same pill refreshes, does not stack")
	g.time += 100.0 / Game.DAY_SECONDS
	g._expire_buffs()
	assert_near(g.stat("armor"), armor)
	g.free()

func test_breakthrough_aid() -> void:
	var g = _game()
	g.p["stones"] = 1000
	g.p["aptitude"] = 0.5
	g.cultivate()
	var normal: float = g.p["cultivation"]
	g.p["cultivation"] = 0.0
	g.add_item("pill_breakthrough", 1)
	g.take_pill("pill_breakthrough")
	g.cultivate()
	assert_near(g.p["cultivation"], normal * 1.5)
	assert_false(g.p["breakthrough_aid"], "used up")
	g.free()

func test_buffs_survive_save_load() -> void:
	var g = _game()
	g.add_item("pill_wind", 1)
	g.take_pill("pill_wind")
	g.add_item("stone", 10); g.add_item("wood", 6); g.add_item("bone", 2)
	g.craft("furnace")
	g.save_game()
	var h = load("res://game/game.gd").new()
	h.save_path = g.save_path
	assert_true(h.load_game())
	assert_near(h.stat("move_speed"), g.stat("move_speed"))
	assert_true(h.near_furnace(g.p["pos"]), "furnace saved")
	g.free(); h.free()
