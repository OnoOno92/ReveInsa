class_name TilesetBuilder
extends RefCounted
## Builds the terrain TileSet in code: a procedurally painted atlas (one row per tile
## type, VARIANTS columns) plus collision polygons for solid tiles.
## To use real art later: replace the atlas texture with a PNG of the same layout.

const VARIANTS := 4
const S := WorldData.TILE


static func build(world_seed: int) -> TileSet:
	var img := Image.create(S * VARIANTS, S * WorldData.TILE_COUNT, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 77
	for t in WorldData.TILE_COUNT:
		for v in VARIANTS:
			_paint(img, t, Vector2i(v * S, t * S), rng)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(S, S)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(S, S)
	ts.add_source(src, 0)
	var h := S / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for t in WorldData.TILE_COUNT:
		for v in VARIANTS:
			var c := Vector2i(v, t)
			src.create_tile(c)
			if WorldData.SOLID.has(t):
				var td := src.get_tile_data(c, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, square)
	return ts


static func _paint(img: Image, t: int, o: Vector2i, rng: RandomNumberGenerator) -> void:
	var base := Color.html(WorldData.TILE_COLORS[t])
	base = base.lightened(rng.randf_range(-0.03, 0.03)) if rng.randf() < 0.5 else base.darkened(rng.randf_range(0.0, 0.04))
	img.fill_rect(Rect2i(o, Vector2i(S, S)), base)
	var T := WorldData.T
	match t:
		T.GRASS, T.FOREST:
			for i in 7:
				var p := o + Vector2i(rng.randi_range(1, S - 3), rng.randi_range(1, S - 6))
				img.fill_rect(Rect2i(p, Vector2i(2, 4)), base.lightened(0.12))
			for i in 3:
				img.set_pixelv(o + Vector2i(rng.randi_range(0, S - 1), rng.randi_range(0, S - 1)), base.darkened(0.15))
		T.WATER, T.DEEP_WATER:
			for i in 2:
				var p := o + Vector2i(rng.randi_range(2, S - 12), rng.randi_range(4, S - 4))
				img.fill_rect(Rect2i(p, Vector2i(rng.randi_range(5, 10), 1)), base.lightened(0.18))
		T.SAND:
			for i in 10:
				img.set_pixelv(o + Vector2i(rng.randi_range(0, S - 1), rng.randi_range(0, S - 1)), base.darkened(0.12))
		T.MOUNTAIN:
			var peak := rng.randi_range(3, 10)
			_triangle(img, o + Vector2i(2, S - 1), o + Vector2i(S / 2, peak), o + Vector2i(S - 2, S - 1), base.darkened(0.25))
			_triangle(img, o + Vector2i(S / 2 - 5, peak + 7), o + Vector2i(S / 2, peak), o + Vector2i(S / 2 + 5, peak + 7), base.lightened(0.35))
		T.SWAMP:
			_ellipse(img, o + Vector2i(S / 2, S / 2), Vector2i(rng.randi_range(6, 11), rng.randi_range(3, 6)), base.darkened(0.3))
		T.WALL:
			for y in S:
				for x in S:
					var k := float(x + y) / (2.0 * S)
					img.set_pixelv(o + Vector2i(x, y), base.lerp(Color(0.85, 0.82, 1.0), 0.35 * (1.0 - k)))
			var sx := rng.randi_range(2, S - 4)
			img.fill_rect(Rect2i(o + Vector2i(sx, 0), Vector2i(2, S)), Color(1, 1, 1, 0.5).blend(base))
		T.ROAD:
			for i in 6:
				img.fill_rect(Rect2i(o + Vector2i(rng.randi_range(0, S - 4), rng.randi_range(0, S - 3)), Vector2i(3, 2)), base.darkened(0.1))
		T.FLOOR:
			_outline(img, o, base.darkened(0.12))
		T.RUIN:
			_outline(img, o, base.darkened(0.2))
			var x0 := rng.randi_range(4, S - 4)
			for y in S:
				img.set_pixelv(o + Vector2i(clampi(x0 + int(sin(y * 0.4) * 3.0), 0, S - 1), y), base.darkened(0.3))
		T.CORRUPT:
			if rng.randf() < 0.6:
				_ellipse(img, o + Vector2i(rng.randi_range(8, S - 8), rng.randi_range(8, S - 8)), Vector2i(5, 5), Color(0.55, 0.25, 0.55))
		T.CITY_WALL:
			img.fill_rect(Rect2i(o + Vector2i(1, 1), Vector2i(14, 14)), Color.html("#6e6862"))
			img.fill_rect(Rect2i(o + Vector2i(17, 17), Vector2i(14, 14)), Color.html("#6e6862"))
			img.fill_rect(Rect2i(o + Vector2i(17, 1), Vector2i(14, 14)), Color.html("#4b4743"))
			img.fill_rect(Rect2i(o + Vector2i(1, 17), Vector2i(14, 14)), Color.html("#4b4743"))
		T.HOUSE:
			img.fill_rect(Rect2i(o + Vector2i(0, 20), Vector2i(S, 12)), Color.html("#6e2a20"))
			for y in range(2, 18, 5):
				img.fill_rect(Rect2i(o + Vector2i(0, y), Vector2i(S, 1)), base.lightened(0.15))


static func _outline(img: Image, o: Vector2i, c: Color) -> void:
	img.fill_rect(Rect2i(o, Vector2i(S, 1)), c)
	img.fill_rect(Rect2i(o, Vector2i(1, S)), c)


static func _ellipse(img: Image, c: Vector2i, r: Vector2i, col: Color) -> void:
	for y in range(-r.y, r.y + 1):
		for x in range(-r.x, r.x + 1):
			if float(x * x) / (r.x * r.x) + float(y * y) / (r.y * r.y) <= 1.0:
				img.set_pixelv(c + Vector2i(x, y), col)


static func _triangle(img: Image, a: Vector2i, b: Vector2i, c: Vector2i, col: Color) -> void:
	var mn := Vector2i(mini(a.x, mini(b.x, c.x)), mini(a.y, mini(b.y, c.y)))
	var mx := Vector2i(maxi(a.x, maxi(b.x, c.x)), maxi(a.y, maxi(b.y, c.y)))
	for y in range(mn.y, mx.y + 1):
		for x in range(mn.x, mx.x + 1):
			var p := Vector2(x, y)
			if Geometry2D.point_is_inside_triangle(p, Vector2(a), Vector2(b), Vector2(c)):
				img.set_pixel(x, y, col)
