extends SceneTree
## Runs every test_*.gd in tests/. Usage: godot --headless -s tests/run.gd
## Exits with code 1 if any test fails.

const TestCase := preload("res://tests/test_case.gd")


func _init() -> void:
	var failed: int = 0
	var passed: int = 0
	for file: String in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed += 1
			printerr("FAIL %s: does not load" % file)
			continue
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.call(name)
			if case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for message: String in case.failures:
					printerr("FAIL %s::%s: %s" % [file, name, message])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
