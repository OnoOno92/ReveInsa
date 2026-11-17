class_name Quests
extends RefCounted
## Clan missions posted by the village elder. Pure logic.
## Mission: {id, type: hunt|gather|explore, target, count, progress, stones, contrib, title}

const MAX_OFFERED := 3
const MAX_ACTIVE := 3

const HUNT_POOL := [
	# [enemy id, min rank, min count, max count, stones per kill, contribution per kill]
	["wolf", 1, 4, 8, 3, 2],
	["boar", 1, 3, 5, 4, 2],
	["night_wolf", 1, 3, 5, 5, 3],
	["demonic_master", 1, 2, 3, 10, 6],
	["thunder_wolf", 2, 2, 4, 12, 7],
	["poison_toad", 2, 2, 4, 10, 6],
]
const GATHER_POOL := [
	# [item, min rank, count, stones, contribution]
	["wood", 1, 12, 14, 6],
	["herb", 1, 6, 10, 6],
	["berries", 1, 10, 10, 5],
	["moon_orchid", 1, 4, 16, 8],
	["pelt", 1, 3, 16, 8],
	["stone", 1, 10, 12, 5],
	["bone", 1, 3, 14, 8],
	["jade_shard", 2, 2, 30, 14],
	["thunder_crystal", 2, 2, 30, 14],
]
const EXPLORE_POOL := [
	# [poi id, stones, contribution]
	["ruins", 25, 12],
	["forbidden", 35, 18],
	["city", 15, 8],
]

## Clan treasury: things bought with contribution points.
const TREASURY := [
	{"id": "wolf_slave", "kind": "gu", "cost": 25},
	{"id": "essence_spring", "kind": "gu", "cost": 30},
	{"id": "bronze_skin", "kind": "gu", "cost": 30},
	{"id": "four_flavors", "kind": "gu", "cost": 90},
	{"id": "aptitude_pill", "kind": "pill", "cost": 120, "name": "Clan Spirit Pill",
		"desc": "A precious clan pill that widens your primeval sea: +5% aptitude (max 99%)."},
]


static func generate(rng: RandomNumberGenerator, rank: int, next_id: int) -> Dictionary:
	var roll := rng.randf()
	if roll < 0.45:
		var pool := HUNT_POOL.filter(func(h): return rank >= h[1])
		var h: Array = pool[rng.randi() % pool.size()]
		var n := rng.randi_range(h[2], h[3])
		return {"id": next_id, "type": "hunt", "target": h[0], "count": n, "progress": 0,
			"stones": n * h[4] * rank, "contrib": n * h[5],
			"title": "Hunt %d %s" % [n, EnemyDB.ENEMIES[h[0]]["name"]]}
	if roll < 0.85:
		var pool := GATHER_POOL.filter(func(g): return rank >= g[1])
		var g: Array = pool[rng.randi() % pool.size()]
		return {"id": next_id, "type": "gather", "target": g[0], "count": g[2], "progress": 0,
			"stones": g[3] * rank, "contrib": g[4],
			"title": "Deliver %d %s" % [g[2], ItemDB.ITEMS[g[0]]["name"]]}
	var e: Array = EXPLORE_POOL[rng.randi() % EXPLORE_POOL.size()]
	return {"id": next_id, "type": "explore", "target": e[0], "count": 1, "progress": 0,
		"stones": e[1] * rank, "contrib": e[2],
		"title": "Scout %s" % WorldData.poi(e[0])["name"]}


## Progress for display; gather missions count what's in the bag.
static func progress(q: Dictionary, inventory: Dictionary) -> int:
	if q["type"] == "gather":
		return mini(inventory.get(q["target"], 0), q["count"])
	return mini(q["progress"], q["count"])


static func is_complete(q: Dictionary, inventory: Dictionary) -> bool:
	return progress(q, inventory) >= q["count"]


static func describe(q: Dictionary) -> String:
	match q["type"]:
		"hunt": return "Slay %s in the wilds." % EnemyDB.ENEMIES[q["target"]]["name"]
		"gather": return "Bring %s to the elder." % ItemDB.ITEMS[q["target"]]["name"]
		"explore": return "Travel to %s and return alive." % WorldData.poi(q["target"])["name"]
	return ""
