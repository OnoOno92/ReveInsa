extends "res://tests/test_case.gd"

var _w: WorldData

func _world() -> WorldData:
	if _w == null:
		_w = WorldData.new(12345)
	return _w

func test_deterministic_by_seed() -> void:
	var a := WorldData.new(777)
	var b := WorldData.new(777)
	assert_eq(a.tiles, b.tiles)
	assert_eq(a.nodes.size(), b.nodes.size())

func test_regional_walls_on_three_sides() -> void:
	var w := _world()
	assert_eq(w.tile_at(Vector2i(110, 0)), WorldData.T.WALL, "north wall")
	assert_eq(w.tile_at(Vector2i(0, 110)), WorldData.T.WALL, "west wall")
	assert_eq(w.tile_at(Vector2i(WorldData.W - 1, 110)), WorldData.T.WALL, "east wall")
	assert_eq(w.tile_at(Vector2i(110, WorldData.H - 1)), WorldData.T.DEEP_WATER, "southern sea")

func test_village_is_safe_and_walkable() -> void:
	var w := _world()
	var c := WorldData.poi_center("village")
	assert_eq(w.zone_at(c), "village")
	assert_true(w.is_safe(c))
	assert_false(w.is_solid_pos(c + Vector2(0, 48)), "player spawn must be walkable")

func test_terrain_mix_is_reasonable() -> void:
	var w := _world()
	var counts := {}
	for t in w.tiles:
		counts[t] = counts.get(t, 0) + 1
	var total := float(w.tiles.size())
	var land := 0
	for t in [WorldData.T.GRASS, WorldData.T.FOREST, WorldData.T.SAND, WorldData.T.SWAMP, WorldData.T.ROAD]:
		land += counts.get(t, 0)
	print("    terrain: grass %.0f%% forest %.0f%% water %.0f%% mountain %.0f%% swamp %.0f%%" % [
		100.0 * counts.get(WorldData.T.GRASS, 0) / total, 100.0 * counts.get(WorldData.T.FOREST, 0) / total,
		100.0 * (counts.get(WorldData.T.WATER, 0) + counts.get(WorldData.T.DEEP_WATER, 0)) / total,
		100.0 * counts.get(WorldData.T.MOUNTAIN, 0) / total, 100.0 * counts.get(WorldData.T.SWAMP, 0) / total])
	assert_true(land / total > 0.5, "at least half the map should be walkable land")
	assert_true(counts.get(WorldData.T.MOUNTAIN, 0) > 0, "some mountains")
	assert_true(counts.get(WorldData.T.WATER, 0) + counts.get(WorldData.T.DEEP_WATER, 0) > total * 0.03, "some water")

func test_resource_nodes_and_altar() -> void:
	var w := _world()
	assert_true(w.nodes.size() > 1000, "plenty of resource nodes: %d" % w.nodes.size())
	var near := w.nodes_near(WorldData.poi_center("ruins"), 40.0)
	assert_true(near.any(func(n): return n["type"] == "chest"), "inheritance altar at ruins")

func test_npcs_present() -> void:
	assert_eq(_world().npcs.size(), 6)
