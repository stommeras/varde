extends "res://tests/test_case.gd"


func test_notes_are_named_in_the_order_read() -> void:
	var wreck: int = 40
	var titles: PackedStringArray = MapScreen.note_titles(PackedInt32Array([7, wreck, 9]), wreck)
	expect(titles == PackedStringArray(["Lapp 1", "Skipsloggen", "Lapp 2"]), "the notes are named %s" % ", ".join(titles))
