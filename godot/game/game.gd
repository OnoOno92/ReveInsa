extends Node
## Autoload "Game": player state + rules (inventory, Gu, cultivation, economy, time, saves).
## No rendering here. The world scene drives tick() and listens to signals.

signal toast(msg: String, kind: String)  # kind: info | good | bad | gold
signal changed
signal npc_interact(npc: Dictionary)
signal teleported(pos: Vector2)
signal died
signal player_hurt(amount: float)
signal new_day(day: int)

var save_path := "user://save_v1.json"
const DAY_SECONDS := 300.0 # real seconds per in-game day
const STARTING_SEED_SALT := 0x5EED

var world: WorldData
## Player state. pos is a Vector2 in memory, saved as [x, y].
var p := {}
var time := 0.12 # days; fractional part = time of day
var flags := {}
var campfires: Array = [] # {pos: Vector2, until: float}
var build := {}
var shield := 0.0
var last_hurt := -99.0
var clock := 0.0
var rng := RandomNumberGenerator.new()
## Set by the HUD: virtual-stick vector and the on-screen action button.
var stick := Vector2.ZERO
var action_requested := false


func _ready() -> void:
	rng.randomize()


# ------------------------------------------------------------------ lifecycle
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func new_game(player_name: String, world_seed := -1) -> Dictionary:
	if world_seed < 0:
		world_seed = rng.randi() % 1000000000
	world = WorldData.new(world_seed)
	var aptitude := snappedf(0.42 + rng.randf() * 0.42, 0.01) # grade C..A
	p = {
		"name": player_name, "pos": WorldData.poi_center("village") + Vector2(0, WorldData.TILE * 1.5),
		"hp": 100.0, "essence": 0.0, "hunger": 80.0,
		"rank": 1, "stage": 0, "cultivation": 0.0, "aptitude": aptitude, "stones": 30,
		"inventory": {"meat": 2, "moon_orchid": 4, "herb": 4, "rice_ball": 2, "wood": 2},
		"gu": [], "placed": [], "next_uid": 1, "kills": 0,
		"contrib": 0, "quests": {"offered": [], "active": []}, "next_quest": 1,
	}
	time = 0.12
	flags = {}
	campfires = []
	shield = 0.0
	add_gu("moonlight", true)
	add_gu("stone_skin" if rng.randf() < 0.5 else "vitality_leaf", true)
	refill_missions()
	rebuild()
	p["hp"] = max_hp()
	p["essence"] = max_essence()
	world.reveal(p["pos"], 14)
	save_game()
	return {"grade": grade_of(aptitude), "aptitude": aptitude}


