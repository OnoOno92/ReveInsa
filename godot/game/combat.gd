extends Node2D
## Auto-combat: every active attack Gu fires on its own when a foe is in range,
## paying primeval essence. Also owns projectiles (drawn here) and enemy spawning.

const EnemyScript := preload("res://actors/enemy.gd")

var view: Node # world_view.gd
var projectiles: Array = [] # {pos, vel, damage, life, size, color, friendly, pierce, slow, hit: {}}
var timers := {}
var spawn_t := 0.0


func enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func clear_enemies(keep_boss := true) -> void:
	for e in enemies():
		if not (keep_boss and e.is_boss()):
			e.queue_free()
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
	_update_spawns(delta)
	_update_heals(delta)
	if not Game.world.is_safe(Game.p["pos"]):
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
		if not e.is_boss() and e.position.distance_to(ppos) > 1500.0:
			e.queue_free()
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	spawn_t = 1.3
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
					_hit(e, a["damage"], a.get("slow", 0.0))
			view.fx.add("ring", origin, col, 0.45, {"r": r})
		"chain":
			var hit := {}
			var cur: Node = target
			var from := origin
			for i in a.get("count", 3):
				if cur == null:
					break
				_hit(cur, a["damage"] * (1.0 - i * 0.1), a.get("slow", 0.0))
				view.fx.add("line", from, col, 0.25, {"pos2": cur.position})
				hit[cur] = true
				from = cur.position
				cur = _nearest(from, 150.0, hit)


func _shoot(a: Dictionary, origin: Vector2, angle: float, col: Color) -> void:
	var sp: float = a.get("speed", 400.0)
	projectiles.append({"pos": origin, "vel": Vector2.from_angle(angle) * sp, "damage": a["damage"],
		"life": a["range"] / sp + 0.1, "size": a.get("size", 6.0), "color": col, "friendly": true,
		"pierce": a.get("pierce", 0), "slow": a.get("slow", 0.0), "hit": {}})


func _hit(e: Node, dmg: float, slow: float) -> void:
	e.take_damage(dmg, slow)
	view.fx.text(e.position + Vector2(randf_range(-8, 8), -e.radius - 6), str(roundi(dmg)), Color.WHITE, 0.6)


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
					_hit(e, pr["damage"], pr["slow"])
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
		Game.add_gu(g)
		Game.toast.emit("You captured a wild %s!" % GuDB.GU[g]["name"], "gold")
	Game.p["kills"] += 1
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
