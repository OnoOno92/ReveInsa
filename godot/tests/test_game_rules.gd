extends "res://tests/test_case.gd"
## Rules in the Game autoload. Tests create a fresh instance (not the live autoload).

func _game():
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	return g

func test_new_game_starts_with_two_placed_gu() -> void:
	var g = _game()
	assert_eq(g.p["gu"].size(), 2)
	assert_eq(g.p["placed"].size(), 2)
	assert_true(g.build["attacks"].size() >= 1, "moonlight should be active")
	g.free()

func test_gu_eats_at_dawn_and_starves_without_food() -> void:
	var g = _game()
	g.p["inventory"] = {} # no food at all
	g.advance_time(4.0)
	var moon = g.p["gu"].filter(func(x): return x["def"] == "moonlight")
	assert_eq(moon.size(), 1, "still alive after 4 days (feeds every 3, dies at 6)")
	assert_true(Aperture.is_starving(moon[0]), "but starving")
	g.advance_time(3.0)
	assert_eq(g.p["gu"].filter(func(x): return x["def"] == "moonlight").size(), 0, "dead after feed_every + 3 days")
	g.free()

func test_gu_fed_from_inventory() -> void:
	var g = _game()
	g.p["inventory"] = {"moon_orchid": 5, "herb": 5, "stone": 5}
	g.advance_time(3.0)
	assert_eq(g.count("moon_orchid"), 4, "moonlight ate one orchid on day 3")
	g.free()

func test_cultivation_ranks_up_and_grows_aperture() -> void:
	var g = _game()
	g.p["stones"] = 100000
	for i in 40:
		g.cultivate()
	assert_true(g.p["rank"] >= 2, "rank should increase")
	assert_eq(g.ap_size(), 3 + g.p["rank"])
	g.free()

func test_rank_lock_on_placement() -> void:
	var g = _game()
	var inst = g.add_gu("moon_glow")
	assert_false(g.place_gu(inst["uid"], 2, 2, 0), "rank 2 Gu cannot be placed at rank 1")
	g.free()

func test_armor_reduces_damage() -> void:
	var g = _game()
	g.shield = 0.0
	var before: float = g.p["hp"]
	g.hurt_player(30.0, "test")
	var taken: float = before - g.p["hp"]
	assert_near(taken, 30.0 * 30.0 / (30.0 + g.stat("armor")), 0.01)
	g.free()

func test_save_load_roundtrip() -> void:
	var g = _game()
	g.p["stones"] = 777
	g.add_item("jade_shard", 3)
	g.save_game()
	var h = load("res://game/game.gd").new()
	h.save_path = g.save_path
	assert_true(h.load_game())
	assert_eq(h.p["stones"], 777)
	assert_eq(h.count("jade_shard"), 3)
	assert_eq(h.p["placed"].size(), g.p["placed"].size())
	assert_eq(h.build["attacks"].size(), g.build["attacks"].size())
	g.free(); h.free()
