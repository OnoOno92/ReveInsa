class_name Aperture
extends RefCounted
## The aperture is a backpack-style grid. Gu occupy shaped cells; adjacency between
## Gu produces auras, path resonance and killer moves. Pure logic — no nodes.
##
## Gu instance: {"uid": int, "def": String, "unfed": int}
## Placement:   {"uid": int, "x": int, "y": int, "rot": int}

const RANK_NAMES := ["", "Rank 1", "Rank 2", "Rank 3", "Rank 4", "Rank 5"]
const STAGE_NAMES := ["Initial Stage", "Middle Stage", "Upper Stage", "Peak Stage"]
## Primeval essence colour per rank: green copper, red steel, white silver, yellow gold, purple crystal
const ESSENCE_COLORS := ["#ffffff", "#3fae6a", "#c0392b", "#dfe6e9", "#f1c40f", "#8e44ad"]
const ESSENCE_NAMES := ["", "Green Copper", "Red Steel", "White Silver", "Yellow Gold", "Purple Crystal"]
const STAT_KEYS := ["armor", "max_hp", "hp_regen", "max_essence", "essence_regen", "move_speed",
	"damage_mult", "shield", "light_radius", "reveal", "pickup", "summon_count", "summon_damage",
	"lifesteal", "damage_taken", "berserk", "crit", "range_mult"]


static func size_for_rank(rank: int) -> int:
	return 3 + rank


static func essence_color(rank: int) -> Color:
	return Color.html(ESSENCE_COLORS[rank])


static func shape_cells(def_id: String, rot: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for c in GuDB.GU[def_id]["shape"]:
		cells.append(c)
	for _i in posmod(rot, 4):
		var turned: Array[Vector2i] = []
		for c in cells:
			turned.append(Vector2i(-c.y, c.x))
		cells = turned
	var mn := Vector2i(999, 999)
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c - mn)
	return out


static func find_inst(gu: Array, uid: int) -> Dictionary:
	for g in gu:
		if g["uid"] == uid:
			return g
	return {}


static func def_of(gu: Array, uid: int) -> Dictionary:
	return GuDB.GU[find_inst(gu, uid)["def"]]


static func is_starving(inst: Dictionary) -> bool:
	return inst["unfed"] > GuRoll.feed_every(inst)


## Scale positive stat values by a Gu's power roll.
static func _scaled_stats(s: Dictionary, mult: float) -> Dictionary:
	var out := {}
	for k in s:
		out[k] = s[k] * mult if s[k] > 0 else s[k]
	return out


## Grid of uids (0 = empty), row-major.
static func occupancy(size: int, placed: Array, gu: Array, ignore_uid := -1) -> PackedInt32Array:
	var occ := PackedInt32Array()
	occ.resize(size * size)
	for p in placed:
		if p["uid"] == ignore_uid:
			continue
		var inst := find_inst(gu, p["uid"])
		if inst.is_empty():
			continue
		for c in shape_cells(inst["def"], p["rot"]):
			var x: int = p["x"] + c.x
			var y: int = p["y"] + c.y
			if x >= 0 and y >= 0 and x < size and y < size:
				occ[y * size + x] = p["uid"]
	return occ


static func can_place(size: int, placed: Array, gu: Array, def_id: String, x: int, y: int, rot: int, ignore_uid := -1) -> bool:
	var occ := occupancy(size, placed, gu, ignore_uid)
	for c in shape_cells(def_id, rot):
		var px := x + c.x
		var py := y + c.y
		if px < 0 or py < 0 or px >= size or py >= size:
			return false
		if occ[py * size + px] != 0:
			return false
	return true


static func find_free_spot(size: int, placed: Array, gu: Array, def_id: String) -> Dictionary:
	for rot in 4:
		for y in size:
			for x in size:
				if can_place(size, placed, gu, def_id, x, y, rot):
					return {"x": x, "y": y, "rot": rot}
	return {}


## uid -> {neighbour_uid: true}
static func adjacency(size: int, placed: Array, gu: Array) -> Dictionary:
	var occ := occupancy(size, placed, gu)
	var adj := {}
	for p in placed:
		adj[p["uid"]] = {}
	for y in size:
		for x in size:
			var a := occ[y * size + x]
			if a == 0:
				continue
			for n in [Vector2i(x + 1, y), Vector2i(x, y + 1)]:
				if n.x >= size or n.y >= size:
					continue
				var b := occ[n.y * size + n.x]
				if b != 0 and b != a and adj.has(a) and adj.has(b):
					adj[a][b] = true
					adj[b][a] = true
	return adj


