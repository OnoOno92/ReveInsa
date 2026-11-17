extends "res://tests/test_case.gd"
## Spirit fields: planting, growth, tending, harvest, rot, trampling, saving.

func _game():
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	g.time = 2.2 # daytime
	return g

func _field(g) -> Dictionary:
	# a fresh field far from water so growth is predictable
	for attempt in 400:
		var pos: Vector2 = WorldData.poi_center("village") + Vector2(randf_range(-60, 60), randf_range(-60, 20)) * WorldData.TILE
		var g2 = g
		var pl: Dictionary = g2.add_plot(pos)
		if not g2.world.is_solid_pos(pos) and is_equal_approx(g2.plot_growth_mult(pl), 1.0):
			return pl
		g2.plots.erase(pl)
	return {}

func test_village_starts_with_two_fields() -> void:
	var g = _game()
	assert_eq(g.plots.size(), 2)
	for pl in g.plots:
		assert_false(g.world.is_solid_pos(pl["pos"]), "field on walkable ground")
	g.free()

func test_every_crop_is_a_real_item() -> void:
	for crop in ItemDB.CROPS:
		assert_true(ItemDB.ITEMS.has(crop), crop)

func test_plant_grow_harvest() -> void:
	var g = _game()
	var pl := _field(g)
	g.add_item("herb", 1)
	var before: int = g.count("herb")
	assert_true(g.plant(pl["id"], "herb"))
	assert_eq(g.count("herb"), before - 1, "planting uses one")
	assert_eq(Game.plot_stage(pl), "Seeded")
	g.grow_plots(0.3) # herb ripens in 0.6 day
	assert_eq(Game.plot_stage(pl), "Sprouting")
	g.grow_plots(0.31)
	assert_eq(Game.plot_stage(pl), "Ripe")
	var n: int = g.harvest(pl["id"])
	assert_eq(n, 3, "base herb yield")
	assert_eq(pl["crop"], "", "field empty again")
	g.free()

func test_tending_speeds_growth_and_raises_quality() -> void:
	var g = _game()
	var pl := _field(g)
	g.add_item("berries", 1)
	g.plant(pl["id"], "berries")
	assert_true(g.tend(pl["id"]))
	assert_near(pl["growth"], 0.15)
	assert_false(g.tend(pl["id"]), "tending has a cooldown")
	g.time += 0.25
	assert_true(g.tend(pl["id"]))
	g.grow_plots(1.0)
	assert_eq(g.harvest(pl["id"]), 3 + 2, "quality adds to the harvest")
	g.free()

func test_ripe_crops_rot() -> void:
	var g = _game()
	var pl := _field(g)
	g.add_item("spirit_rice", 1)
	g.plant(pl["id"], "spirit_rice")
	g.grow_plots(0.8)
	assert_eq(Game.plot_stage(pl), "Ripe")
	g.grow_plots(0.7)
	assert_eq(Game.plot_stage(pl), "Overripe")
	g.grow_plots(0.5)
	assert_eq(pl["crop"], "", "rotted away")
	g.free()

func test_moon_orchid_grows_faster_at_night() -> void:
	var g = _game()
	var pl := _field(g)
	g.add_item("moon_orchid", 1)
	g.plant(pl["id"], "moon_orchid")
	g.time = 2.85 # night
	g.grow_plots(0.1)
	assert_near(pl["growth"], 0.15, 0.001)
	g.free()

func test_resting_grows_fields() -> void:
	var g = _game()
	var pl := _field(g)
	g.add_item("berries", 1)
	g.plant(pl["id"], "berries")
	g.rest_until_dawn()
	assert_true(pl["growth"] > 0.5, "grew overnight: %.2f" % pl["growth"])
	g.free()

func test_fields_survive_save_load() -> void:
	var g = _game()
	var pl: Dictionary = g.plots[0]
	g.add_item("herb", 1)
	g.plant(pl["id"], "herb")
	g.tend(pl["id"])
	g.save_game()
	var h = load("res://game/game.gd").new()
	h.save_path = g.save_path
	assert_true(h.load_game())
	var back: Dictionary = h.find_plot(pl["id"])
	assert_eq(back["crop"], "herb")
	assert_eq(back["quality"], 1)
	assert_eq(back["pos"], pl["pos"])
	g.free(); h.free()

func test_building_a_field() -> void:
	var g = _game()
	g.add_item("wood", 4); g.add_item("stone", 2); g.add_item("herb", 1)
	g.craft("plot")
	assert_eq(g.plots.size(), 3)
	g.free()
