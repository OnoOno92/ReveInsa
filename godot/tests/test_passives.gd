extends "res://tests/test_case.gd"
## Trigger passives and named pairs.

func _gu(list: Array) -> Array:
	var out: Array = []
	for i in list.size():
		out.append({"uid": i + 1, "def": list[i], "unfed": 0})
	return out

func _game_with(gu_ids: Array):
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	g.p["gu"] = []
	g.p["placed"] = []
	g.p["rank"] = 3
	for gid in gu_ids:
		g.add_gu(gid, true, "shop", {"pot": {"power": 0, "speed": 0, "eff": 0, "dur": 0}, "nature": "steady", "shiny": false})
	g.rebuild()
	g.p["hp"] = g.max_hp()
	return g

func test_data_is_valid() -> void:
	for gid in GuDB.PASSIVES:
		assert_true(GuDB.GU.has(gid), "passive for unknown Gu %s" % gid)
		assert_true(GuDB.PASSIVES[gid]["trigger"] in ["opener", "on_kill", "on_hurt", "low_hp"])
	for pr in GuDB.PAIRS:
		for gid in pr["gu"]:
			assert_true(GuDB.GU.has(gid), "%s: %s" % [pr["id"], gid])
		for gid in pr.get("attack", {}):
			assert_true(GuDB.GU[gid].has("attack"), "%s modifies an attack Gu" % pr["id"])

func test_build_lists_active_passives() -> void:
	var gu := _gu(["black_boar", "moonlight"])
	var b := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 3, "y": 3, "rot": 0}], gu)
	assert_eq(b["passives"].size(), 2)
	var moon: Dictionary = b["attacks"].filter(func(a): return a["def"] == "moonlight")[0]
	assert_true(moon.has("opener"), "Moonlight carries its opening-strike passive")

func test_pairs_need_to_touch() -> void:
	var gu := _gu(["stone_skin", "bronze_skin"])
	var touching := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 1, "y": 0, "rot": 0}], gu)
	var apart := Aperture.compute_build(2, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 3, "y": 0, "rot": 0}], gu)
	assert_eq(touching["pairs"].size(), 1)
	assert_near(touching["stats"]["armor"], 4.0 + 7.0 + 3.0)
	assert_eq(apart["pairs"].size(), 0)

func test_pair_modifies_specific_attack() -> void:
	var gu := _gu(["moonlight", "water_arrow"])
	var b := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 1, "y": 0, "rot": 0}], gu)
	for a in b["attacks"]:
		assert_near(a["range"], GuDB.GU[a["def"]]["attack"]["range"] * 1.15, 0.01, a["def"])

func test_heal_cost_pair() -> void:
	var gu := _gu(["vitality_leaf", "essence_spring"])
	var b := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 1, "y": 0, "rot": 0}], gu)
	assert_near(b["heals"][0]["cost"], 4.0 * 0.5)

func test_bloodlust_stacks_and_fades() -> void:
	var g = _game_with(["black_boar"])
	for i in 7:
		g.on_enemy_killed("wolf", false)
	assert_near(g.stat("damage_buff"), 0.05 * 5, 0.0001, "capped at 5 stacks")
	g.clock += 9.0
	g._update_passives()
	assert_near(g.stat("damage_buff"), 0.0, 0.0001, "faded")
	g.free()

func test_on_kill_heal_and_essence() -> void:
	var g = _game_with(["vitality_leaf", "essence_spring"])
	g.p["hp"] = 10.0
	g.p["essence"] = 0.0
	g.on_enemy_killed("wolf", false)
	assert_near(g.p["hp"], 13.0)
	assert_near(g.p["essence"], 2.0)
	g.free()

func test_low_hp_passive() -> void:
	var g = _game_with(["jade_skin"])
	var armor: float = g.stat("armor")
	g.p["hp"] = g.max_hp() * 0.2
	g._update_passives()
	assert_near(g.stat("armor"), armor + 10.0)
	g.p["hp"] = g.max_hp()
	g._update_passives()
	assert_near(g.stat("armor"), armor)
	g.free()

func test_when_hit_passive_fires_burst() -> void:
	var g = _game_with(["spider_silk"])
	var fired := [0]
	g.passive_burst.connect(func(_ps): fired[0] += 1)
	g.hurt_player(5.0, "test")
	assert_eq(fired[0], 1, "100% chance")
	g.hurt_player(5.0, "test")
	assert_eq(fired[0], 1, "4s cooldown")
	g.clock += 5.0
	g.hurt_player(5.0, "test")
	assert_eq(fired[0], 2)
	g.free()

func test_shield_refill_passive() -> void:
	var g = _game_with(["water_shield"])
	var refilled := false
	for i in 60:
		g.shield = 0.0
		g.clock += 2.0
		g.hurt_player(1.0, "test")
		if g.shield > 0.0:
			refilled = true
			break
	assert_true(refilled, "20% per hit: almost certain within 60 hits")
	g.free()
