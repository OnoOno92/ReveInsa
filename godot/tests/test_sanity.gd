extends "res://tests/test_case.gd"

func test_math_works() -> void:
	assert_eq(2 + 2, 4)

func test_main_scene_loads() -> void:
	var s: PackedScene = load("res://scenes/main.tscn")
	assert_true(s != null, "main scene should load")
