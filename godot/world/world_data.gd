class_name WorldData
extends RefCounted
## Procedural Southern Border. Pure data (no nodes) so it can be tested and saved by seed.

const TILE := 32
const W := 220
const H := 220

enum T { DEEP_WATER, WATER, SAND, GRASS, FOREST, MOUNTAIN, SWAMP, WALL, ROAD, FLOOR, RUIN, CORRUPT, CITY_WALL, HOUSE }
const TILE_COUNT := 14
const SOLID := [T.DEEP_WATER, T.MOUNTAIN, T.WALL, T.CITY_WALL, T.HOUSE]
const TILE_COLORS := ["#1d4e6e", "#2f7aa0", "#d8c98f", "#5f8f3e", "#3f6b2f", "#6b6259", "#4a5a34",
	"#8a7cc9", "#b59a6a", "#9c9283", "#7b7468", "#4a3448", "#5a5550", "#8c3b2e"]

enum Z { VILLAGE, CITY, WILD, DEEP, RUINS, FORBIDDEN, WALL }
const ZONE_IDS := ["village", "city", "wild", "deep", "ruins", "forbidden", "wall"]

const POIS := [
	{"id": "village", "name": "Shi Lan Village", "zone": Z.VILLAGE, "tx": 110, "ty": 172, "r": 9,
		"desc": "A small righteous-path clan village. Safe haven, merchant and clan elder."},
	{"id": "city", "name": "Shang Clan City", "zone": Z.CITY, "tx": 168, "ty": 46, "r": 13,
		"desc": "The great trading city of the Shang clan. Rare Gu are sold here."},
	{"id": "ruins", "name": "Nameless Inheritance Ruins", "zone": Z.RUINS, "tx": 46, "ty": 58, "r": 11,
		"desc": "Remains of a long-dead Gu Master. Demonic cultivators prowl here."},
	{"id": "forbidden", "name": "Myriad Beast Mire", "zone": Z.FORBIDDEN, "tx": 42, "ty": 168, "r": 24,
		"desc": "A forbidden area. A Beast King rules the mire."},
]

const NODE_INFO := {
	"tree": {"name": "Tree", "hp": 3, "regrow": 2.0, "verb": "Chop"},
	"rock": {"name": "Rock", "hp": 3, "regrow": 3.0, "verb": "Mine"},
	"bush": {"name": "Berry Bush", "hp": 1, "regrow": 1.0, "verb": "Pick"},
	"orchid": {"name": "Moon Orchid", "hp": 1, "regrow": 2.0, "verb": "Pick"},
	"jade": {"name": "Jade Vein", "hp": 4, "regrow": 4.0, "verb": "Mine"},
	"chest": {"name": "Inheritance Altar", "hp": 1, "regrow": 99999.0, "verb": "Inherit"},
}

var seed_value: int
var tiles := PackedByteArray()
var zones := PackedByteArray()
var danger := PackedFloat32Array()
var explored := PackedByteArray()
## {id, type, pos: Vector2, hp, regrow_day}
var nodes: Array = []
## {id, name, role, shop, poi, pos: Vector2, dest}
var npcs: Array = []
## {pos: Vector2, text}
var signs: Array = []


func _init(world_seed: int) -> void:
	seed_value = world_seed
	tiles.resize(W * H)
	zones.resize(W * H)
	danger.resize(W * H)
	explored.resize(W * H)
	_generate()


# ------------------------------------------------------------------ queries
static func idx(t: Vector2i) -> int:
	return t.y * W + t.x

static func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H

static func to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))

static func tile_center(t: Vector2i) -> Vector2:
	return Vector2((t.x + 0.5) * TILE, (t.y + 0.5) * TILE)

func tile_at(t: Vector2i) -> int:
	return tiles[idx(t)] if in_bounds(t) else T.WALL

func tile_at_pos(p: Vector2) -> int:
	return tile_at(to_tile(p))

func is_solid_pos(p: Vector2) -> bool:
	return SOLID.has(tile_at_pos(p))

func zone_at(p: Vector2) -> String:
	var t := to_tile(p)
	return ZONE_IDS[zones[idx(t)]] if in_bounds(t) else "wall"

