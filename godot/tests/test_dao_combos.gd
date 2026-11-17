extends "res://tests/test_case.gd"
## Dao combos and status effects.

func _gu(list: Array) -> Array:
	var out: Array = []
	for i in list.size():
		out.append({"uid": i + 1, "def": list[i], "unfed": 0})
	return out

func _line(n: int) -> Array:
	var placed: Array = []
	for i in n:
		placed.append({"uid": i + 1, "x": i, "y": 0, "rot": 0})
	return placed

func test_two_pairs_awaken_combo() -> void:
	var gu := _gu(["moonlight", "moonlight", "moonlight"])
	var two := Aperture.compute_build(1, _line(2), gu)
	assert_eq(two["combos"].size(), 0, "one pair is only resonance")
	var three := Aperture.compute_build(1, _line(3), gu)
	assert_eq(three["path_pairs"].get("moon", 0), 2)
	assert_eq(three["combos"].size(), 1)
	assert_eq(three["combos"][0]["name"], "Moonlit Edge")
	for a in three["attacks"]:
		assert_eq(a.get("pierce", 0), 1, "moon attacks pierce one more foe")
		assert_near(a.get("burn", 0.0), 0.2)

func test_global_combo_stats() -> void:
	var gu := _gu(["stone_skin", "jade_bone", "jade_bone"])
	# stone_skin is 1x2 vertical at (0,0); jade bones at (1,0) and (1,1) touch it and each other
	var placed := [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 1, "y": 0, "rot": 0}, {"uid": 3, "x": 1, "y": 1, "rot": 0}]
	var b := Aperture.compute_build(1, placed, gu)
	assert_eq(b["combos"].size(), 1, "earth combo")
	assert_near(b["stats"]["damage_taken"], -0.2)

func test_lightning_combo_adds_chain_jump() -> void:
	var gu := _gu(["thunder_bead", "thunder_bead", "thunder_bead"])
	# thunder_bead cells (0,0),(1,0),(1,1): stack three diagonally so each touches the next
	var placed := [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 2, "y": 0, "rot": 0}, {"uid": 3, "x": 2, "y": 2, "rot": 0}]
	var b := Aperture.compute_build(2, placed, gu)
	assert_true(b["path_pairs"].get("lightning", 0) >= 2, "pairs: %s" % b["path_pairs"])
	assert_eq(b["attacks"][0]["count"], 4)
	assert_near(b["attacks"][0]["stun"], 0.3)

func test_range_mult_applies() -> void:
	var gu := _gu(["moonlight"])
	var b := Aperture.compute_build(1, _line(1), gu)
	assert_near(b["attacks"][0]["range"], 240.0)

func test_every_path_has_a_combo() -> void:
	for path in GuDB.PATH_COLORS:
		assert_true(GuDB.DAO_COMBOS.has(path), "combo for %s" % path)

func test_enemy_burn_and_vulnerable() -> void:
	var e = load("res://actors/enemy.gd").new()
	e.setup("wolf", Vector2.ZERO, 0)
	var start: float = e.hp
	e.apply_vulnerable(0.2)
	var dealt: float = e.take_damage(10.0)
	assert_near(dealt, 12.0)
	e.apply_burn(6.0)
	assert_near(e.burn_dps * e.burn_t, 6.0, 0.01)
	assert_near(e.hp, start - 12.0)
	e.free()
