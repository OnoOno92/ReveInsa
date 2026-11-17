extends Node2D
## Auto-combat: every active attack Gu fires on its own when a foe is in range,
## paying primeval essence. Also owns projectiles (drawn here) and enemy spawning.

const EnemyScript := preload("res://actors/enemy.gd")
const AllyScript := preload("res://actors/ally.gd")

var view: Node # world_view.gd
var projectiles: Array = [] # {pos, vel, damage, life, size, color, friendly, pierce, slow, hit: {}}
var timers := {}
var spawn_t := 0.0
var ally_respawn := {} # summon key -> seconds until a fallen beast returns
var _guards_posted := false
var nemesis_actor: Node = null
var _last_fire := {} # attack key -> Game.clock of its last shot (for opening-strike passives)


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _ready() -> void:
	Game.nemesis_engage.connect(_on_nemesis_engage)
	Game.passive_burst.connect(_on_passive_burst)


## When-hit passives that reach out to nearby enemies.
func _on_passive_burst(ps: Dictionary) -> void:
	var at: Vector2 = Game.p["pos"]
	for e in enemies():
		if e.position.distance_to(at) > 110.0:
			continue
		if ps.has("shove"):
			e.push((e.position - at).normalized() * ps["shove"] * 3.0)
		if ps.has("slow"):
			e.slow_t = 2.5
			e.slow_amt = maxf(e.slow_amt, ps["slow"])
	view.fx.add("ring", at, Color("#c9a36b") if ps.has("shove") else Color("#d16ba5"), 0.45, {"r": 110.0})
	view.fx.text(at + Vector2(0, -44), ps["name"], Color("#ffe9a8"), 0.9)


## The nemesis steps out of the wilds with two followers.
func _on_nemesis_engage(n: Dictionary) -> void:
	var ppos: Vector2 = Game.p["pos"]
	var from: Vector2 = (n["pos"] - ppos).normalized() if n["pos"] != ppos else Vector2.RIGHT
	var at := ppos + from * 380.0
	for attempt in 8:
		if not Game.world.is_solid_pos(at) and not Game.world.is_safe(at):
			break
		at = ppos + from.rotated(attempt * 0.8) * 380.0
	var st := Nemesis.combat_stats(n)
	var e: Node = spawn("nemesis", at)
	e.max_hp = st["hp"]
	e.hp = e.max_hp
	e.dmg_scale = st["dmg_scale"]
	e.tint = Nemesis.path_color(n).darkened(0.35)
	e.display_name = n["name"]
	e.aggro = true
	nemesis_actor = e
	for i in 2:
		var m: Node = spawn("demonic_master", at + Vector2.from_angle(i * PI + 0.6) * 50.0)
		m.aggro = true
	view.fx.add("ring", at, Color("#ff4d6d"), 1.0, {"r": 90.0})


func _update_nemesis_actor() -> void:
	if not Game.nemesis_present:
		return
	if not is_instance_valid(nemesis_actor) or nemesis_actor.is_queued_for_deletion():
		Game.nemesis_lost_trail(Game.nemesis["pos"]) # removed some other way (travel, tribulation): he stays where he was
		nemesis_actor = null
		return
	Game.nemesis["pos"] = nemesis_actor.position
	if nemesis_actor.position.distance_to(Game.p["pos"]) > 1400.0:
		Game.nemesis_lost_trail(nemesis_actor.position)
		nemesis_actor.queue_free()
		nemesis_actor = null


func clear_enemies(keep_boss := true) -> void:
	for e in enemies():
		if not (keep_boss and e.is_boss()):
			e.queue_free()
	for a in allies():
		a.position = Game.p["pos"] + Vector2.from_angle(randf() * TAU) * 30.0
	projectiles.clear()


func spawn(enemy_id: String, pos: Vector2, home := Vector2.INF) -> Node:
	var e: CharacterBody2D = EnemyScript.new()
	e.setup(enemy_id, pos, Game.day(), home)
	e.fired.connect(_on_enemy_fired)
	view.entities.add_child(e)
	return e


