extends CanvasLayer
## Title screen: continue or begin a new journey.

signal started(result: Dictionary)

var name_edit: LineEdit


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.theme = UITheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.035, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var t := Widgets.label("GU WILDS", 46, UITheme.PAPER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := Widgets.label("A Gu Master survival tale of the Southern Border", 15, UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var has := Game.has_save()
	if has:
		v.add_child(Widgets.button("Continue Journey", _continue, true, false, 18))
	name_edit = LineEdit.new()
	name_edit.text = "Shi Mo"
	name_edit.placeholder_text = "Your name"
	name_edit.max_length = 16
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_edit)
	v.add_child(Widgets.button("New Journey (overwrites save)" if has else "Begin Journey", _new, true, true, 18))
	var hint := Widgets.label("Move: WASD or drag on the left of the screen. Your Gu attack automatically.\nE/Space interact - Tab aperture - B bag - C refine - M map - Q absorb", 12, UITheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func _continue() -> void:
	if Game.load_game():
		started.emit({})
		Game.toast.emit.call_deferred("Welcome back, %s." % Game.p["name"], "gold")
	else:
		Game.toast.emit("Save could not be loaded.", "bad")


func _new() -> void:
	var n := name_edit.text.strip_edges()
	started.emit(Game.new_game(n if n != "" else "Shi Mo"))
