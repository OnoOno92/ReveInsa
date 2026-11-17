extends Node2D
## Breakthrough tribulation: an arena storm themed by the player's dominant Dao path.
## Phase 1 (0-20s): telegraphed strikes + tribulation spirits.
## Phase 2 (20-40s): faster strikes, more spirits.
## Phase 3 (40s+): the Calamity Avatar appears - kill it to break through.
## Fail: falling (handled in Game.die), leaving the ring, or running out the 120s limit.

const RADIUS := 320.0
const LIMIT := 120.0
const PHASE_2 := 20.0
const PHASE_3 := 40.0

var view: Node # world_view
var active := false
var theme: Dictionary
var arena := Vector2.ZERO
var t := 0.0
var strikes: Array = [] # {pos, r, delay, t, landed, flash}
var _strike_t := 0.0
var _spirit_t := 0.0
var avatar: Node = null
var _outside_t := 0.0
var _color := Color.WHITE


func _ready() -> void:
	z_index = 4
	Game.tribulation_started.connect(_on_started)
	Game.tribulation_ended.connect(_on_ended)


func _on_started(th: Dictionary, at: Vector2) -> void:
	theme = th
	arena = at
	_color = Color(th["color"])
	active = true
	t = 0.0
	strikes.clear()
	_strike_t = 2.0 # a breath before the first strike
	_spirit_t = 3.0
	avatar = null
	_outside_t = 0.0
	view.combat.clear_enemies()


func _on_ended(_success: bool) -> void:
	active = false
	strikes.clear()
	for e in view.combat.enemies():
		if str(e.id).begins_with("trib_"):
			e.queue_free()
	Game.trib_status = ""


func rank() -> int:
	return int(theme.get("rank", 2))


func phase() -> int:
	if t >= PHASE_3:
		return 3
	return 2 if t >= PHASE_2 else 1


func _physics_process(delta: float) -> void:
	if not active:
		queue_redraw()
		return
	t += delta
	var ppos: Vector2 = Game.p["pos"]
	# Leaving the ring: a 2-second grace (knockback, a misstep) before it counts as fleeing.
	if ppos.distance_to(arena) > RADIUS + 20.0:
		if _outside_t <= 0.0:
			Game.toast.emit("Return to the ring, or Heaven will judge you a coward!", "bad")
		_outside_t += delta
		if _outside_t >= 2.0:
			if autopilot:
				print("tribulation: fled at %s (arena %s)" % [ppos, arena])
			Game.end_tribulation(false, "You fled the tribulation.")
			return
	else:
		_outside_t = 0.0
	if t >= LIMIT:
		Game.end_tribulation(false, "The tribulation outlasted you.")
		return
	if autopilot:
		_autopilot(ppos)
	_update_strikes(delta, ppos)
	_update_spirits(delta)
	if phase() == 3 and avatar == null:
		_spawn_avatar()
	elif avatar != null and (not is_instance_valid(avatar) or avatar.hp <= 0.0):
		Game.end_tribulation(true)
		return
	var left := ceili(LIMIT - t)
	Game.trib_status = "%s  %s  %ds" % [str(theme["name"]).trim_suffix(" Tribulation"), "%d/3" % phase() if phase() < 3 else "- slay the Avatar!", left]
	queue_redraw()


## Debug/balance: steer like a sensible player - leave warning circles, otherwise kite around the arena.
var autopilot := false
func _autopilot(ppos: Vector2) -> void:
	var dir := Vector2.ZERO
	for s in strikes:
		if not s["landed"] and ppos.distance_to(s["pos"]) < s["r"] + 12.0:
			dir += (ppos - s["pos"]).normalized()
	if dir == Vector2.ZERO:
		var rel := ppos - arena
		var tangent := Vector2(-rel.y, rel.x).normalized()
		var radial := (150.0 - rel.length()) / 150.0
		dir = tangent + rel.normalized() * radial
	Game.stick = dir.normalized()


