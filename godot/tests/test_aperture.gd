extends "res://tests/test_case.gd"

func _gu(list: Array) -> Array:
	var out: Array = []
	for i in list.size():
		out.append({"uid": i + 1, "def": list[i], "unfed": 0})
	return out

func test_size_grows_with_rank() -> void:
	assert_eq(Aperture.size_for_rank(1), 4)
	assert_eq(Aperture.size_for_rank(5), 8)

func test_rotation_normalizes_to_origin() -> void:
	# black_boar L: (0,0),(0,1),(1,1)
	var r1 := Aperture.shape_cells("black_boar", 1)
	for c in r1:
		assert_true(c.x >= 0 and c.y >= 0, "cells must be non-negative after rotation")
	assert_eq(r1.size(), 3)
	assert_eq(Aperture.shape_cells("black_boar", 4), Aperture.shape_cells("black_boar", 0), "4 rotations = identity")

func test_can_place_bounds_and_overlap() -> void:
	var gu := _gu(["moon_glow", "moonlight"])
	var placed := [{"uid": 1, "x": 0, "y": 0, "rot": 0}]
	assert_false(Aperture.can_place(4, placed, gu, "moonlight", 1, 1, 0), "overlaps 2x2")
	assert_true(Aperture.can_place(4, placed, gu, "moonlight", 2, 0, 0))
	assert_false(Aperture.can_place(4, placed, gu, "moon_glow", 3, 3, 0), "out of bounds")
	assert_true(Aperture.can_place(4, placed, gu, "moon_glow", 0, 0, 0, 1), "ignoring itself it fits")

func test_aura_buffs_adjacent_attack_only() -> void:
	var gu := _gu(["moonlight", "liquor_worm"])
	var near := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 1, "y": 0, "rot": 0}], gu)
	assert_near(near["attacks"][0]["damage"], 13.0)
	assert_near(near["attacks"][0]["cost"], 1.2)
	var far := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 2, "y": 3, "rot": 0}], gu)
	assert_near(far["attacks"][0]["damage"], 10.0)

func test_path_resonance() -> void:
	var gu := _gu(["moonlight", "moonlight"])
	var b := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 0, "y": 1, "rot": 0}], gu)
	assert_near(b["attacks"][0]["damage"], 11.5)

func test_killer_move_requires_connection() -> void:
	var gu := _gu(["black_boar", "stone_skin"])
	var touching := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 1, "y": 0, "rot": 0}], gu)
	assert_eq(touching["killer_moves"].size(), 1)
	assert_eq(touching["stats"]["armor"], 9.0, "4 from stone skin + 5 from killer move")
	var apart := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 3, "y": 0, "rot": 0}], gu)
	assert_eq(apart["killer_moves"].size(), 0)

func test_killer_move_rank_gate() -> void:
	var gu := _gu(["moonlight", "moon_glow", "liquor_worm"])
	var placed := [{"uid": 1, "x": 0, "y": 0, "rot": 0}, {"uid": 2, "x": 1, "y": 0, "rot": 0}, {"uid": 3, "x": 1, "y": 2, "rot": 0}]
	assert_eq(Aperture.compute_build(1, placed, gu)["killer_moves"].size(), 0)
	assert_eq(Aperture.compute_build(2, placed, gu)["killer_moves"].size(), 1)

func test_starving_gu_inactive() -> void:
	var gu := _gu(["moonlight"])
	gu[0]["unfed"] = 9
	var b := Aperture.compute_build(1, [{"uid": 1, "x": 0, "y": 0, "rot": 0}], gu)
	assert_eq(b["attacks"].size(), 0)
	assert_true(b["inactive"].has(1))