func spawn_boss_if_needed() -> void:
	if Game.flags.has("bear_king_died"):
		if Game.day() - int(Game.flags["bear_king_died"]) < 5:
			return
		Game.flags.erase("bear_king_died")
	for e in enemies():
		if e.is_boss():
			return
	var c := WorldData.poi_center("forbidden")
	spawn("bear_king", c, c)


func _on_enemy_fired(from: Vector2, dir: Vector2, spec: Dictionary) -> void:
	var sp: float = spec["speed"]
	projectiles.append({"pos": from, "vel": dir * sp, "damage": spec["damage"] * (1.0 + Game.day() * 0.03),
		"life": spec["range"] / sp + 0.2, "size": 6.0, "color": Color.html(spec["color"]), "friendly": false,
		"pierce": 0, "slow": 0.0, "hit": {}})


func _physics_process(delta: float) -> void:
	_update_nemesis_actor()
	_update_spawns(delta)
	_update_allies(delta)
	_update_heals(delta)
	if not Game.world.is_safe(Game.p["pos"]) or Game.tide_active():
		_update_attacks(delta)
	_update_projectiles(delta)
	for e in enemies():
		if e.hp <= 0.0 and not e.is_queued_for_deletion():
			_kill(e)
	queue_redraw()


# ------------------------------------------------------------------ spawning
func _update_spawns(delta: float) -> void:
	var ppos: Vector2 = Game.p["pos"]
	for e in enemies():
		if not e.is_boss() and e != nemesis_actor and e.position.distance_to(ppos) > 1500.0:
			e.queue_free()
	spawn_t -= delta
	if spawn_t > 0.0 or Game.in_tribulation:
		return
	spawn_t = 1.3
	if Game.tide_active() and ppos.distance_to(WorldData.poi_center("village")) < 45.0 * WorldData.TILE:
		_spawn_raiders()
		return
	var cap := roundi((12.0 if Game.is_night() else 7.0) + Game.world.danger_at(ppos) * 8.0)
	if enemies().size() >= cap:
		return
	for attempt in 6:
		var pos := ppos + Vector2.from_angle(randf() * TAU) * randf_range(560.0, 860.0)
		if Game.world.is_solid_pos(pos) or Game.world.is_safe(pos):
			continue
		var table := EnemyDB.spawn_table(Game.world.zone_at(pos), Game.is_night(), Game.world.danger_at(pos)).filter(func(t): return t[1] > 0)
		if table.is_empty():
			continue
		var total := 0
		for t in table:
			total += t[1]
		var roll := randi() % total
		var pick: String = table[0][0]
		for t in table:
			roll -= t[1]
			if roll < 0:
				pick = t[0]
				break
		var pack := randi_range(1, 3) if pick in ["wolf", "night_wolf"] else 1
		for i in pack:
			spawn(pick, pos + Vector2(i * 20, i * 14))
		return


## Beast tide: packs pour in from the wilds around the village.
func _spawn_raiders() -> void:
	spawn_t = 1.0
	var raiders := enemies().filter(func(e): return e.raider)
	if raiders.size() >= 5 + Game.day():
		return
	spawn_t = maxf(1.2, 3.0 - Game.day() * 0.1)
	var heart := WorldData.poi_center("village")
	var pool := ["wolf", "night_wolf", "night_wolf", "boar"]
	if Game.day() >= 9:
		pool.append("thunder_wolf")
	for attempt in 8:
		var pos := heart + Vector2.from_angle(randf() * TAU) * randf_range(15.0, 19.0) * WorldData.TILE
		if Game.world.is_solid_pos(pos):
			continue
		var pick: String = pool[randi() % pool.size()]
		for i in (randi_range(1, 2) if pick != "thunder_wolf" else 1):
			var e = spawn(pick, pos + Vector2(i * 22, i * 12))
			e.raider = true
		return