func _update_strikes(delta: float, ppos: Vector2) -> void:
	_strike_t -= delta
	if _strike_t <= 0.0:
		_strike_t = [1.5, 0.85, 1.1][phase() - 1]
		var targeted := randf() < 0.6
		var pos := ppos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 40.0) if targeted \
			else arena + Vector2.from_angle(randf() * TAU) * randf_range(0.0, RADIUS - 40.0)
		strikes.append({"pos": pos, "r": randf_range(55.0, 80.0), "delay": 1.3 if phase() == 1 else 0.95, "t": 0.0, "landed": false})
	for s in strikes:
		s["t"] += delta
		if not s["landed"] and s["t"] >= s["delay"]:
			s["landed"] = true
			if ppos.distance_to(s["pos"]) <= s["r"]:
				var dmg: float = (12.0 + 10.0 * rank()) * (1.0 - clampf(Game.stat("trib_ward"), 0.0, 0.8))
				Game.note_tribulation_hit()
				Game.hurt_player(dmg, theme["name"])
			view.fx.add("ring", s["pos"], _color, 0.4, {"r": s["r"]})
	strikes = strikes.filter(func(s): return s["t"] < s["delay"] + 0.35)


func _update_spirits(delta: float) -> void:
	if phase() == 3:
		return
	_spirit_t -= delta
	if _spirit_t > 0.0:
		return
	_spirit_t = 6.0 if phase() == 1 else 4.5
	var alive: int = view.combat.enemies().filter(func(e): return e.id == "trib_spirit").size()
	for i in mini(2, 4 - alive):
		var pos := arena + Vector2.from_angle(randf() * TAU) * (RADIUS - 30.0)
		var e: Node = view.combat.spawn("trib_spirit", pos)
		e.max_hp = 20.0 + 15.0 * rank()
		e.hp = e.max_hp
		e.tint = _color
		e.dmg_scale = 0.6 + 0.3 * rank()


func _spawn_avatar() -> void:
	avatar = view.combat.spawn("trib_avatar", arena + Vector2(0, -RADIUS * 0.6))
	avatar.max_hp = 120.0 * pow(rank(), 1.4)
	avatar.hp = avatar.max_hp
	avatar.tint = _color
	avatar.display_name = theme["avatar"]
	avatar.dmg_scale = 0.55 + 0.3 * rank()
	view.fx.add("ring", avatar.position, _color, 1.2, {"r": 140.0})
	Game.toast.emit("The %s descends. Destroy it to break through!" % theme["avatar"], "bad")


func _draw() -> void:
	if not active:
		return
	# the arena ring
	var ring := _color
	ring.a = 0.6 + 0.3 * sin(t * 3.0)
	draw_arc(arena, RADIUS, 0, TAU, 96, ring, 4.0)
	var haze := _color
	haze.a = 0.05
	draw_circle(arena, RADIUS, haze)
	# telegraphed strikes: a filling warning circle, then a bolt from the sky
	for s in strikes:
		var k: float = clampf(s["t"] / s["delay"], 0.0, 1.0)
		if not s["landed"]:
			draw_circle(s["pos"], s["r"], Color(1, 0.2, 0.2, 0.10 + 0.15 * k))
			draw_arc(s["pos"], s["r"], 0, TAU, 32, Color(1, 0.35, 0.3, 0.8), 2.0)
			draw_arc(s["pos"], s["r"] * k, 0, TAU, 32, Color(1, 0.6, 0.4, 0.9), 2.0)
		else:
			var a: float = 1.0 - (s["t"] - s["delay"]) / 0.35
			var bolt := _color.lightened(0.4)
			bolt.a = a
			var top: Vector2 = s["pos"] + Vector2(randf_range(-30, 30), -420)
			var pts := PackedVector2Array([top])
			for i in range(1, 6):
				pts.append(top.lerp(s["pos"], i / 6.0) + Vector2(randf_range(-14, 14), 0))
			pts.append(s["pos"])
			draw_polyline(pts, bolt, 5.0)
			var glow := _color
			glow.a = 0.35 * a
			draw_circle(s["pos"], s["r"], glow)
