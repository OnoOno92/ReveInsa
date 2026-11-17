extends "res://tests/test_case.gd"
## Wild Gu sightings: habitats, spawning, channelling, interruption, expiry, saving.

func _game():
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	g.p["pos"] = WorldData.poi_center("village") + Vector2(0, -16 * WorldData.TILE) # out in the wilds
	return g

func test_habitat_pools_only_hold_real_gu() -> void:
	for hab in Sightings.HABITATS:
		assert_true(Sightings.HABITAT_TEXT.has(hab), "text for %s" % hab)
		for e in Sightings.HABITATS[hab]:
			assert_true(GuDB.GU.has(e[0]), "%s in %s" % [e[0], hab])

func test_pick_respects_rank_and_habitat() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 300:
		var id := Sightings.pick(r, "mire", false, 1)
		assert_true(GuDB.GU[id]["rank"] <= 2, "rank-1 players only see up to rank 2: %s" % id)
		var w := Sightings.pick(r, "water", false, 3)
		assert_true(w in ["water_arrow", "water_shield", "essence_spring"], "water habitat gave %s" % w)

func test_spawn_places_sighting_in_the_wilds() -> void:
	var g = _game()
	var sg: Dictionary = g.spawn_sighting()
	assert_false(sg.is_empty(), "found a spot")
	assert_false(g.world.is_safe(sg["pos"]))
	assert_false(g.world.is_solid_pos(sg["pos"]))
	assert_true(sg["until"] > g.time)
	g.free()

func test_channel_capture_succeeds_over_time() -> void:
	var g = _game()
	g.p["aptitude"] = 0.99
	g.p["rank"] = 3 # outranks a rank-1 Gu: fast and 95% likely
	var before: int = g.p["gu"].size()
	var sg: Dictionary = g.spawn_sighting("moonlight", g.p["pos"] + Vector2(10, 0))
	assert_eq(g.channelling(), sg)
	var caught := false
	for attempt in 20: # 95% each try: astronomically unlikely to fail 20 times
		if g.sightings.is_empty():
			g.spawn_sighting("moonlight", g.p["pos"] + Vector2(10, 0))
		for i in 40:
			g._update_sightings(0.1)
		if g.p["gu"].size() > before:
			caught = true
			break
	assert_true(caught, "bound the Gu")
	var new_gu: Dictionary = g.p["gu"][-1]
	assert_eq(new_gu["def"], "moonlight")
	assert_true(new_gu.has("pot"), "wild roll applied")
	g.free()

func test_leaving_the_ring_decays_progress() -> void:
	var g = _game()
	var sg: Dictionary = g.spawn_sighting("stone_skin", g.p["pos"] + Vector2(10, 0))
	g._update_sightings(1.0)
	assert_near(sg["progress"], 1.0)
	g.p["pos"] += Vector2(500, 0)
	g._update_sightings(1.0)
	assert_near(sg["progress"], 0.5)

	g.free()

func test_damage_interrupts_channel() -> void:
	var g = _game()
	var sg: Dictionary = g.spawn_sighting("stone_skin", g.p["pos"] + Vector2(10, 0))
	g._update_sightings(2.0)
	g.hurt_player(5.0, "test")
	assert_near(sg["progress"], 1.2)
	g.free()

func test_sightings_expire() -> void:
	var g = _game()
	g.spawn_sighting("moonlight", g.p["pos"] + Vector2(400, 0))
	g.time += 1.0
	g._update_sightings(0.0)
	assert_eq(g.sightings.size(), 0)
	g.free()

func test_capture_odds() -> void:
	assert_true(Sightings.capture_chance("moonlight", 3, 0.9) > Sightings.capture_chance("moonlight", 1, 0.5))
	assert_true(Sightings.capture_chance("bear_strength", 1, 0.4) >= 0.25, "never hopeless")
	assert_true(Sightings.capture_time("thunder_bead", 1) > Sightings.capture_time("moonlight", 1), "higher rank takes longer")

func test_sightings_survive_save_load() -> void:
	var g = _game()
	var sg: Dictionary = g.spawn_sighting("water_arrow", g.p["pos"] + Vector2(300, 0))
	sg["progress"] = 1.5
	g.save_game()
	var h = load("res://game/game.gd").new()
	h.save_path = g.save_path
	assert_true(h.load_game())
	assert_eq(h.sightings.size(), g.sightings.size())
	var back: Dictionary = h.sightings.filter(func(x): return x["def"] == "water_arrow")[0]
	assert_eq(back["pos"], sg["pos"])
	assert_near(back["progress"], 1.5)
	assert_eq(typeof(back["id"]), TYPE_INT)
	g.free(); h.free()

func test_direction_text() -> void:
	assert_eq(Sightings.direction_text(Vector2.ZERO, Vector2(0, -320)), "to the north (~10 steps)")
	assert_eq(Sightings.direction_text(Vector2.ZERO, Vector2(320, 320)), "to the south-east (~14 steps)")
