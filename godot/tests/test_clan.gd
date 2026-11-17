extends "res://tests/test_case.gd"
## Clan missions, treasury, beast tides, summons and the new killer moves.

func _game():
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	return g

func _gu(list: Array) -> Array:
	var out: Array = []
	for i in list.size():
		out.append({"uid": i + 1, "def": list[i], "unfed": 0})
	return out

func test_board_is_filled_on_new_game() -> void:
	var g = _game()
	assert_eq(g.missions()["offered"].size(), Quests.MAX_OFFERED)
	g.free()

func test_hunt_mission_progress_and_reward() -> void:
	var g = _game()
	var q := {"id": 999, "type": "hunt", "target": "wolf", "count": 2, "progress": 0, "stones": 10, "contrib": 5, "title": "t"}
	g.p["quests"]["active"].append(q)
	g.on_enemy_killed("boar", false)
	assert_eq(q["progress"], 0, "wrong enemy does not count")
	g.on_enemy_killed("wolf", false)
	g.on_enemy_killed("wolf", false)
	g.on_enemy_killed("wolf", false)
	assert_eq(q["progress"], 2, "progress caps at count")
	var stones: int = g.p["stones"]
	g.claim_mission(999)
	assert_eq(g.p["stones"], stones + 10)
	assert_eq(g.p["contrib"], 5)
	assert_eq(g.p["quests"]["active"].size(), 0)
	g.free()

func test_gather_mission_consumes_items() -> void:
	var g = _game()
	g.p["quests"]["active"].append({"id": 7, "type": "gather", "target": "pelt", "count": 3, "progress": 0, "stones": 5, "contrib": 2, "title": "t"})
	g.add_item("pelt", 2)
	g.claim_mission(7)
	assert_eq(g.p["quests"]["active"].size(), 1, "not enough pelts yet")
	g.add_item("pelt", 2)
	g.claim_mission(7)
	assert_eq(g.p["quests"]["active"].size(), 0)
	assert_eq(g.count("pelt"), 1, "3 pelts handed over")
	g.free()

func test_accept_limit() -> void:
	var g = _game()
	for i in 5:
		g.refill_missions()
		var offered: Array = g.missions()["offered"]
		g.accept_mission(offered[0]["id"])
	assert_eq(g.missions()["active"].size(), Quests.MAX_ACTIVE)
	g.free()

func test_treasury_pill_raises_aptitude() -> void:
	var g = _game()
	g.p["contrib"] = 500
	var before: float = g.p["aptitude"]
	g.buy_treasury("aptitude_pill")
	assert_near(g.p["aptitude"], minf(0.99, before + 0.05), 0.0001)
	assert_eq(g.p["contrib"], 380)
	g.free()

func test_beast_tide_opens_the_village() -> void:
	var g = _game()
	var heart := WorldData.poi_center("village")
	g.time = 2.8 # Day 3 night: no tide
	assert_true(g.blocks_enemies(heart))
	g.time = 4.8 # Day 5 night: tide
	assert_true(g.tide_active())
	assert_false(g.blocks_enemies(heart), "village is open to raiders during the tide")
	assert_true(g.blocks_enemies(WorldData.poi_center("city")), "the city stays safe")
	g.free()

func test_tide_reward_paid_at_dawn() -> void:
	var g = _game()
	g.time = 4.6
	g.tick(0.0)
	g._tide_transitions(0.6)
	g.time = 4.7
	g._tide_transitions(0.6)
	assert_true(g.flags.get("tide_on", false))
	g.on_enemy_killed("wolf", true)
	g.on_enemy_killed("wolf", true)
	var contrib: int = g.p["contrib"]
	g.advance_time(0.5)
	assert_eq(g.p["contrib"], contrib + 2 * 2 + 15)
	g.free()

func test_summon_and_wolf_pack_killer_move() -> void:
	var gu := _gu(["wolf_slave", "earth_ear"])
	var alone := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}], gu)
	assert_eq(alone["summons"].size(), 1)
	assert_eq(alone["summons"][0]["count"], 1)
	var pack := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 2, "y": 0, "rot": 0}], gu)
	assert_eq(pack["summons"][0]["count"], 2, "Wolf Pack Command adds a wolf")
	assert_near(pack["summons"][0]["damage"], 7.0 * 1.5)

func test_steam_burst() -> void:
	var gu := _gu(["water_arrow", "spark"])
	var b := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 2, "y": 0, "rot": 0}], gu)
	assert_eq(b["killer_moves"].size(), 1)
	assert_eq(b["attacks"].size(), 3, "two Gu attacks + the killer move")

func test_all_shop_and_treasury_ids_exist() -> void:
	for shop in ItemDB.SHOPS.values():
		for id in shop["gu"]:
			assert_true(GuDB.GU.has(id), "shop Gu %s" % id)
		for id in shop["items"]:
			assert_true(ItemDB.ITEMS.has(id), "shop item %s" % id)
	for e in Quests.TREASURY:
		if e["kind"] == "gu":
			assert_true(GuDB.GU.has(e["id"]), "treasury %s" % e["id"])
	for km in GuDB.KILLER_MOVES:
		for r in km["requires"]:
			assert_true(GuDB.GU.has(r), "killer move part %s" % r)
	for g in GuDB.GU.values():
		assert_true(ItemDB.ITEMS.has(g["food"]), "%s food %s" % [g["name"], g["food"]])
		assert_true(GuDB.PATH_COLORS.has(g["path"]), "%s path" % g["name"])