# ------------------------------------------------------------------ summons
## Clan guards hold posts around the village heart while a beast tide rages.
func _update_guards() -> void:
	var guards := allies().filter(func(a): return a.mode == "guard")
	if not Game.tide_active():
		for g in guards:
			g.queue_free()
		_guards_posted = false
		return
	for g in guards:
		if g.hp <= 0.0:
			view.fx.add("burst", g.position, Color("#3d6a8a"), 0.5)
			g.queue_free()
	if _guards_posted:
		return
	_guards_posted = true
	var heart := WorldData.poi_center("village")
	for off in [Vector2(-5, -3), Vector2(5, -3), Vector2(-5, 4), Vector2(5, 4)]:
		var g: CharacterBody2D = AllyScript.new()
		g.setup_guard(heart + off * WorldData.TILE)
		g.shoot.connect(_on_guard_shoot)
		view.entities.add_child(g)


func _on_guard_shoot(from: Vector2, dir: Vector2) -> void:
	projectiles.append({"pos": from, "vel": dir * 420.0, "damage": 9.0 + Game.day() * 0.6, "life": 0.7,
		"size": 7.0, "color": Color("#bfe0ff"), "friendly": true, "pierce": 0, "slow": 0.0, "hit": {}})


func allies() -> Array:
	return get_tree().get_nodes_in_group("allies")


func _update_allies(delta: float) -> void:
	var want := {}
	for s in Game.build.get("summons", []):
		want[s["key"]] = s
	var have := {}
	_update_guards()
	for a in allies():
		if a.mode == "guard":
			continue
		if a.hp <= 0.0:
			view.fx.add("burst", a.position, Color("#b9a98c"), 0.5)
			var spec: Dictionary = want.get(a.key, {})
			ally_respawn[a.key] = spec.get("respawn", 20.0)
			a.queue_free()
			continue
		if not want.has(a.key) or have.get(a.key, 0) >= want[a.key]["count"]:
			a.queue_free() # Gu removed, starving, or count reduced
			continue
		have[a.key] = have.get(a.key, 0) + 1
		a.damage = want[a.key]["damage"]
	for key in want:
		var t: float = ally_respawn.get(key, 0.0) - delta
		ally_respawn[key] = t
		if t > 0.0:
			continue
		var spec: Dictionary = want[key]
		for i in range(have.get(key, 0), spec["count"]):
			var a: CharacterBody2D = AllyScript.new()
			a.setup(spec, i, Game.p["pos"] + Vector2.from_angle(randf() * TAU) * 30.0)
			view.entities.add_child(a)
			view.fx.add("ring", a.position, Color("#d16ba5"), 0.5, {"r": 24.0})


# ------------------------------------------------------------------ player skills
func _nearest(from: Vector2, rng: float, exclude := {}) -> Node:
	var best: Node = null
	var bd := rng * rng
	for e in enemies():
		if e.hp <= 0.0 or exclude.has(e):
			continue
		var d: float = e.position.distance_squared_to(from)
		if d < bd:
			bd = d
			best = e
	return best


func _update_heals(delta: float) -> void:
	var p := Game.p
	for h in Game.build["heals"]:
		var t: float = timers.get(h["key"], 0.0) - delta
		if t <= 0.0 and p["hp"] < Game.max_hp() * 0.7 and p["essence"] >= h["cost"]:
			p["essence"] -= h["cost"]
			p["hp"] = minf(Game.max_hp(), p["hp"] + h["amount"])
			view.fx.text(p["pos"] + Vector2(0, -30), "+%d" % h["amount"], Color.html("#7cfc8a"), 0.9)
			view.fx.add("ring", p["pos"], Color.html("#7cfc8a"), 0.5, {"r": 26.0})
			t = h["cooldown"]
		timers[h["key"]] = maxf(0.0, t)


func _update_attacks(delta: float) -> void:
	var p := Game.p
	for a in Game.build["attacks"]:
		var t: float = timers.get(a["key"], 0.0) - delta
		if t <= 0.0:
			var reach: float = a.get("radius", a["range"]) if a["kind"] == "nova" else a["range"]
			var target := _nearest(p["pos"], reach)
			if target and p["essence"] >= a["cost"]:
				p["essence"] -= a["cost"]
				_fire(a, target)
				t = a["cooldown"]
			else:
				t = 0.1
		timers[a["key"]] = t


