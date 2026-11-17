extends SceneTree
## Compiles every .gd file in the project and reports the ones that fail.

func _initialize() -> void:
	var bad: Array[String] = []
	var files: Array[String] = []
	_collect("res://", files)
	for f in files:
		var s = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or not (s as GDScript).can_instantiate():
			bad.append(f)
	if bad.is_empty():
		print("check: OK (%d scripts compiled)" % files.size())
		quit(0)
	else:
		for f in bad:
			print("check: FAILED ", f)
		quit(1)

func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "addons":
			continue
		_collect(dir_path.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".gd") and f != "check_scripts.gd":
			out.append(dir_path.path_join(f))
