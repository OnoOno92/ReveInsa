extends "res://tests/test_case.gd"
## Unique Gu: potentials, natures, shiny, grades, inheritance.

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_roll_ranges_per_source() -> void:
	var r := _rng(1)
	for i in 200:
		var shop := GuRoll.roll(r, "shop")
		var inh := GuRoll.roll(r, "inherit")
		for k in GuRoll.KEYS:
			assert_true(shop["pot"][k] >= 0 and shop["pot"][k] <= 20, "shop %s=%d" % [k, shop["pot"][k]])
			assert_true(inh["pot"][k] >= 16 and inh["pot"][k] <= 31, "inherit %s=%d" % [k, inh["pot"][k]])
		assert_false(shop["shiny"], "shops never sell shiny Gu")
		assert_true(GuRoll.NATURES.has(shop["nature"]))

func test_shiny_rate_is_rare() -> void:
	var r := _rng(7)
	var n := 0
	for i in 20000:
		if GuRoll.roll(r, "wild")["shiny"]:
			n += 1
	assert_true(n > 15 and n < 80, "about 1/512 of 20000 = 39, got %d" % n)

func test_forced_shiny_boosts_potentials() -> void:
	var r := _rng(3)
	var s := GuRoll.roll(r, "shop", true)
	assert_true(s["shiny"])
	for k in GuRoll.KEYS:
		assert_true(s["pot"][k] >= 8, "shiny adds +8")

func test_power_and_speed_change_the_build() -> void:
	var weak := {"uid": 1, "def": "moonlight", "unfed": 0, "pot": {"power": 0, "speed": 0, "eff": 0, "dur": 0}, "nature": "steady", "shiny": false}
	var strong := {"uid": 1, "def": "moonlight", "unfed": 0, "pot": {"power": 30, "speed": 30, "eff": 30, "dur": 0}, "nature": "steady", "shiny": false}
	var placed := [{"uid": 1, "x": 0, "y": 0, "rot": 0}]
	var a0: Dictionary = Aperture.compute_build(1, placed, [weak])["attacks"][0]
	var a1: Dictionary = Aperture.compute_build(1, placed, [strong])["attacks"][0]
	assert_near(a1["damage"], a0["damage"] * 1.3)
	assert_near(a1["cooldown"], a0["cooldown"] * 0.85)
	assert_near(a1["cost"], a0["cost"] * (1.0 - 30.0 / 125.0))

func test_nature_modifies_traits() -> void:
	var base := {"def": "moonlight", "pot": {"power": 10, "speed": 10, "eff": 10, "dur": 10}, "nature": "steady"}
	var fierce := base.duplicate(true)
	fierce["nature"] = "fierce" # +power -eff
	assert_near(GuRoll.power_mult(fierce), GuRoll.power_mult(base) * 1.1)
	assert_true(GuRoll.cost_mult(fierce) > GuRoll.cost_mult(base), "fierce Gu cost more essence")

func test_durability_extends_feeding_interval() -> void:
	var hardy := {"def": "moonlight", "pot": {"power": 0, "speed": 0, "eff": 0, "dur": 25}, "nature": "hardy", "unfed": 0}
	assert_eq(GuRoll.feed_every(hardy), 3 + 2, "dur>=20 and hardy nature each add a day")
	hardy["unfed"] = 4
	assert_false(Aperture.is_starving(hardy))
	var glutton := {"def": "liquor_worm", "pot": {"power": 0, "speed": 0, "eff": 0, "dur": 0}, "nature": "gluttonous"}
	assert_eq(GuRoll.feed_every(glutton), 1, "never below one day")

func test_grades_and_sell_value() -> void:
	var top := {"def": "moonlight", "pot": {"power": 31, "speed": 31, "eff": 31, "dur": 31}, "nature": "steady", "shiny": false}
	var low := {"def": "moonlight", "pot": {"power": 0, "speed": 0, "eff": 0, "dur": 0}, "nature": "steady", "shiny": false}
	assert_eq(GuRoll.grade(top), "S")
	assert_eq(GuRoll.grade(low), "F")
	assert_true(GuRoll.sell_value(top) > GuRoll.sell_value(low))
	top["shiny"] = true
	assert_eq(GuRoll.sell_value(top), GuRoll.sell_value(low) * 0 + floori(25 * 0.4 * 1.4 * 3.0))

func test_refinement_inherits_soul() -> void:
	var old := {"def": "moonlight", "pot": {"power": 30, "speed": 5, "eff": 10, "dur": 2}, "nature": "keen", "shiny": true}
	var r := GuRoll.inherit(old)
	assert_eq(r["nature"], "keen")
	assert_true(r["shiny"])
	assert_eq(r["pot"]["power"], 31, "capped at 31")
	assert_eq(r["pot"]["speed"], 8)

func test_legacy_gu_gets_neutral_rolls() -> void:
	var g := {"uid": 1, "def": "moonlight", "unfed": 0}
	GuRoll.ensure(g)
	assert_eq(g["nature"], "steady")
	assert_eq(g["pot"]["power"], 12)
	assert_false(g["shiny"])

func test_rolls_survive_save_load() -> void:
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	var made: Dictionary = g.add_gu("spark", false, "wild", GuRoll.roll(_rng(9), "wild", true))
	g.save_game()
	var h = load("res://game/game.gd").new()
	h.save_path = g.save_path
	assert_true(h.load_game())
	var back := Aperture.find_inst(h.p["gu"], made["uid"])
	assert_true(back["shiny"])
	assert_eq(back["nature"], made["nature"])
	assert_eq(back["pot"]["power"], made["pot"]["power"])
	assert_eq(typeof(back["pot"]["power"]), TYPE_INT, "JSON floats normalized to int")
	g.free(); h.free()
