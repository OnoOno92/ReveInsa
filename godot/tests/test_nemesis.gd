extends "res://tests/test_case.gd"
## The nemesis: emergence, growth, grudge, phases, engagement, defeat, escape, saving.

func _game():
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	return g

func _with_nemesis():
	var g = _game()
	g.advance_time(1.0) # dawn of Day 2
	return g

func test_emerges_on_day_two() -> void:
	var g = _game()
	assert_true(g.nemesis.is_empty())
	g.advance_time(1.0)
	assert_false(g.nemesis.is_empty())
	assert_true(g.nemesis["alive"])
	assert_true(Nemesis.TITLES.has(g.nemesis["path"]))
	g.free()

func test_name_is_deterministic_per_world() -> void:
	var a := Nemesis.create(777, 1, Vector2.ZERO)
	var b := Nemesis.create(777, 1, Vector2.ZERO)
	var c := Nemesis.create(778, 1, Vector2.ZERO)
	assert_eq(a["name"], b["name"])
	assert_true(a["name"] != c["name"] or a["path"] != c["path"], "different worlds, different nemesis (usually)")

func test_arsenal_and_titles_are_valid() -> void:
	for path in Nemesis.PATHS:
		assert_true(Nemesis.TITLES.has(path))
		for gid in Nemesis.ARSENAL[path]:
			assert_true(GuDB.GU.has(gid), "%s arsenal: %s" % [path, gid])

func test_phases_follow_grudge() -> void:
	var n := {"grudge": 10.0}
	assert_eq(Nemesis.phase(n), "emerging")
	n["grudge"] = 50.0
	assert_eq(Nemesis.phase(n), "rival")
	Nemesis.add_grudge(n, 500.0)
	assert_eq(n["grudge"], 100.0, "capped")
	assert_eq(Nemesis.phase(n), "threat")

func test_grows_but_stays_within_one_rank() -> void:
	var g = _with_nemesis()
	var n: Dictionary = g.nemesis
	assert_eq(n["rank"], 1)
	for i in 10:
		Nemesis.grow(n, 1)
	assert_true(n["power"] > 1.7)
	assert_eq(n["rank"], 2, "one rank above a rank-1 player")
	Nemesis.sync_rank(n, 5)
	assert_eq(n["rank"], 5, "never above rank 5")
	g.free()

func test_grudge_sources() -> void:
	var g = _with_nemesis()
	var n: Dictionary = g.nemesis
	var before: float = n["grudge"]
	g.on_enemy_killed("demonic_master", false)
	assert_near(n["grudge"], before + 8.0)
	g.loot_inheritance()
	assert_near(n["grudge"], before + 38.0)
	g.free()

func test_engages_when_close_in_the_wilds() -> void:
	var g = _with_nemesis()
	var hits := [0]
	g.nemesis_engage.connect(func(_n): hits[0] += 1)
	g.p["pos"] = WorldData.poi_center("village") + Vector2(0, -20 * WorldData.TILE)
	g.nemesis["grudge"] = 80.0
	g.nemesis["pos"] = g.p["pos"] + Vector2(5 * WorldData.TILE, 0)
	g._update_nemesis(0.1)
	assert_true(g.nemesis_present)
	assert_eq(hits[0], 1)
	g._update_nemesis(0.1)
	assert_eq(hits[0], 1, "only once while present")
	g.free()

func test_never_engages_in_a_settlement() -> void:
	var g = _with_nemesis()
	g.p["pos"] = WorldData.poi_center("village")
	g.nemesis["grudge"] = 100.0
	g.nemesis["pos"] = g.p["pos"] + Vector2(64, 0)
	g._update_nemesis(0.1)
	assert_false(g.nemesis_present)
	g.free()

func test_threat_hunts_the_player() -> void:
	var g = _with_nemesis()
	g.p["pos"] = WorldData.poi_center("village") # safe, so he approaches but cannot engage
	g.nemesis["grudge"] = 90.0
	var d0: float = (g.nemesis["pos"] as Vector2).distance_to(g.p["pos"])
	for i in 60:
		g._update_nemesis(1.0)
	assert_true((g.nemesis["pos"] as Vector2).distance_to(g.p["pos"]) < d0, "closing in")
	g.free()

func test_defeat_rewards_and_return() -> void:
	var g = _with_nemesis()
	g.nemesis_present = true
	var stones: int = g.p["stones"]
	var gu: int = g.p["gu"].size()
	var power: float = g.nemesis["power"]
	g.nemesis_defeated()
	assert_false(g.nemesis["alive"])
	assert_true(g.p["stones"] > stones)
	assert_eq(g.count("demon_core"), 1)
	assert_eq(g.p["gu"].size(), gu + 1, "drops one of his Gu")
	g.advance_time(Nemesis.RESPAWN_DAYS + 1.0)
	assert_true(g.nemesis["alive"], "returns")
	assert_true(g.nemesis["power"] > power * 1.2, "stronger")
	assert_true(Nemesis.phase(g.nemesis) == "threat", "and wants vengeance")
	g.free()

func test_escape_makes_him_angrier() -> void:
	var g = _with_nemesis()
	g.nemesis_present = true
	var grudge: float = g.nemesis["grudge"]
	g.nemesis_escaped(Vector2(100, 100))
	assert_false(g.nemesis_present)
	assert_true(g.nemesis["alive"])
	assert_near(g.nemesis["grudge"], grudge + 15.0)
	assert_true(g.nemesis["cooldown_until"] > g.time)
	g.free()

func test_falling_to_him_is_a_normal_death_but_cools_him() -> void:
	var g = _with_nemesis()
	g.nemesis_present = true
	g.nemesis["grudge"] = 80.0
	g.die("test")
	assert_false(g.nemesis_present)
	assert_near(g.nemesis["grudge"], 65.0)
	g.free()

func test_rival_burns_fields() -> void:
	var g = _with_nemesis()
	g.nemesis["grudge"] = 60.0
	g.add_item("herb", 2)
	g.plant(g.plots[0]["id"], "herb")
	g.plant(g.plots[1]["id"], "herb")
	var burned := false
	for i in 30:
		g.nemesis["grudge"] = 60.0
		g._nemesis_new_day()
		if g.plots[0]["crop"] == "" or g.plots[1]["crop"] == "":
			burned = true
			break
	assert_true(burned, "35% per dawn: almost certain within 30 dawns")
	g.free()

func test_nemesis_survives_save_load() -> void:
	var g = _with_nemesis()
	g.nemesis["grudge"] = 55.0
	g.nemesis["pos"] = Vector2(1234, 2345)
	g.save_game()
	var h = load("res://game/game.gd").new()
	h.save_path = g.save_path
	assert_true(h.load_game())
	assert_eq(h.nemesis["name"], g.nemesis["name"])
	assert_near(h.nemesis["grudge"], 55.0)
	assert_eq(h.nemesis["pos"], Vector2(1234, 2345))
	assert_eq(typeof(h.nemesis["rank"]), TYPE_INT)
	g.free(); h.free()
