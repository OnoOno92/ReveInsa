class_name People
extends RefCounted
## The people of the Southern Border: named NPC Gu Masters on ONE shared schema
## (a lesson from Martial Improved, which ended up with two NPC systems).
## Pure helpers; the live list is Game.people, the history is Game.chronicle.
##
## Person: {id, name, affiliation: clan|shang|rogue|demonic, rank, power, path, home: poi id,
##          pos: Vector2, target: Vector2, goal, favor (-100..100), alive, met, gu: [ids], stock: [item ids]}

const COUNT := {"clan": 3, "shang": 2, "rogue": 2, "demonic": 1}
const SPEED_TILES_PER_DAY := 50.0
const MEET_RADIUS := 900.0     # px: becomes a walking actor
const LEAVE_RADIUS := 1300.0   # px: back to the abstract simulation
const CHRONICLE_MAX := 40

const SURNAMES := {
	"clan": ["Shi"], "shang": ["Shang"],
	"rogue": ["Bai", "Liu", "Zhao", "Tie", "Hua", "Lu", "Jiang"],
	"demonic": ["Xue", "Hei", "Gui", "Yin", "Leng"],
}
const GIVEN := ["Yu", "Lan", "Feng", "Hu", "Ling", "Jun", "Mei", "Tao", "Shan", "Qing", "Wei", "Rou", "Bo", "Xin", "An", "Ming"]
const AFFILIATION_NAMES := {"clan": "Shi Lan clan", "shang": "Shang clan merchant", "rogue": "Rogue cultivator", "demonic": "Demonic cultivator"}
const AFFILIATION_COLORS := {"clan": "#7fb3d5", "shang": "#d4a93a", "rogue": "#9be07a", "demonic": "#ff4d6d"}
const HOMES := {"clan": "village", "shang": "city", "rogue": "ruins", "demonic": "forbidden"}
const PATHS := ["moon", "fire", "lightning", "water", "wood", "wind", "strength", "earth"]
## Wandering merchants carry a few rare goods.
const SHANG_STOCK := ["thunder_crystal", "jade_shard", "pill_essence", "pill_vitality", "pill_wind", "moon_orchid", "wine", "bone"]


static func person_name(rng: RandomNumberGenerator, affiliation: String, taken: Dictionary) -> String:
	for attempt in 40:
		var sur: Array = SURNAMES[affiliation]
		var n := "%s %s" % [sur[rng.randi() % sur.size()], GIVEN[rng.randi() % GIVEN.size()]]
		if not taken.has(n):
			return n
	return "%s %d" % [SURNAMES[affiliation][0], rng.randi() % 1000]


static func make(rng: RandomNumberGenerator, id: int, affiliation: String, player_rank: int, taken: Dictionary) -> Dictionary:
	var home := WorldData.poi_center(HOMES[affiliation])
	var path: String = PATHS[rng.randi() % PATHS.size()]
	var pool: Array = Nemesis.ARSENAL.get(path, ["moonlight"])
	var stock: Array = []
	if affiliation == "shang":
		var s := SHANG_STOCK.duplicate()
		s.shuffle()
		stock = s.slice(0, 4)
	return {
		"id": id, "name": person_name(rng, affiliation, taken), "affiliation": affiliation,
		"rank": clampi(player_rank + rng.randi_range(-1, 1), 1, 5), "power": rng.randf_range(0.9, 1.15),
		"path": path, "home": HOMES[affiliation],
		"pos": home + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)) * WorldData.TILE,
		"target": home, "goal": "rest",
		"favor": {"clan": 20, "shang": 5, "rogue": 0, "demonic": -60}[affiliation],
		"alive": true, "met": false, "gu": [pool[rng.randi() % pool.size()]], "stock": stock,
	}


static func generate(rng: RandomNumberGenerator, player_rank: int) -> Array:
	var out: Array = []
	var taken := {}
	var id := 1
	for aff in COUNT:
		for i in COUNT[aff]:
			var pp := make(rng, id, aff, player_rank, taken)
			taken[pp["name"]] = true
			out.append(pp)
			id += 1
	return out


static func is_hostile(pp: Dictionary) -> bool:
	return pp["affiliation"] == "demonic" or pp["favor"] <= -50


## Favor tiers shown in the UI.
static func favor_label(f: float) -> String:
	if f >= 60: return "Sworn friend"
	if f >= 30: return "Friendly"
	if f >= 0: return "Neutral"
	if f > -50: return "Wary"
	return "Hostile"


## Where someone wants to go next, by affiliation and daily goal.
static func pick_goal(rng: RandomNumberGenerator, pp: Dictionary) -> String:
	var roll := rng.randf()
	match pp["affiliation"]:
		"clan": return "rest" if roll < 0.35 else ("gather" if roll < 0.7 else "hunt")
		"shang": return "travel" if roll < 0.6 else "rest"
		"rogue": return "hunt" if roll < 0.5 else ("gather" if roll < 0.8 else "travel")
		"demonic": return "hunt" if roll < 0.7 else "rest"
	return "rest"


static func pick_target(rng: RandomNumberGenerator, world: WorldData, pp: Dictionary) -> Vector2:
	var home := WorldData.poi_center(pp["home"])
	match pp["goal"]:
		"rest":
			return home + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 3)) * WorldData.TILE
		"travel":
			var dests := ["village", "city", "ruins"]
			return WorldData.poi_center(dests[rng.randi() % dests.size()])
	# gather / hunt: somewhere in the wilds around home (hunters go further)
	var reach := 40.0 if pp["goal"] == "hunt" else 22.0
	for attempt in 16:
		var c := home + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, reach) * WorldData.TILE
		if WorldData.in_bounds(WorldData.to_tile(c)) and not world.is_solid_pos(c) and not world.is_safe(c) and world.zone_at(c) != "wall":
			return c
	return home


## Combat numbers when someone duels or attacks the player.
static func combat_stats(pp: Dictionary) -> Dictionary:
	var rk: float = pp["rank"]
	return {"hp": 110.0 * pow(rk, 1.3) * pp["power"], "dmg_scale": (0.7 + 0.3 * rk) * sqrt(pp["power"])}