func _fire(a: Dictionary, target: Node) -> void:
	var origin: Vector2 = Game.p["pos"]
	# Opening strike: first shot of this Gu after 6s of calm
	if a.has("opener") and Game.clock - _last_fire.get(a["key"], -99.0) > 6.0 and Game.clock - Game.last_hurt > 6.0:
		a = a.duplicate()
		a["damage"] = a["damage"] * a["opener"].get("opener_mult", 1.0)
		if a["opener"].has("opener_burn"):
			a["burn"] = a.get("burn", 0.0) + a["opener"]["opener_burn"]
		view.fx.text(origin + Vector2(0, -52), a["opener"]["name"], Color("#ffe9a8"), 0.9)
	_last_fire[a["key"]] = Game.clock
	var ang: float = (target.position - origin).angle()
	var col := Color.html(a["color"])
	if a["is_killer"]:
		view.fx.text(origin + Vector2(0, -40), a["name"], Color.html("#ffd76b"), 1.1)
	match a["kind"]:
		"projectile":
			_shoot(a, origin, ang, col)
		"fan":
			var n: int = a.get("count", 3)
			var s: float = a.get("spread", 0.5)
			for i in n:
				_shoot(a, origin, ang - s / 2.0 + (s / 2.0 if n == 1 else s * i / (n - 1)), col)
		"nova":
			var r: float = a.get("radius", 100.0)
			for e in enemies():
				if e.position.distance_to(origin) < r + e.radius:
					_hit(e, a["damage"], a)
					if a.has("knockback"):
						e.push((e.position - origin).normalized() * a["knockback"] * 3.0)
			view.fx.add("ring", origin, col, 0.45, {"r": r})
		"chain":
			var hit := {}
			var cur: Node = target
			var from := origin
			for i in a.get("count", 3):
				if cur == null:
					break
				_hit(cur, a["damage"] * (1.0 - i * 0.1), a)
				view.fx.add("line", from, col, 0.25, {"pos2": cur.position})
				hit[cur] = true
				from = cur.position
				cur = _nearest(from, 150.0, hit)


func _shoot(a: Dictionary, origin: Vector2, angle: float, col: Color) -> void:
	var sp: float = a.get("speed", 400.0)
	projectiles.append({"pos": origin, "vel": Vector2.from_angle(angle) * sp, "damage": a["damage"],
		"life": a["range"] / sp + 0.1, "size": a.get("size", 6.0), "color": col, "friendly": true,
		"pierce": a.get("pierce", 0), "slow": a.get("slow", 0.0), "hit": {}, "src": a})


## Apply a player attack: crits, berserk, status effects, lifesteal. src is the attack spec
## (may carry slow / burn / stun / vulnerable); guard shots pass an empty dict.
func _hit(e: Node, dmg: float, src: Dictionary) -> void:
	var from_player := not src.is_empty()
	var crit := false
	if from_player:
		if Game.p["hp"] < Game.max_hp() * 0.5:
			dmg *= 1.0 + Game.stat("berserk")
		dmg *= 1.0 + Game.stat("damage_buff") # Battle Fury Pill
		if randf() < Game.stat("crit"):
			dmg *= 2.0
			crit = true
	var dealt: float = e.take_damage(dmg, src.get("slow", 0.0))
	if src.get("burn", 0.0) > 0.0:
		e.apply_burn(dealt * src["burn"])
	if src.get("stun", 0.0) > 0.0 and randf() < src["stun"]:
		e.apply_stun(0.6)
	if src.get("vulnerable", 0.0) > 0.0:
		e.apply_vulnerable(src["vulnerable"])
	if from_player and Game.stat("lifesteal") > 0.0:
		Game.p["hp"] = minf(Game.max_hp(), Game.p["hp"] + dealt * Game.stat("lifesteal"))
	if e == nemesis_actor and e.hp > 0.0 and e.hp < e.max_hp * 0.25 and not e.has_meta("escape_rolled"):
		e.set_meta("escape_rolled", true)
		if randf() < 0.5:
			view.fx.add("ring", e.position, Color("#ff1a4a"), 0.8, {"r": 70.0})
			view.fx.add("burst", e.position, Color("#ff1a4a"), 0.6)
			Game.nemesis_escaped(e.position)
			nemesis_actor = null
			e.queue_free()
			return
	var txt := str(roundi(dealt)) + ("!" if crit else "")
	view.fx.text(e.position + Vector2(randf_range(-8, 8), -e.radius - 6), txt, Color("#ffd76b") if crit else Color.WHITE, 0.6)