func save_game() -> void:
	if world == null:
		return
	var depleted: Array = []
	for n in world.nodes:
		if n["regrow_day"] > 0.0 or n["hp"] < WorldData.NODE_INFO[n["type"]]["hp"]:
			depleted.append([n["id"], n["regrow_day"], n["hp"]])
	var pd: Dictionary = p.duplicate(true)
	pd["pos"] = [p["pos"].x, p["pos"].y]
	var fires: Array = []
	for c in campfires:
		fires.append({"x": c["pos"].x, "y": c["pos"].y, "until": c["until"]})
	var data := {
		"v": 1, "seed": world.seed_value, "time": time, "player": pd, "flags": flags,
		"depleted": depleted, "campfires": fires, "explored": Marshalls.raw_to_base64(world.explored),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	world = WorldData.new(int(data["seed"]))
	time = float(data["time"])
	flags = data.get("flags", {})
	p = data["player"]
	p["pos"] = Vector2(p["pos"][0], p["pos"][1])
	# JSON turns ints into floats — normalize the fields we compare/key by.
	for k in ["rank", "stage", "stones", "next_uid", "kills"]:
		p[k] = int(p[k])
	for g in p["gu"]:
		g["uid"] = int(g["uid"]); g["unfed"] = int(g["unfed"])
	for pl in p["placed"]:
		for k in ["uid", "x", "y", "rot"]:
			pl[k] = int(pl[k])
	for k in p["inventory"].keys():
		p["inventory"][k] = int(p["inventory"][k])
	# Fields added after v0.1 saves
	p["contrib"] = int(p.get("contrib", 0))
	p["next_quest"] = int(p.get("next_quest", 1))
	if not p.has("quests"):
		p["quests"] = {"offered": [], "active": []}
	for list_name in ["offered", "active"]:
		for q in p["quests"][list_name]:
			for k in ["id", "count", "progress", "stones", "contrib"]:
				q[k] = int(q[k])
	var by_id := {}
	for n in world.nodes:
		by_id[n["id"]] = n
	for d in data.get("depleted", []):
		var n = by_id.get(int(d[0]))
		if n:
			n["regrow_day"] = float(d[1]); n["hp"] = int(d[2])
	campfires = []
	for c in data.get("campfires", []):
		campfires.append({"pos": Vector2(c["x"], c["y"]), "until": float(c["until"])})
	var ex := Marshalls.base64_to_raw(data.get("explored", ""))
	if ex.size() == world.explored.size():
		world.explored = ex
	shield = 0.0
	rebuild()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ------------------------------------------------------------------ derived stats
func stat(k: String) -> float:
	return build["stats"][k]

func max_hp() -> float:
	return 100.0 + (p["rank"] - 1) * 40.0 + p["stage"] * 8.0 + stat("max_hp")

func max_essence() -> float:
	var base: float = 40.0 * pow(1.7, p["rank"] - 1) * (1.0 + p["stage"] * 0.2)
	return base * (0.5 + p["aptitude"]) + stat("max_essence")

func essence_regen() -> float:
	return max_essence() * 0.012 * (0.5 + p["aptitude"]) * (1.0 + stat("essence_regen"))

func move_speed() -> float:
	return 150.0 * (1.0 + stat("move_speed"))

func day() -> int:
	return floori(time)

func tod() -> float:
	return time - floorf(time)

func is_night() -> bool:
	var t := tod()
	return t > 0.68 or t < 0.04

func darkness() -> float:
	var t := tod()
	if t < 0.04: return 0.82 * (1.0 - t / 0.04)
	if t < 0.58: return 0.0
	if t < 0.68: return 0.82 * ((t - 0.58) / 0.1)
	return 0.82

func ap_size() -> int:
	return Aperture.size_for_rank(p["rank"])

static func grade_of(apt: float) -> String:
	if apt >= 0.8: return "A"
	if apt >= 0.6: return "B"
	if apt >= 0.4: return "C"
	return "D"

func rebuild() -> void:
	build = Aperture.compute_build(p["rank"], p["placed"], p["gu"])
	shield = minf(shield, stat("shield"))
	p["hp"] = minf(p["hp"], max_hp())
	p["essence"] = minf(p["essence"], max_essence())


# ------------------------------------------------------------------ inventory & Gu
func count(item: String) -> int:
	return p["inventory"].get(item, 0)

func add_item(item: String, n := 1) -> void:
	var v := count(item) + n
	if v <= 0:
		p["inventory"].erase(item)
	else:
		p["inventory"][item] = v

func is_placed(uid: int) -> bool:
	for pl in p["placed"]:
		if pl["uid"] == uid:
			return true
	return false

func add_gu(def_id: String, auto_place := false) -> Dictionary:
	var inst := {"uid": p["next_uid"], "def": def_id, "unfed": 0}
	p["next_uid"] += 1
	p["gu"].append(inst)
	if auto_place and GuDB.GU[def_id]["rank"] <= p["rank"]:
		var spot := Aperture.find_free_spot(ap_size(), p["placed"], p["gu"], def_id)
		if not spot.is_empty():
			p["placed"].append({"uid": inst["uid"], "x": spot["x"], "y": spot["y"], "rot": spot["rot"]})
	return inst

func remove_gu(uid: int) -> void:
	p["gu"] = p["gu"].filter(func(g): return g["uid"] != uid)
	p["placed"] = p["placed"].filter(func(pl): return pl["uid"] != uid)

func place_gu(uid: int, x: int, y: int, rot: int) -> bool:
	var inst := Aperture.find_inst(p["gu"], uid)
	if inst.is_empty():
		return false
	var d: Dictionary = GuDB.GU[inst["def"]]
	if d["rank"] > p["rank"]:
		toast.emit("%s is rank %d. Your aperture cannot sustain it yet." % [d["name"], d["rank"]], "bad")
		return false
	if not Aperture.can_place(ap_size(), p["placed"], p["gu"], inst["def"], x, y, rot, uid):
		return false
	p["placed"] = p["placed"].filter(func(pl): return pl["uid"] != uid)
	p["placed"].append({"uid": uid, "x": x, "y": y, "rot": rot})
	rebuild()
	changed.emit()
	return true

func unplace_gu(uid: int) -> void:
	p["placed"] = p["placed"].filter(func(pl): return pl["uid"] != uid)
	rebuild()
	changed.emit()

func feed_gu(uid: int) -> bool:
	var inst := Aperture.find_inst(p["gu"], uid)
	if inst.is_empty():
		return false
	var d: Dictionary = GuDB.GU[inst["def"]]
	if count(d["food"]) <= 0:
		toast.emit("No %s to feed %s." % [ItemDB.ITEMS[d["food"]]["name"], d["name"]], "bad")
		return false
	add_item(d["food"], -1)
	inst["unfed"] = 0
	rebuild()
	changed.emit()
	return true

func eat(item: String) -> void:
	var d: Dictionary = ItemDB.ITEMS.get(item, {})
	if d.is_empty() or count(item) <= 0 or not (d.has("food") or d.has("heal")):
		return
	add_item(item, -1)
	p["hunger"] = minf(100.0, p["hunger"] + d.get("food", 0.0))
	p["hp"] = clampf(p["hp"] + d.get("heal", 0.0), 1.0, max_hp())
	toast.emit("Ate %s." % d["name"], "info")
	changed.emit()

var _absorb_cd := 0.0
func absorb_stone() -> bool:
	if p["stones"] <= 0 or _absorb_cd > 0.0:
		return false
	if p["essence"] >= max_essence() - 0.5:
		toast.emit("Your aperture is already full of essence.", "info")
		return false
	p["stones"] -= 1
	p["essence"] = minf(max_essence(), p["essence"] + max_essence() * 0.35)
	_absorb_cd = 0.8
	changed.emit()
	return true

func near_fire(pos: Vector2) -> bool:
	if world.is_safe(pos):
		return true
	for c in campfires:
		if (c["pos"] as Vector2).distance_to(pos) < 110.0:
			return true
	return false

## Returns "" when craftable, otherwise the reason.
func can_craft(r: Dictionary) -> String:
	for k in r["needs"]:
		if count(k) < r["needs"][k]:
			return "Need %d %s" % [r["needs"][k], ItemDB.ITEMS[k]["name"]]
	if p["stones"] < r.get("stones", 0):
		return "Need %d primeval stones" % r["stones"]
	if r.has("gu_input") and not p["gu"].any(func(g): return g["def"] == r["gu_input"]):
		return "Need a %s" % GuDB.GU[r["gu_input"]]["name"]
	if r.get("near_fire", false) and not near_fire(p["pos"]):
		return "Must be near a fire"
	if p["rank"] < r.get("min_rank", 0):
		return "Requires rank %d" % r["min_rank"]
	return ""

func craft(id: String, facing: Vector2 = Vector2.RIGHT) -> void:
	var r := ItemDB.recipe(id)
	if r.is_empty():
		return
	var why := can_craft(r)
	if why != "":
		toast.emit(why, "bad")
		return
	for k in r["needs"]:
		add_item(k, -r["needs"][k])
	p["stones"] -= r.get("stones", 0)
	if r.has("gu_input"):
		var cands: Array = p["gu"].filter(func(g): return g["def"] == r["gu_input"])
		var pick: Dictionary = cands[0]
		for c in cands:
			if not is_placed(c["uid"]):
				pick = c
				break
		remove_gu(pick["uid"])
	var out: Dictionary = r["output"]
	if out.has("item"):
		add_item(out["item"], out.get("count", 1))
		toast.emit("Made %s." % ItemDB.ITEMS[out["item"]]["name"], "good")
	if out.has("gu"):
		var success: float = 0.85 if r.has("gu_input") else 0.75 + p["aptitude"] * 0.2
		if rng.randf() < success:
			add_gu(out["gu"])
			toast.emit("Refinement succeeded: %s!" % GuDB.GU[out["gu"]]["name"], "gold")
		else:
			toast.emit("Refinement failed... the materials dissipated.", "bad")
	if out.get("place", "") == "campfire":
		campfires.append({"pos": p["pos"] + facing * 30.0, "until": time + 1.0})
		toast.emit("Campfire lit. It will burn for one day.", "good")
	rebuild()
	changed.emit()
	save_game()

func buy_gu(def_id: String) -> void:
	var d: Dictionary = GuDB.GU[def_id]
	if p["stones"] < d["price"]:
		toast.emit("Not enough primeval stones.", "bad")
		return
	p["stones"] -= d["price"]
	add_gu(def_id, true)
	toast.emit("Bought %s." % d["name"], "good")
	rebuild(); changed.emit(); save_game()

func sell_gu(uid: int) -> void:
	var inst := Aperture.find_inst(p["gu"], uid)
	if inst.is_empty():
		return
	var d: Dictionary = GuDB.GU[inst["def"]]
	var v := floori(d["price"] * 0.4)
	remove_gu(uid)
	p["stones"] += v
	toast.emit("Sold %s for %d stones." % [d["name"], v], "info")
	rebuild(); changed.emit(); save_game()

func buy_item(id: String, n := 1) -> void:
	var cost: int = ItemDB.ITEMS[id]["price"] * 2 * n
	if p["stones"] < cost:
		toast.emit("Not enough primeval stones.", "bad")
		return
	p["stones"] -= cost
	add_item(id, n)
	changed.emit()

func sell_item(id: String, n := 1) -> void:
	n = mini(n, count(id))
	if n <= 0:
		return
	add_item(id, -n)
	p["stones"] += ItemDB.ITEMS[id]["price"] * n
	changed.emit()


# ------------------------------------------------------------------ cultivation, travel, time
func cultivation_cost() -> int:
	return 10 * p["rank"] * p["rank"]

func cultivate() -> void:
	var cost := cultivation_cost()
	if p["rank"] >= 5 and p["stage"] >= 3 and p["cultivation"] >= 100.0:
		toast.emit("You stand at the peak of mortality. The path to Gu Immortal is not yet open.", "gold")
		return
	if p["stones"] < cost:
		toast.emit("Cultivation needs %d primeval stones." % cost, "bad")
		return
	p["stones"] -= cost
	p["cultivation"] += 20.0 + p["aptitude"] * 30.0
	advance_time(0.05)
	if p["cultivation"] >= 100.0:
		p["cultivation"] = 0.0
		if p["stage"] < 3:
			p["stage"] += 1
			toast.emit("Breakthrough! %s." % Aperture.STAGE_NAMES[p["stage"]], "gold")
		elif p["rank"] < 5:
			p["rank"] += 1
			p["stage"] = 0
			toast.emit("Your aperture expands - Rank %d! Your essence becomes %s." % [p["rank"], Aperture.ESSENCE_NAMES[p["rank"]]], "gold")
	rebuild()
	p["essence"] = max_essence()
	changed.emit(); save_game()

func travel(dest: String) -> void:
	var fee := 15
	if p["stones"] < fee:
		toast.emit("The caravan charges %d primeval stones." % fee, "bad")
		return
	p["stones"] -= fee
	p["pos"] = WorldData.poi_center(dest) + Vector2(0, WorldData.TILE * 2)
	advance_time(0.3)
	world.reveal(p["pos"], 16)
	teleported.emit(p["pos"])
	toast.emit("The caravan arrives at %s. Time passes on the road." % WorldData.poi(dest)["name"], "good")
	changed.emit(); save_game()

## Skip time forward, processing every dawn crossed (Gu feeding etc).
func advance_time(days: float) -> void:
	var target := time + days
	while floori(target) > day():
		time = float(day() + 1)
		_on_new_day()
	time = target

func rest_until_dawn() -> void:
	advance_time(day() + 1.02 - time)
	p["hp"] = max_hp()
	p["essence"] = max_essence()
	p["hunger"] = maxf(0.0, p["hunger"] - 15.0)
	toast.emit("You rest in safety until dawn.", "good")
	changed.emit()

func _on_new_day() -> void:
	var lines: Array[String] = []
	for inst in p["gu"].duplicate():
		var d: Dictionary = GuDB.GU[inst["def"]]
		inst["unfed"] += 1
		if inst["unfed"] >= d["feed_every"]:
			if count(d["food"]) > 0:
				add_item(d["food"], -1)
				inst["unfed"] = 0
			elif inst["unfed"] >= d["feed_every"] + 3:
				remove_gu(inst["uid"])
				lines.append("%s starved to death!" % d["name"])
			elif inst["unfed"] > d["feed_every"]:
				lines.append("%s is starving (needs %s)." % [d["name"], ItemDB.ITEMS[d["food"]]["name"]])
	_tide_reward()
	refill_missions()
	rebuild()
	toast.emit("Day %d dawns." % (day() + 1), "gold")
	for l in lines:
		toast.emit(l, "bad")
	new_day.emit(day())
	changed.emit()
	save_game()


# ------------------------------------------------------------------ clan missions & treasury
func missions() -> Dictionary:
	return p["quests"]

func refill_missions() -> void:
	var offered: Array = p["quests"]["offered"]
	while offered.size() < Quests.MAX_OFFERED:
		offered.append(Quests.generate(rng, p["rank"], p["next_quest"]))
		p["next_quest"] += 1

func accept_mission(id: int) -> void:
	var q := _find_mission("offered", id)
	if q.is_empty():
		return
	if p["quests"]["active"].size() >= Quests.MAX_ACTIVE:
		toast.emit("You can only carry %d missions at once." % Quests.MAX_ACTIVE, "bad")
		return
	p["quests"]["offered"].erase(q)
	p["quests"]["active"].append(q)
	toast.emit("Mission accepted: %s." % q["title"], "good")
	changed.emit()

func abandon_mission(id: int) -> void:
	var q := _find_mission("active", id)
	if q.is_empty():
		return
	p["quests"]["active"].erase(q)
	toast.emit("Mission abandoned: %s." % q["title"], "info")
	changed.emit()

func claim_mission(id: int) -> void:
	var q := _find_mission("active", id)
	if q.is_empty() or not Quests.is_complete(q, p["inventory"]):
		return
	if q["type"] == "gather":
		add_item(q["target"], -q["count"])
	p["quests"]["active"].erase(q)
	p["stones"] += q["stones"]
	p["contrib"] += q["contrib"]
	toast.emit("Mission complete: %s. +%d stones, +%d contribution." % [q["title"], q["stones"], q["contrib"]], "gold")
	refill_missions()
	changed.emit()
	save_game()

func _find_mission(list_name: String, id: int) -> Dictionary:
	for q in p["quests"][list_name]:
		if q["id"] == id:
			return q
	return {}

func on_enemy_killed(enemy_id: String, was_raider: bool) -> void:
	for q in p["quests"]["active"]:
		if q["type"] == "hunt" and q["target"] == enemy_id and q["progress"] < q["count"]:
			q["progress"] += 1
			if q["progress"] == q["count"]:
				toast.emit("Mission ready to report: %s." % q["title"], "good")
	if was_raider:
		flags["tide_kills"] = int(flags.get("tide_kills", 0)) + 1

func _track_explore() -> void:
	var z := world.zone_at(p["pos"])
	for q in p["quests"]["active"]:
		if q["type"] == "explore" and q["progress"] < 1 and WorldData.ZONE_IDS[WorldData.poi(q["target"])["zone"]] == z:
			q["progress"] = 1
			toast.emit("Scouted %s. Report back to the elder." % WorldData.poi(q["target"])["name"], "good")
			changed.emit()

func buy_treasury(entry_id: String) -> void:
	var e: Dictionary = {}
	for t in Quests.TREASURY:
		if t["id"] == entry_id:
			e = t
	if e.is_empty():
		return
	if p["contrib"] < e["cost"]:
		toast.emit("Not enough clan contribution.", "bad")
		return
	if e["kind"] == "pill":
		if p["aptitude"] >= 0.99:
			toast.emit("Your aptitude cannot rise any further.", "info")
			return
		p["contrib"] -= e["cost"]
		p["aptitude"] = minf(0.99, p["aptitude"] + 0.05)
		toast.emit("Your primeval sea widens: aptitude %d%% (Grade %s)." % [roundi(p["aptitude"] * 100), grade_of(p["aptitude"])], "gold")
	else:
		p["contrib"] -= e["cost"]
		add_gu(e["id"], true)
		toast.emit("The clan grants you %s." % GuDB.GU[e["id"]]["name"], "gold")
	rebuild(); changed.emit(); save_game()


# ------------------------------------------------------------------ beast tides
## Every 5th day (Day 5, 10, ...) beasts storm Shi Lan Village at night.
func is_tide_day() -> bool:
	return (day() + 1) % 5 == 0

func tide_active() -> bool:
	return is_tide_day() and tod() > 0.68

## Settlements keep monsters out, except the village during a beast tide.
func blocks_enemies(pos: Vector2) -> bool:
	if not world.is_safe(pos):
		return false
	return not (tide_active() and world.zone_at(pos) == "village")

func _tide_transitions(prev_tod: float) -> void:
	if not is_tide_day():
		return
	var t := tod()
	if prev_tod < 0.5 and t >= 0.5:
		toast.emit("War drums from the wilds... a BEAST TIDE will strike Shi Lan Village tonight!", "bad")
	if prev_tod < 0.68 and t >= 0.68:
		flags["tide_kills"] = 0
		flags["tide_on"] = true
		toast.emit("BEAST TIDE! Defend Shi Lan Village until dawn!", "bad")

func _tide_reward() -> void:
	if not flags.get("tide_on", false):
		return
	flags.erase("tide_on")
	var kills := int(flags.get("tide_kills", 0))
	flags.erase("tide_kills")
	if kills <= 0:
		toast.emit("The beast tide passed. The clan noticed you were not on the walls.", "info")
		return
	var stones: int = kills * 4 * p["rank"]
	var contrib := kills * 2 + 15
	p["stones"] += stones
	p["contrib"] += contrib
	toast.emit("The beast tide is repelled! You slew %d beasts: +%d stones, +%d contribution." % [kills, stones, contrib], "gold")


# ------------------------------------------------------------------ per-frame survival (driven by the world scene)
var _explore_t := 0.0
func tick(delta: float) -> void:
	clock += delta
	_absorb_cd = maxf(0.0, _absorb_cd - delta)
	var prev := day()
	var prev_tod := tod()
	time += delta / DAY_SECONDS
	_tide_transitions(prev_tod)
	_explore_t -= delta
	if _explore_t <= 0.0:
		_explore_t = 0.5
		_track_explore()
	if day() != prev:
		time = float(day())
		_on_new_day()
	p["hunger"] = maxf(0.0, p["hunger"] - delta * (100.0 / (DAY_SECONDS * 1.1)))
	var safe := world.is_safe(p["pos"])
	var regen := 0.25 + stat("hp_regen") + (3.0 if safe else 0.0)
	if p["hunger"] <= 0.0:
		regen = -1.5
	p["hp"] = minf(max_hp(), p["hp"] + regen * delta)
	p["essence"] = minf(max_essence(), p["essence"] + essence_regen() * (2.0 if safe else 1.0) * delta)
	if clock - last_hurt > 3.0 and stat("shield") > 0.0:
		shield = minf(stat("shield"), shield + stat("shield") * 0.15 * delta)
	campfires = campfires.filter(func(c): return c["until"] > time)
	if p["hp"] <= 0.0:
		die("You starved.")

func hurt_player(dmg: float, source: String) -> void:
	last_hurt = clock
	var d := dmg
	if shield > 0.0:
		var absorbed := minf(shield, d)
		shield -= absorbed
		d -= absorbed
	d = d * 30.0 / (30.0 + stat("armor"))
	if d <= 0.0:
		return
	p["hp"] -= d
	player_hurt.emit(d)
	if p["hp"] <= 0.0:
		die("You were slain by a %s." % source)

func die(reason: String) -> void:
	var lost := floori(p["stones"] / 2.0)
	p["stones"] -= lost
	var keep := {}
	for k in p["inventory"]:
		if p["inventory"][k] > 1:
			keep[k] = floori(p["inventory"][k] / 2.0)
	p["inventory"] = keep
	p["pos"] = WorldData.poi_center("village") + Vector2(0, WorldData.TILE * 1.5)
	p["hp"] = max_hp() * 0.6
	p["hunger"] = maxf(p["hunger"], 40.0)
	p["essence"] = max_essence() * 0.3
	if tide_active():
		reason += " The clan guards held the walls until dawn."
		advance_time(day() + 1.02 - time)
	else:
		advance_time(0.25)
	toast.emit("%s Your clan carried you home. Lost %d stones and half your supplies." % [reason, lost], "bad")
	died.emit()
	teleported.emit(p["pos"])
	changed.emit()
	save_game()

func loot_inheritance() -> String:
	flags["ruins_looted"] = true
	p["stones"] += 150
	var pool := ["moon_glow", "thunder_bead", "four_flavors", "fire_ember"]
	var g: String = pool[rng.randi() % pool.size()]
	add_gu(g)
	add_item("jade_shard", 3)
	toast.emit("You received the Nameless Inheritance: 150 primeval stones and %s!" % GuDB.GU[g]["name"], "gold")
	changed.emit(); save_game()
	return g
