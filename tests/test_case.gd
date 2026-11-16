extends RefCounted
## Base for test files. Extend it by path, write methods named test_*, and call expect().

var failures: PackedStringArray = []


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
