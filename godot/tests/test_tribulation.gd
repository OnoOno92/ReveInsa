extends "res://tests/test_case.gd"
## Breakthrough tribulations and qi deviation.

func _ready_game():
	var g = load("res://game/game.gd").new()
	g.save_path = "user://test_save.json"
	g.new_game("Tester", 4242)
	g.p["stones"] = 100000
	while not g.p["trib_ready"]:
		g.cultivate()
	return g

func test_peak_stage_waits_for_tribulation() -> void:
	var g = _ready_game()
	assert_eq(g.p["stage"], 3)
	assert_near(g.p["cultivation"], 100.0)
	var stones: int = g.p["stones"]
	g.cultivate()
	assert_eq(g.p["stones"], stones, "no stones spent while waiting")
	g.free()

func test_requirements() -> void:
	var g = _ready_game()
	g.p["hp"] = 1.0
	assert_ne_str(g.can_start_tribulation(), "", "needs half HP")
	g.p["hp"] = g.max_hp()
	assert_eq(g.can_start_tribulation(), "")
	g.p["deviation_until"] = g.time + 0.5
	assert_ne_str(g.can_start_tribulation(), "", "not while deviating")
	g.free()

func assert_ne_str(a: String, b: String, msg := "") -> void:
	assert_true(a != b, msg)

func test_arena_is_open_wilderness() -> void:
	var g = _ready_game()
	var a: Vector2 = g.tribulation_arena()
	assert_false(g.world.is_safe(a), "Heaven strikes outside the village walls")
	assert_false(g.world.is_solid_pos(a))
	assert_true(a.distance_to(WorldData.poi_center("village")) < 70 * WorldData.TILE, "close to home")
	g.free()

func test_success_ranks_up_with_reward() -> void:
	var g = _ready_game()
	g.p["hp"] = g.max_hp()
	var stones: int = g.p["stones"]
	assert_true(g.start_tribulation())
	assert_true(g.in_tribulation)
	g.end_tribulation(true)
	assert_false(g.in_tribulation)
	assert_eq(g.p["rank"], 2)
	assert_eq(g.p["stage"], 0)
	assert_false(g.p["trib_ready"])
	assert_eq(g.p["stones"], stones + 40 * 2 * 2, "flawless doubles the reward")
	g.free()

func test_hit_breaks_flawless() -> void:
	var g = _ready_game()
	g.p["hp"] = g.max_hp()
	var stones: int = g.p["stones"]
	g.start_tribulation()
	g.note_tribulation_hit()
	g.end_tribulation(true)
	assert_eq(g.p["stones"], stones + 40 * 2)
	g.free()

func test_failure_causes_qi_deviation() -> void:
	var g = _ready_game()
	g.p["hp"] = g.max_hp()
	var ess: float = g.max_essence()
	g.start_tribulation()
	g.end_tribulation(false, "test")
	assert_eq(g.p["rank"], 1)
	assert_near(g.p["cultivation"], 60.0)
	assert_true(g.in_deviation())
	assert_near(g.max_essence(), ess * 0.8, 0.01)
	g.cultivate()
	assert_near(g.p["cultivation"], 60.0 + (20.0 + g.p["aptitude"] * 30.0) * 0.5, 0.01, "half-speed cultivation")
	g.advance_time(1.1)
	assert_false(g.in_deviation(), "settles after a day")
	g.free()

func test_falling_in_tribulation_is_not_death() -> void:
	var g = _ready_game()
	g.p["hp"] = g.max_hp()
	var stones: int = g.p["stones"]
	g.start_tribulation()
	g.hurt_player(99999.0, "test")
	assert_false(g.in_tribulation)
	assert_eq(g.p["stones"], stones, "no death penalty")
	assert_true(g.in_deviation())
	assert_true(g.p["hp"] > 0.0)
	g.free()

func test_dominant_path_and_themes() -> void:
	var g = _ready_game()
	g.p["placed"] = []
	g.p["gu"] = []
	g.add_gu("moonlight", true, "shop")
	g.add_gu("stone_skin", true, "shop") # 2 earth cells beat 1 moon cell
	assert_eq(g.dominant_path(), "earth")
	for path in GuDB.PATH_COLORS:
		assert_true(Game.TRIB_THEMES.has(path), "theme for %s" % path)
	g.free()

func test_ward_pill_exists() -> void:
	assert_true(ItemDB.ITEMS.has("pill_ward"))
	assert_true(ItemDB.recipe("a_ward").size() > 0)
