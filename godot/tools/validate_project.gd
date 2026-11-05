extends SceneTree
## Loads scripts and scenes without executing a gameplay frame or visual test.

var failures: Array[String] = []
var script_count := 0
var scene_count := 0

func _initialize() -> void:
	call_deferred("_validate")

func _validate() -> void:
	_scan("res://scripts")
	_scan("res://scenes")
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_check(ResourceLoader.exists(main_path), "Main scene is missing")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer is required")
	if failures.is_empty():
		print("PASS structure: %d scripts, %d scenes; no gameplay frames executed" % [script_count, scene_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _scan(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_check(false, "Missing directory: " + path)
		return
	for name in directory.get_directories():
		_scan(path.path_join(name))
	for name in directory.get_files():
		var file_path := path.path_join(name)
		if name.ends_with(".gd"):
			var script := load(file_path) as GDScript
			_check(script != null and script.can_instantiate(), "Invalid script: " + file_path)
			script_count += 1
		elif name.ends_with(".tscn"):
			var scene := load(file_path) as PackedScene
			_check(scene != null, "Invalid scene: " + file_path)
			if scene != null:
				var instance := scene.instantiate()
				_check(instance != null, "Cannot instantiate scene: " + file_path)
				if instance != null:
					instance.process_mode = Node.PROCESS_MODE_DISABLED
					root.add_child(instance)
					root.remove_child(instance)
					instance.free()
			scene_count += 1

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