func danger_at(p: Vector2) -> float:
	var t := to_tile(p)
	return danger[idx(t)] if in_bounds(t) else 1.0

func is_safe(p: Vector2) -> bool:
	var z := zone_at(p)
	return z == "village" or z == "city"

static func poi(id: String) -> Dictionary:
	for p in POIS:
		if p["id"] == id:
			return p
	return {}

static func poi_center(id: String) -> Vector2:
	var p := poi(id)
	return tile_center(Vector2i(p["tx"], p["ty"]))

func wall_name(p: Vector2) -> String:
	var tx := p.x / TILE
	var ty := p.y / TILE
	if ty <= tx and ty <= W - tx:
		return "Regional Wall - beyond lies the Central Continent"
	if tx <= W - tx:
		return "Regional Wall - beyond lies the Western Desert"
	return "Regional Wall - beyond lies the Eastern Sea"

func nodes_near(p: Vector2, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	var b0 := Vector2i(floori((p.x - radius) / TILE / 8.0), floori((p.y - radius) / TILE / 8.0))
	var b1 := Vector2i(floori((p.x + radius) / TILE / 8.0), floori((p.y + radius) / TILE / 8.0))
	for by in range(b0.y, b1.y + 1):
		for bx in range(b0.x, b1.x + 1):
			for n in _buckets.get(by * 1000 + bx, []):
				if (n["pos"] as Vector2).distance_squared_to(p) <= r2:
					out.append(n)
	return out

func reveal(p: Vector2, radius_tiles: float) -> void:
	var c := to_tile(p)
	var r := ceili(radius_tiles)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > radius_tiles * radius_tiles:
				continue
			var t := c + Vector2i(dx, dy)
			if in_bounds(t):
				explored[idx(t)] = 1

## Deterministic per-tile hash in [0,1)
static func hash2(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 982451653) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffffff) / 16777216.0


# ------------------------------------------------------------------ generation
var _buckets := {}

func _put(t: Vector2i, v: int) -> void:
	if in_bounds(t):
		tiles[idx(t)] = v

func _noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n

static func _n01(n: FastNoiseLite, x: float, y: float) -> float:
	return clampf(n.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)

