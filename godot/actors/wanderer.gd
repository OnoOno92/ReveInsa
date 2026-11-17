extends Node2D
## A friendly person walking the world (clan member, merchant, rogue). Talk to them.
## Moves toward their simulated target; pauses when the player is close.

var kind := "person" # for the world's interaction search
var data: Dictionary # the person (shared dict with Game.people)
var highlighted := false
var _t := 0.0
var _moving := false


func setup(pp: Dictionary) -> void:
	data = pp
	position = pp["pos"]


func _process(delta: float) -> void:
	_t += delta
	var near_player: bool = position.distance_to(Game.p["pos"]) < 110.0
	var to: Vector2 = data["target"] - position
	_moving = not near_player and to.length() > 6.0 and not get_tree().paused
	if _moving:
		var step: float = 70.0 * delta
		var nxt := position + to.normalized() * minf(step, to.length())
		if not Game.world.is_solid_pos(nxt):
			position = nxt
		else:
			data["target"] = position # blocked: give up on this target
	data["pos"] = position
	queue_redraw()


func _draw() -> void:
	var col := Color(People.AFFILIATION_COLORS[data["affiliation"]])
	var bob := sin(_t * 10.0) * 1.2 if _moving else 0.0
	draw_set_transform(Vector2(0, 7), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 10, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 7 + bob), Vector2(9, 7 + bob), Vector2(6, -10 + bob), Vector2(-6, -10 + bob)]), col.darkened(0.25))
	draw_rect(Rect2(-7, -2 + bob, 14, 3), col.lightened(0.3))
	draw_circle(Vector2(0, -15 + bob), 6, Color("#f1d6b8"))
	draw_arc(Vector2(0, -16 + bob), 6, PI, TAU, 12, Color("#2a2420"), 4.0)
	if data["affiliation"] == "shang":
		draw_rect(Rect2(6, -6 + bob, 8, 10), Color("#8a5a2b")) # merchant's pack
	var f := ThemeDB.fallback_font
	var label: String = data["name"]
	draw_string_outline(f, Vector2(-80, -28), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 11, 3, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(-80, -28), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 11, col.lightened(0.35))
	if highlighted:
		draw_arc(Vector2(0, -6), 18, 0, TAU, 24, Color(1, 0.94, 0.7, 0.9), 2.0)
