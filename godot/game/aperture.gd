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
	"damage_mult", "shield", "light_radius", "reveal", "pickup"]


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
	return inst["unfed"] > GuDB.GU[inst["def"]]["feed_every"]


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


## Returns {attacks, heals, stats, synergies, killer_moves, inactive}
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
		_add_stats(stats, def_of(gu, p["uid"]).get("stats"))

	var attacks: Array = []
	var heals: Array = []
	for p in active:
		var uid: int = p["uid"]
		var d := def_of(gu, uid)
		if d.has("heal"):
			var h: Dictionary = d["heal"].duplicate()
			h["key"] = "h%d" % uid
			h["name"] = d["name"]
			heals.append(h)
		if not d.has("attack"):
			continue
		var a: Dictionary = d["attack"].duplicate()
		a["key"] = "a%d" % uid
		a["name"] = d["name"]
		a["is_killer"] = false
		var dmg_mult := 1.0
		var cd_mult := 1.0
		var cost_mult := 1.0
		var resonance := 0
		for n in adj.get(uid, {}):
			var nd := def_of(gu, n)
			if nd.has("aura"):
				var au: Dictionary = nd["aura"]
				dmg_mult += au.get("damage_mult", 0.0)
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
		a["damage"] = a["damage"] * dmg_mult
		a["cooldown"] = a["cooldown"] * maxf(0.3, cd_mult)
		a["cost"] = a["cost"] * maxf(0.2, cost_mult)
		attacks.append(a)

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
	return {"attacks": attacks, "heals": heals, "stats": stats, "synergies": synergies,
		"killer_moves": killer_moves, "inactive": inactive}