func _generate() -> void:
	var elev := _noise(seed_value, 1.0 / 38.0, 5)
	var moist := _noise(seed_value + 101, 1.0 / 30.0, 4)
	var detail := _noise(seed_value + 202, 0.2, 1)
	var vil := poi("village")

	# 1. Base terrain
	for ty in H:
		for tx in W:
			var e := _n01(elev, tx, ty)
			var m := _n01(moist, tx + 50, ty + 50)
			e -= maxf(0.0, (ty - (H - 14)) / 14.0) * 0.6 # south coast falls into the sea
			# Settlements and ruins sit on solid ground: lift the land around them.
			for lift_id in ["village", "city", "ruins"]:
				var lp := poi(lift_id)
				var ld := Vector2(tx - lp["tx"], ty - lp["ty"]).length()
				if ld < 30.0:
					var k := 1.0 - ld / 30.0
					e = maxf(e, 0.43 + 0.04 * k) if ld < 18.0 else e + 0.05 * k * k
			var t := T.GRASS
			# Thresholds tuned to FastNoiseLite's value-fbm distribution (roughly 0.36..0.60)
			if e < 0.38: t = T.DEEP_WATER
			elif e < 0.40: t = T.WATER
			elif e < 0.41: t = T.SAND
			elif e > 0.565: t = T.MOUNTAIN
			elif m > 0.58 and e < 0.47: t = T.SWAMP
			elif m > 0.52: t = T.FOREST
			tiles[ty * W + tx] = t

	# 2. Regional walls: north (Central Continent), west (Western Desert), east (Eastern Sea); sea to the south
	for ty in H:
		for tx in W:
			var wob := floori(_n01(detail, tx, ty) * 2.0)
			if ty < 3 + wob or tx < 3 + wob or tx >= W - 3 - wob:
				tiles[ty * W + tx] = T.WALL
			if ty >= H - 3:
				tiles[ty * W + tx] = T.DEEP_WATER

	# 3. Points of interest
	for p in POIS:
		var r: int = p["r"]
		for dy in range(-r - 3, r + 4):
			for dx in range(-r - 3, r + 4):
				var t := Vector2i(p["tx"] + dx, p["ty"] + dy)
				if not in_bounds(t) or tile_at(t) == T.WALL:
					continue
				var d := sqrt(float(dx * dx + dy * dy))
				var edge: float = r + (_n01(detail, t.x * 1.5, t.y * 1.5) - 0.5) * (8.0 if p["id"] == "forbidden" else 2.0)
				if d > edge:
					continue
				match p["id"]:
					"village": _put(t, T.FLOOR if d < r - 3 else T.GRASS)
					"city": _put(t, T.FLOOR)
					"ruins": _put(t, T.RUIN if hash2(t.x, t.y, 7) < 0.6 else T.GRASS)
					"forbidden":
						var cur := tile_at(t)
						if cur == T.DEEP_WATER or cur == T.WATER:
							_put(t, T.SWAMP)
						elif cur != T.MOUNTAIN or d < r - 6:
							_put(t, T.SWAMP if hash2(t.x, t.y, 9) < 0.35 else T.CORRUPT)

	# City wall ring with 4 gates
	var city := poi("city")
	var a := 0.0
	while a < TAU:
		var t := Vector2i(roundi(city["tx"] + cos(a) * city["r"]), roundi(city["ty"] + sin(a) * city["r"]))
		if absi(t.x - city["tx"]) > 1 and absi(t.y - city["ty"]) > 1:
			_put(t, T.CITY_WALL)
		a += 0.01

	# 4. Roads
	var ruins := poi("ruins")
	var forb := poi("forbidden")
	_road(Vector2i(vil["tx"], vil["ty"]), Vector2i(city["tx"], city["ty"]), 2)
	_road(Vector2i(vil["tx"], vil["ty"]), Vector2i(ruins["tx"], ruins["ty"]), 1)
	_road(Vector2i(city["tx"], city["ty"]), Vector2i(ruins["tx"], ruins["ty"]), 1)
	_road(Vector2i(vil["tx"], vil["ty"]), Vector2i(forb["tx"] + 18, forb["ty"]), 1)

	# 5. Houses
	_houses(vil, [Vector2i(-6, -5), Vector2i(3, -5), Vector2i(-6, 3), Vector2i(4, 3)])
	_houses(city, [Vector2i(-9, -7), Vector2i(-3, -8), Vector2i(4, -7), Vector2i(-9, 5), Vector2i(5, 5), Vector2i(-3, 7), Vector2i(7, -2), Vector2i(-10, -1)])

	# 6. Zones + danger
	for ty in H:
		for tx in W:
			var i := ty * W + tx
			var dv := Vector2(tx - vil["tx"], ty - vil["ty"]).length()
			danger[i] = minf(1.0, dv / 150.0)
			var z := Z.DEEP if danger[i] > 0.62 else Z.WILD
			if tiles[i] == T.WALL:
				z = Z.WALL
			for p in POIS:
				var d := Vector2(tx - p["tx"], ty - p["ty"]).length()
				var pr: float = p["r"] + (2 if p["id"] == "forbidden" else 0)
				if d <= pr:
					z = p["zone"]
					if p["id"] == "forbidden":
						danger[i] = 1.0
			zones[i] = z

	# 7. NPCs
	_npc("v_elder", "Clan Elder Shi", "elder", "", vil, Vector2i(-2, -1))
	_npc("v_merchant", "Merchant Lan", "merchant", "village", vil, Vector2i(2, -1))
	_npc("v_caravan", "Caravan Master", "caravan", "", vil, Vector2i(0, 3), "city")
	_npc("c_elder", "Cultivation Chamber", "elder", "", city, Vector2i(-3, 0))
	_npc("c_merchant", "Shang Clan Steward", "merchant", "city", city, Vector2i(3, 0))
	_npc("c_caravan", "Shang Caravan", "caravan", "", city, Vector2i(0, 4), "village")

	# 8. Resource nodes
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 999
	var nid := 1
	for ty in range(4, H - 4):
		for tx in range(4, W - 4):
			var t := Vector2i(tx, ty)
			var tt := tile_at(t)
			var z := zones[idx(t)]
			if z == Z.VILLAGE or z == Z.CITY:
				continue
			var v := rng.randf()
			var near_mtn := _is_near(t, T.MOUNTAIN, 2)
			var near_water := _is_near(t, T.WATER, 2)
			var type := ""
			match tt:
				T.FOREST:
					type = "tree" if v < 0.2 else ("bush" if v < 0.235 else "")
				T.GRASS:
					if v < 0.03: type = "tree"
					elif v < 0.05: type = "bush"
					elif v < (0.12 if near_mtn else 0.06): type = "rock"
					elif near_water and v < 0.085: type = "orchid"
				T.SAND:
					type = "rock" if v < 0.03 else ""
				T.SWAMP:
					type = "orchid" if v < 0.04 else ("bush" if v < 0.07 else "")
				T.CORRUPT:
					if v < 0.04: type = "orchid"
					elif v < 0.06: type = "jade"
					elif v < 0.1: type = "tree"
				T.RUIN:
					type = "rock" if v < 0.05 else ("jade" if v < 0.065 else "")
			if type == "rock" and near_mtn and rng.randf() < 0.08:
				type = "jade"
			if type == "":
				continue
			var pos := Vector2((tx + 0.2 + rng.randf() * 0.6) * TILE, (ty + 0.2 + rng.randf() * 0.6) * TILE)
			_add_node({"id": nid, "type": type, "pos": pos, "hp": NODE_INFO[type]["hp"], "regrow_day": 0.0})
			nid += 1
	# Inheritance altar at the ruins
	_clear_around(Vector2i(ruins["tx"], ruins["ty"]), T.RUIN)
	_add_node({"id": 900000, "type": "chest", "pos": poi_center("ruins"), "hp": 1, "regrow_day": 0.0})

	# 9. Signs
	var vc := poi_center("village")
	signs.append({"pos": vc + Vector2(5, -9) * TILE, "text": "North: Shang Clan City"})
	signs.append({"pos": vc + Vector2(-7, -4) * TILE, "text": "West: Myriad Beast Mire - FORBIDDEN"})


