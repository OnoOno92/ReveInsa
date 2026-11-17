extends SceneTree
## Runs every res://tests/test_*.gd. Optional filter: -- <substring of file or method name>

func _initialize() -> void:
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		filter = user_args[0]
	var total := 0
	var failed: Array[String] = []
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (filter in f or filter in name):
				continue
			var t = script.new()
			t._current = "%s::%s" % [f, name]
			t.call(name)
			total += 1
			if t.failures.is_empty():
				print("  ok   ", t._current)
			else:
				for msg in t.failures:
					failed.append(msg)
					print("  FAIL ", msg)
	print("\n%d tests, %d failed" % [total, failed.size()])
	quit(1 if failed.size() > 0 else 0)