static func empty_stats() -> Dictionary:
	var s := {}
	for k in STAT_KEYS:
		s[k] = 0.0
	return s


static func _add_stats(into: Dictionary, s: Variant) -> void:
	if s == null:
		return
	for k in s:
		into[k] += float(s[k])


## Number of touching same-path Gu pairs per path, e.g. {"moon": 2}.
static func path_pairs(size: int, active: Array, gu: Array) -> Dictionary:
	var adj := adjacency(size, active, gu)
	var pairs := {}
	for u in adj:
		for v in adj[u]:
			if u < v:
				var pu: String = def_of(gu, u)["path"]
				if pu == def_of(gu, v)["path"]:
					pairs[pu] = pairs.get(pu, 0) + 1
	return pairs


## Returns {attacks, heals, summons, stats, synergies, killer_moves, combos, path_pairs, inactive, pairs, passives}
static func compute_build(rank: int, placed: Array, gu: Array) -> Dictionary:
	var size := size_for_rank(rank)
	var stats := empty_stats()
	var synergies: Array[String] = []
	var inactive := {}
	var active: Array = []
	for p in placed:
		var inst := find_inst(gu, p["uid"])
		if inst.is_empty():
			continue
		if is_starving(inst):
			inactive[p["uid"]] = true
		else:
			active.append(p)
	var adj := adjacency(size, active, gu)

	for p in active:
		var st = def_of(gu, p["uid"]).get("stats")
		if st != null:
			_add_stats(stats, _scaled_stats(st, GuRoll.power_mult(find_inst(gu, p["uid"]))))

	# Dao combos (2+ touching same-path pairs)
	var pairs := path_pairs(size, active, gu)
	var combos: Array = []
	for path in pairs:
		if pairs[path] >= 2 and GuDB.DAO_COMBOS.has(path):
			var c: Dictionary = GuDB.DAO_COMBOS[path].duplicate()
			c["path"] = path
			combos.append(c)
			_add_stats(stats, c.get("stats"))

	# Named pairs: two specific Gu touching
	var pairs_on: Array = []
	for pr in GuDB.PAIRS:
		if _pair_touching(pr["gu"][0], pr["gu"][1], active, gu, adj):
			pairs_on.append(pr)
			_add_stats(stats, pr.get("stats"))

	# Trigger passives of every active Gu
	var passives: Array = []
	for p in active:
		var pid: String = find_inst(gu, p["uid"])["def"]
		if GuDB.PASSIVES.has(pid):
			var ps: Dictionary = GuDB.PASSIVES[pid].duplicate(true)
			ps["key"] = "p%d" % p["uid"]
			ps["gu"] = pid
			passives.append(ps)

	var attacks: Array = []
	var heals: Array = []
	for p in active:
		var uid: int = p["uid"]
		var d := def_of(gu, uid)
		var inst := find_inst(gu, uid)
		if d.has("heal"):
			var h: Dictionary = d["heal"].duplicate()
			h["key"] = "h%d" % uid
			h["name"] = d["name"]
			h["amount"] = h["amount"] * GuRoll.power_mult(inst)
			h["cooldown"] = h["cooldown"] * GuRoll.cooldown_mult(inst)
			h["cost"] = h["cost"] * GuRoll.cost_mult(inst)
			heals.append(h)
		if not d.has("attack"):
			continue
		var a: Dictionary = d["attack"].duplicate()
		a["key"] = "a%d" % uid
		a["name"] = d["name"]
		a["path"] = d["path"]
		a["def"] = inst["def"]
		if GuDB.PASSIVES.has(inst["def"]) and GuDB.PASSIVES[inst["def"]]["trigger"] == "opener":
			a["opener"] = GuDB.PASSIVES[inst["def"]]
		a["is_killer"] = false
		for c in combos:
			if c["path"] == d["path"] and c.has("attack"):
				_apply_attack_effects(a, c["attack"])
		var dmg_mult := 1.0
		var cd_mult := 1.0
		var cost_mult := 1.0
		var resonance := 0
		for n in adj.get(uid, {}):
			var nd := def_of(gu, n)
			if nd.has("aura"):
				var au: Dictionary = nd["aura"]
				var apow := GuRoll.power_mult(find_inst(gu, n))
				dmg_mult += au.get("damage_mult", 0.0) * apow
				cd_mult += au.get("cooldown_mult", 0.0)
				cost_mult += au.get("cost_mult", 0.0)
				if au.has("slow"):
					a["slow"] = maxf(a.get("slow", 0.0), au["slow"])
				if au.has("range_add"):
					a["range"] += au["range_add"]
				synergies.append("%s empowers %s" % [nd["name"], d["name"]])
			if nd["path"] == d["path"]:
				resonance += 1
		if resonance > 0:
			dmg_mult += 0.15 * resonance
			synergies.append("%s: %s resonance x%d (+%d%% dmg)" % [d["name"], GuDB.PATH_NAMES[d["path"]], resonance, 15 * resonance])
		a["damage"] = a["damage"] * dmg_mult * GuRoll.power_mult(inst)
		a["cooldown"] = a["cooldown"] * maxf(0.3, cd_mult) * GuRoll.cooldown_mult(inst)
		a["cost"] = a["cost"] * maxf(0.2, cost_mult) * GuRoll.cost_mult(inst)
		a["shiny"] = inst.get("shiny", false)
		attacks.append(a)

	# Pair bonuses on specific attacks / heals
	for pr in pairs_on:
		for gid in pr.get("attack", {}):
			for a in attacks:
				if a.get("def", "") != gid:
					continue
				var mods: Dictionary = pr["attack"][gid]
				a["range"] = a["range"] * (1.0 + mods.get("range_mult", 0.0))
				a["cooldown"] = a["cooldown"] * (1.0 + mods.get("cooldown_mult", 0.0))
				a["pierce"] = a.get("pierce", 0) + mods.get("pierce_add", 0)
				if mods.has("stun_add"):
					a["stun"] = a.get("stun", 0.0) + mods["stun_add"]
		if pr.has("heal_cost"):
			for h in heals:
				h["cost"] = h["cost"] * pr["heal_cost"]

	# Killer moves: every required Gu present and connected through each other
	var killer_moves: Array = []
	for km in GuDB.KILLER_MOVES:
		if rank < km["min_rank"]:
			continue
		var members: Array[int] = []
		var ok := true
		for req in km["requires"]:
			var found := -1
			for p in active:
				if find_inst(gu, p["uid"])["def"] == req and not members.has(p["uid"]):
					found = p["uid"]
					break
			if found < 0:
				ok = false
				break
			members.append(found)
		if not ok:
			continue
		var seen := {members[0]: true}
		var stack: Array[int] = [members[0]]
		while not stack.is_empty():
			var u: int = stack.pop_back()
			for v in adj.get(u, {}):
				if members.has(v) and not seen.has(v):
					seen[v] = true
					stack.append(v)
		if seen.size() != members.size():
			continue
		killer_moves.append(km)
		_add_stats(stats, km.get("stats"))
		if km.has("attack"):
			var ka: Dictionary = km["attack"].duplicate()
			ka["key"] = "k" + km["id"]
			ka["name"] = km["name"]
			ka["is_killer"] = true
			attacks.append(ka)

	for a in attacks:
		a["damage"] = a["damage"] * (1.0 + stats["damage_mult"])
		a["range"] = a["range"] * (1.0 + stats["range_mult"])
		if a.has("radius"):
			a["radius"] = a["radius"] * (1.0 + stats["range_mult"])

	# Summons (enslavement path): one entry per summoning Gu; killer moves can add more.
	var summons: Array = []
	for p in active:
		var d := def_of(gu, p["uid"])
		if d.has("summon"):
			var s: Dictionary = d["summon"].duplicate()
			s["key"] = "s%d" % p["uid"]
			var spow := GuRoll.power_mult(find_inst(gu, p["uid"]))
			s["count"] = int(s["count"] + stats["summon_count"])
			s["damage"] = s["damage"] * (1.0 + stats["summon_damage"] + stats["damage_mult"]) * spow
			s["hp"] = s["hp"] * spow
			summons.append(s)
	return {"attacks": attacks, "heals": heals, "summons": summons, "stats": stats, "synergies": synergies,
		"killer_moves": killer_moves, "combos": combos, "path_pairs": pairs, "inactive": inactive,
		"pairs": pairs_on, "passives": passives}


## True if any placed instance of gu id a touches any placed instance of gu id b.
static func _pair_touching(a: String, b: String, active: Array, gu: Array, adj: Dictionary) -> bool:
	for p in active:
		if find_inst(gu, p["uid"])["def"] != a:
			continue
		for n in adj.get(p["uid"], {}):
			if find_inst(gu, n)["def"] == b:
				return true
	return false


static func _apply_attack_effects(a: Dictionary, fx: Dictionary) -> void:
	for k in fx:
		match k:
			"pierce_add": a["pierce"] = a.get("pierce", 0) + fx[k]
			"count_add":
				if a["kind"] == "chain" or a["kind"] == "fan":
					a["count"] = a.get("count", 1) + fx[k]
			_: a[k] = maxf(a.get(k, 0.0), fx[k])
