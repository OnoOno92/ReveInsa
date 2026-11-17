extends "res://tests/test_case.gd"
## The people of the Southern Border and the World Chronicle.

func _game():
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	return g

func _of(g, aff: String) -> Dictionary:
	return g.people.filter(func(pp): return pp["affiliation"] == aff)[0]

func test_population() -> void:
	var g = _game()
	var counts := {}
	for pp in g.people:
		counts[pp["affiliation"]] = counts.get(pp["affiliation"], 0) + 1
	for aff in People.COUNT:
		assert_eq(counts.get(aff, 0), People.COUNT[aff], aff)
	var names := {}
	for pp in g.people:
		assert_false(names.has(pp["name"]), "unique names")
		names[pp["name"]] = true
		for gid in pp["gu"]:
			assert_true(GuDB.GU.has(gid))
	assert_true(_of(g, "shang")["stock"].size() > 0, "merchants carry wares")
	g.free()

func test_hostility() -> void:
	var g = _game()
	assert_true(People.is_hostile(_of(g, "demonic")))
	assert_false(People.is_hostile(_of(g, "clan")))
	g.free()

func test_life_goes_on_and_is_chronicled() -> void:
	var g = _game()
	var start: int = g.chronicle.size()
	g.advance_time(12.0)
	assert_true(g.chronicle.size() > start + 2, "things happened: %d" % (g.chronicle.size() - start))
	assert_true(g.chronicle.size() <= People.CHRONICLE_MAX)
	assert_true(g.people.filter(func(pp): return pp["alive"]).size() >= 6, "the dead are replaced")
	g.free()

func test_people_move_toward_targets() -> void:
	var g = _game()
	var pp := _of(g, "rogue")
	pp["target"] = pp["pos"] + Vector2(3000, 0)
	var d0: float = (pp["pos"] as Vector2).distance_to(pp["target"])
	g._update_people(10.0)
	assert_true((pp["pos"] as Vector2).distance_to(pp["target"]) < d0)
	g.free()

func test_gifts_raise_favor() -> void:
	var g = _game()
	var pp := _of(g, "rogue")
	var f: float = pp["favor"]
	g.p["stones"] = 100
	g.give_gift(pp["id"])
	assert_near(pp["favor"], f + 8.0)
	assert_eq(g.p["stones"], 90)
	g.add_item("rice_ball", 1)
	g.give_gift(pp["id"], "rice_ball")
	assert_near(pp["favor"], f + 13.0)
	g.free()

func test_recruit_requires_friendship() -> void:
	var g = _game()
	var pp := _of(g, "clan")
	pp["favor"] = 20.0
	assert_true(g.can_recruit(pp) != "")
	pp["favor"] = 45.0
	assert_eq(g.can_recruit(pp), "")
	g.recruit(pp["id"])
	assert_true(g.p.has("companion"))
	g.advance_time(1.1)
	g._update_people(0.0)
	assert_false(g.p.has("companion"), "leaves after a day")
	assert_true(g.can_recruit(_of(g, "shang")) != "", "merchants don't travel with you")
	g.free()

func test_merchant_trade() -> void:
	var g = _game()
	var pp := _of(g, "shang")
	var item: String = pp["stock"][0]
	g.p["stones"] = 1000
	g.buy_from(pp["id"], item)
	assert_eq(g.count(item), 1)
	assert_eq(g.p["stones"], 1000 - ceili(ItemDB.ITEMS[item]["price"] * 2.5))
	g.free()

func test_duel_ends_in_a_yield_not_death() -> void:
	var g = _game()
	var pp := _of(g, "rogue")
	g.p["pos"] = WorldData.poi_center("village") + Vector2(0, -20 * WorldData.TILE)
	g.start_duel(pp["id"])
	assert_eq(g.duel_id, pp["id"])
	g.hurt_player(99999.0, "duel")
	assert_eq(g.duel_id, -1, "duel over")
	assert_near(g.p["hp"], g.max_hp() * 0.2, 0.01, "you yield at 20%")
	g.free()

func test_duel_win_rewards() -> void:
	var g = _game()
	var pp := _of(g, "clan")
	g.p["pos"] = WorldData.poi_center("village") + Vector2(0, -20 * WorldData.TILE)
	var stones: int = g.p["stones"]
	var f: float = pp["favor"]
	g.start_duel(pp["id"])
	g.end_duel(true)
	assert_eq(g.p["stones"], stones + 15 * pp["rank"])
	assert_near(pp["favor"], f + 10.0)
	g.free()

func test_no_duels_inside_the_village() -> void:
	var g = _game()
	g.p["pos"] = WorldData.poi_center("village")
	g.start_duel(_of(g, "clan")["id"])
	assert_eq(g.duel_id, -1)
	g.free()

func test_people_survive_save_load() -> void:
	var g = _game()
	var pp := _of(g, "clan")
	pp["favor"] = 42.0
	pp["met"] = true
	g.log_event("test entry")
	g.save_game()
	var h = load("res://game/game.gd").new()
	h.save_path = g.save_path
	assert_true(h.load_game())
	var back: Dictionary = h.find_person(pp["id"])
	assert_eq(back["name"], pp["name"])
	assert_near(back["favor"], 42.0)
	assert_true(back["met"])
	assert_eq(typeof(back["id"]), TYPE_INT)
	assert_eq(back["pos"], pp["pos"])
	assert_eq(h.chronicle[-1]["text"], "test entry")
	g.free(); h.free()
