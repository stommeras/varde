extends "res://tests/test_case.gd"


## The pause menu draws its keys from a list of its own, so a rebinding in the project settings would
## leave it showing the wrong keys.
func test_every_key_shown_is_bound_to_its_row() -> void:
	for row: Dictionary in PauseMenu.CONTROLS:
		var actions: Array = row["actions"]
		for group: Array in row["keys"]:
			for keys: Array in group:
				for key: Key in keys:
					expect(actions.any(func(action: StringName) -> bool: return _bound(action, key)),
							"%s is shown for %s but not bound to it" % [OS.get_keycode_string(key), row["text"]])


## Every action a row names must show at least one key, or the menu hides how to do it.
func test_every_action_shown_has_a_key() -> void:
	for row: Dictionary in PauseMenu.CONTROLS:
		for action: StringName in row["actions"]:
			var shown: bool = false
			for group: Array in row["keys"]:
				for keys: Array in group:
					for key: Key in keys:
						shown = shown or _bound(action, key)
			expect(shown, "%s shows no key for %s" % [row["text"], action])


func _bound(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event.physical_keycode == key or event.keycode == key):
			return true
	return false
