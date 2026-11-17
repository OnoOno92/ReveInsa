class_name Sightings
extends RefCounted
## Wild Gu sightings: rumours of a Gu at a spot in the world, matched to the terrain.
## Stand in the ring to channel a capture. Idea carried over from Martial Improved (gu_hunting.js).
## Pure helpers; the live list lives in Game.sightings:
##   {id, def, pos: Vector2, until: float (days), progress: float (s), need: float (s)}

const MAX_ACTIVE := 3
const RADIUS := 72.0
const LIFETIME_DAYS := Vector2(0.3, 0.45)    # ~1.5-2.25 real minutes
const SPAWN_SECONDS := Vector2(25.0, 45.0)
const DISTANCE_TILES := Vector2(14.0, 45.0)

## Habitat pools: [gu id, weight]. Ranks above the player's + 1 are filtered out.
const HABITATS := {
	"grass": [["moonlight", 3], ["jade_bone", 2], ["wind_blade", 2], ["earth_ear", 1], ["gust", 1]],
	"forest": [["vitality_leaf", 3], ["liquor_worm", 2], ["spider_silk", 2], ["wolf_slave", 1], ["wood_thorn", 1]],
	"water": [["water_arrow", 3], ["water_shield", 2], ["essence_spring", 1]],
	"mountain": [["stone_skin", 3], ["bronze_skin", 2], ["black_boar", 2], ["jade_skin", 1]],
	"swamp": [["spider_silk", 2], ["essence_spring", 1], ["vitality_leaf", 1], ["thunder_bead", 1]],
	"ruins": [["spark", 2], ["stone_skin", 2], ["bronze_skin", 1], ["liquor_worm", 1], ["four_flavors", 1]],
	"mire": [["wolf_slave", 2], ["black_boar", 2], ["thunder_bead", 2], ["fire_ember", 1], ["bear_strength", 1]],
	"road": [["spark", 2], ["moonlight", 1], ["jade_bone", 1]],
}
const HABITAT_TEXT := {
	"grass": "in the grasslands", "forest": "deep in the forest", "water": "near water",
	"mountain": "at the foot of the mountains", "swamp": "in the swamp", "ruins": "among the ruins",
	"mire": "inside the Myriad Beast Mire", "road": "beside the road",
}


## Which habitat a tile belongs to.
static func habitat(world: WorldData, pos: Vector2) -> String:
	var t := WorldData.to_tile(pos)
	var tile := world.tile_at(t)
	if world.zone_at(pos) == "forbidden":
		return "mire"
	if _near(world, t, [WorldData.T.WATER, WorldData.T.DEEP_WATER], 2):
		return "water"
	if _near(world, t, [WorldData.T.MOUNTAIN], 2):
		return "mountain"
	match tile:
		WorldData.T.FOREST: return "forest"
		WorldData.T.SWAMP: return "swamp"
		WorldData.T.RUIN: return "ruins"
		WorldData.T.ROAD: return "road"
		WorldData.T.SAND: return "water"
	return "grass"


static func _near(world: WorldData, t: Vector2i, types: Array, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if world.tile_at(t + Vector2i(dx, dy)) in types:
				return true
	return false


## Pick a Gu for a habitat. Moon Gu prefer the night.
static func pick(rng: RandomNumberGenerator, hab: String, night: bool, player_rank: int) -> String:
	var pool: Array = []
	for e in HABITATS.get(hab, HABITATS["grass"]):
		if GuDB.GU[e[0]]["rank"] <= player_rank + 1:
			pool.append([e[0], float(e[1])])
	if night:
		pool.append(["moonlight", 3.0])
		if player_rank >= 1:
			pool.append(["moon_glow", 0.6])
	if pool.is_empty():
		return "moonlight"
	var total := 0.0
	for e in pool:
		total += e[1]
	var roll := rng.randf() * total
	for e in pool:
		roll -= e[1]
		if roll <= 0.0:
			return e[0]
	return pool[-1][0]


## Seconds of channelling needed. Higher-rank Gu resist longer; outranking them helps.
static func capture_time(def_id: String, player_rank: int) -> float:
	var r: int = GuDB.GU[def_id]["rank"]
	return maxf(3.0, 4.0 + 2.0 * r - maxf(0.0, player_rank - r))


## Chance the Gu is bound when the channel completes (otherwise it escapes).
static func capture_chance(def_id: String, player_rank: int, aptitude: float) -> float:
	var r: int = GuDB.GU[def_id]["rank"]
	return clampf(0.6 + 0.12 * (player_rank - r) + (aptitude - 0.5) * 0.5, 0.25, 0.95)


static func direction_text(from: Vector2, to: Vector2) -> String:
	var v := to - from
	var dirs := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var i := posmod(roundi(v.angle() / (PI / 4.0)), 8)
	return "to the %s (~%d steps)" % [dirs[i], roundi(v.length() / WorldData.TILE)]
