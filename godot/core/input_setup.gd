class_name InputSetup
extends RefCounted
## Registers input actions in code so the project works without editor-configured input maps.
## (They can also be edited later in Project Settings > Input Map; existing actions are kept.)

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"interact": [KEY_E, KEY_SPACE],
	"open_aperture": [KEY_TAB, KEY_I],
	"open_bag": [KEY_B],
	"open_craft": [KEY_C],
	"open_map": [KEY_M],
	"absorb": [KEY_Q],
	"rotate": [KEY_R],
	"cancel": [KEY_ESCAPE],
}


static func ensure() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
