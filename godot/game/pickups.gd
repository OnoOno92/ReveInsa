extends Node2D
## Loot on the ground. Magnetized toward the player, collected on touch.

var view: Node
var items: Array = [] # {pos, item, count, stones, t}
var _clock := 0.0


func drop(pos: Vector2, item: String, count: int, stones := 0) -> void:
	items.append({"pos": pos, "item": item, "count": count, "stones": stones, "t": 0.0})


func clear() -> void:
	items.clear()


func _physics_process(delta: float) -> void:
	_clock += delta
	var ppos: Vector2 = Game.p["pos"]
	var mag := 60.0 + Game.stat("pickup")
	var got := false
	for k in items:
		k["t"] += delta
		var to: Vector2 = ppos - k["pos"]
		var d := to.length()
		if k["t"] > 0.3 and d < mag:
			k["pos"] += to * minf(1.0, 360.0 * delta / maxf(d, 0.001))
		if d < 16.0 and k["t"] > 0.3:
			if k["stones"] > 0:
				Game.p["stones"] += k["stones"]
				view.fx.text(ppos + Vector2(0, -20), "+%d stones" % k["stones"], Color.html("#9be7ff"))
			if k["item"] != "":
				Game.add_item(k["item"], k["count"])
				view.fx.text(ppos + Vector2(0, -20), "+%d %s" % [k["count"], ItemDB.ITEMS[k["item"]]["name"]], Color.html("#ffe9a8"))
			k["t"] = -999.0
			got = true
	items = items.filter(func(k): return k["t"] >= 0.0 and k["t"] < 120.0)
	if got:
		Game.changed.emit()
	queue_redraw()


func _draw() -> void:
	for k in items:
		var bob := sin(_clock * 4.0 + k["pos"].x) * 2.0
		var p: Vector2 = k["pos"] + Vector2(0, bob)
		if k["stones"] > 0:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)]), Color.html("#9be7ff"))
		elif k["item"] != "":
			draw_circle(p, 5.5, Color(0, 0, 0, 0.5))
			draw_circle(p, 4.5, ItemDB.color(k["item"]))