func _npc(id: String, npc_name: String, role: String, shop: String, p: Dictionary, off: Vector2i, dest := "") -> void:
	var t := Vector2i(p["tx"], p["ty"]) + off
	_clear_around(t, T.FLOOR)
	npcs.append({"id": id, "name": npc_name, "role": role, "shop": shop, "poi": p["id"], "pos": tile_center(t), "dest": dest})

func _houses(p: Dictionary, spots: Array) -> void:
	for s in spots:
		for y in 2:
			for x in 3:
				_put(Vector2i(p["tx"], p["ty"]) + s + Vector2i(x, y), T.HOUSE)

func _clear_around(t: Vector2i, v: int) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_put(t + Vector2i(dx, dy), v)

func _is_near(t: Vector2i, type: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if tile_at(t + Vector2i(dx, dy)) == type:
				return true
	return false

func _road(from: Vector2i, to: Vector2i, width: int) -> void:
	var n := _noise(seed_value + from.x * 7 + to.y, 4.0, 3)
	var dir := Vector2(to - from)
	var normal := Vector2(-dir.y, dir.x).normalized()
	var steps := ceili(dir.length() * 2.0)
	for i in steps + 1:
		var t := float(i) / steps
		var off := (_n01(n, t, 0.5) - 0.5) * 22.0 * sin(PI * t)
		var c := Vector2(from) + dir * t + normal * off
		var ct := Vector2i(roundi(c.x), roundi(c.y))
		for dy in range(-width + 1, width):
			for dx in range(-width + 1, width):
				var tt := ct + Vector2i(dx, dy)
				var cur := tile_at(tt)
				if cur in [T.WALL, T.CITY_WALL, T.HOUSE, T.FLOOR]:
					continue
				_put(tt, T.ROAD)

func _add_node(n: Dictionary) -> void:
	nodes.append(n)
	var p: Vector2 = n["pos"]
	var k := floori(p.y / TILE / 8.0) * 1000 + floori(p.x / TILE / 8.0)
	if not _buckets.has(k):
		_buckets[k] = []
	_buckets[k].append(n)
