class_name Nemesis
extends RefCounted
## The player's nemesis: a named demonic Gu Master who grows, roams, holds a grudge,
## ambushes, raids fields, flees when beaten and returns stronger.
## Idea carried over from Martial Improved (nemesis.js). Pure helpers; state lives in Game.nemesis:
##   {name, title, path, rank, power, grudge, pos: Vector2, target: Vector2, last_seen: Vector2,
##    alive, respawn_day, defeats, escapes, cooldown_until, gu: [ids]}

const EMERGE_DAY := 1 # appears at the dawn of Day 2
const ENGAGE_TILES := 22.0
const ROAM_TILES_PER_DAY := 45.0
const HUNT_TILES_PER_DAY := 90.0
const DAILY_GROWTH := 1.06
const RESPAWN_DAYS := 4.0

const SURNAMES := ["Mo", "Xue", "Hei", "Yin", "Gui", "Leng", "Wu", "Qiu", "Ye", "Shen"]
const GIVEN := ["Xuanhe", "Jue", "Wuchang", "Lianfeng", "Canglang", "Youming", "Zhaoye", "Kuxin", "Duanhun", "Moran"]
const TITLES := {
	"moon": "the Pale Moon Fiend", "fire": "the Ash-Robed Demon", "lightning": "the Thunder-Scarred",
	"water": "the Drowned Lord", "earth": "the Grave-Digger", "metal": "the Ten-Blade Butcher",
	"strength": "the Bone-Breaker", "wood": "the Blood-Lotus Demon", "wind": "the Howling Shade",
	"enslavement": "the Beast Tamer", "information": "the Whispering Eye",
}
## The Gu he fights with and may drop, per path.
const ARSENAL := {
	"moon": ["moonlight", "moon_glow"], "fire": ["spark", "fire_ember"], "lightning": ["thunder_bead", "wind_blade"],
	"water": ["water_arrow", "water_shield"], "earth": ["stone_skin", "jade_skin"], "metal": ["bronze_skin", "spark"],
	"strength": ["black_boar", "bear_strength"], "wood": ["wood_thorn", "vitality_leaf"], "wind": ["wind_blade", "gust"],
	"enslavement": ["wolf_slave", "spider_silk"], "information": ["earth_ear", "moonlight"],
}
const PATHS := ["moon", "fire", "lightning", "water", "wood", "wind", "strength", "enslavement"]


static func create(world_seed: int, player_rank: int, home: Vector2) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed * 7 + 13
	var path: String = PATHS[r.randi() % PATHS.size()]
	return {
		"name": "%s %s" % [SURNAMES[r.randi() % SURNAMES.size()], GIVEN[r.randi() % GIVEN.size()]],
		"title": TITLES[path], "path": path,
		"rank": mini(5, player_rank), "power": 1.0, "grudge": 15.0,
		"pos": home, "target": home, "last_seen": home,
		"alive": true, "respawn_day": 0.0, "defeats": 0, "escapes": 0, "cooldown_until": 0.0,
		"gu": ARSENAL[path].duplicate(),
	}


static func full_name(n: Dictionary) -> String:
	return "%s, %s" % [n["name"], n["title"]]


## emerging (watches) | rival (raids fields) | threat (hunts the player)
static func phase(n: Dictionary) -> String:
	if n["grudge"] >= 70.0:
		return "threat"
	if n["grudge"] >= 35.0:
		return "rival"
	return "emerging"


static func add_grudge(n: Dictionary, amount: float) -> void:
	n["grudge"] = clampf(n["grudge"] + amount, 0.0, 100.0)


## Daily growth: stronger every day. He matches your rank, and once he has grown 25%
## stronger he stays one rank above you (max 5).
static func grow(n: Dictionary, player_rank: int) -> void:
	n["power"] *= DAILY_GROWTH
	sync_rank(n, player_rank)


static func sync_rank(n: Dictionary, player_rank: int) -> void:
	n["rank"] = mini(5, player_rank + (1 if n["power"] >= 1.25 else 0))


## Combat numbers for the encounter.
static func combat_stats(n: Dictionary) -> Dictionary:
	var rk: float = n["rank"]
	return {
		"hp": 200.0 * pow(rk, 1.35) * n["power"],
		"dmg_scale": (0.85 + 0.4 * rk) * sqrt(n["power"]),
	}


static func path_color(n: Dictionary) -> Color:
	return GuDB.path_color(n["path"])
