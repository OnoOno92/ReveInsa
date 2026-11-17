extends SceneTree
## Screenshot harness: loads a scene, lets it run N frames, saves the viewport.
## Args (after --): --scene=res://... --out=/abs/path.png --frames=30
## Any other --key=value args are exposed to the scene via the `Capture` meta on root:
##   get_tree().root.get_meta("capture_args", {})

var _frames := 30
var _out := ""
var _count := 0

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	_frames = int(args.get("frames", "30"))
	_out = args.get("out", "user://shot.png")
	root.set_meta("capture_args", args)
	var scene: PackedScene = load(args.get("scene", ProjectSettings.get_setting("application/run/main_scene")))
	if scene == null:
		push_error("capture: could not load scene")
		quit(1)
		return
	root.add_child(scene.instantiate())

func _process(_delta: float) -> bool:
	_count += 1
	if _count < _frames:
		return false
	var img := root.get_texture().get_image()
	var err := img.save_png(_out)
	print("capture: saved %s (%dx%d) err=%d" % [_out, img.get_width(), img.get_height(), err])
	return true