func _update_projectiles(delta: float) -> void:
	var ppos: Vector2 = Game.p["pos"]
	for pr in projectiles:
		pr["pos"] += pr["vel"] * delta
		pr["life"] -= delta
		var tile := Game.world.tile_at_pos(pr["pos"])
		if WorldData.SOLID.has(tile) and tile != WorldData.T.DEEP_WATER:
			pr["life"] = 0.0
		if pr["life"] <= 0.0:
			continue
		if pr["friendly"]:
			for e in enemies():
				if e.hp <= 0.0 or pr["hit"].has(e):
					continue
				if e.position.distance_to(pr["pos"]) < e.radius + pr["size"]:
					_hit(e, pr["damage"], pr.get("src", {}))
					pr["hit"][e] = true
					pr["pierce"] -= 1
					if pr["pierce"] < 0:
						pr["life"] = 0.0
						break
		elif ppos.distance_to(pr["pos"]) < 12.0 + pr["size"]:
			Game.hurt_player(pr["damage"], "ranged attack")
			pr["life"] = 0.0
	projectiles = projectiles.filter(func(pr): return pr["life"] > 0.0)


func _kill(e: Node) -> void:
	var d: Dictionary = e.def
	for dr in d["drops"]:
		if randf() < dr["chance"]:
			view.pickups.drop(e.position + Vector2(randf_range(-12, 12), randf_range(-12, 12)), dr["item"], randi_range(dr["min"], dr["max"]))
	var st := randi_range(d["stones"][0], d["stones"][1])
	if st > 0:
		view.pickups.drop(e.position, "", 0, st)
	if d.has("gu_drop") and randf() < d["gu_drop"]["chance"]:
		var pool: Array = d["gu_drop"]["pool"]
		var g: String = pool[randi() % pool.size()]
		var caught: Dictionary = Game.add_gu(g, false, "wild")
		if caught["shiny"]:
			Game.toast.emit("A SHINY %s! One in five hundred... (%s)" % [GuDB.GU[g]["name"], GuRoll.summary(caught)], "gold")
			view.fx.add("ring", e.position, Color("#ffd76b"), 1.2, {"r": 90.0})
		else:
			Game.toast.emit("You captured a wild %s! (%s)" % [GuDB.GU[g]["name"], GuRoll.summary(caught)], "gold")
	Game.p["kills"] += 1
	Game.on_enemy_killed(e.id, e.raider)
	if e == nemesis_actor:
		nemesis_actor = null
		Game.nemesis_defeated()
	view.fx.add("burst", e.position, Color.html(d["color"]), 0.5)
	if e.is_boss():
		Game.flags["bear_king_died"] = maxi(1, Game.day())
		Game.toast.emit("The %s has fallen! The mire trembles." % d["name"], "gold")
	Game.changed.emit()
	e.queue_free()


func _draw() -> void:
	for pr in projectiles:
		var c: Color = pr["color"]
		var p: Vector2 = pr["pos"]
		var s: float = pr["size"]
		if pr["friendly"]:
			# crescent: a bright arc facing the travel direction
			var ang: float = pr["vel"].angle()
			draw_arc(p, s, ang - 1.2, ang + 1.2, 12, c, maxf(2.0, s * 0.6))
			var glow := c
			glow.a = 0.25
			draw_circle(p, s * 1.2, glow)
		else:
			draw_circle(p, s, c)
