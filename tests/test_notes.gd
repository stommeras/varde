extends "res://tests/test_case.gd"


## ConfigFile turns a malformed value into null without an error, so a typo in a template would
## only show as a blank note in play.
func test_every_template_loads_as_a_string() -> void:
	var file := ConfigFile.new()
	expect(file.load(Notes.path(Notes.LANGUAGE)) == OK, "notes/%s.cfg doesn't load" % Notes.LANGUAGE)
	expect(file.get_value("compass", "words", []).size() == 8, "the compass doesn't have 8 words")
	for word: Variant in file.get_value("compass", "words", []):
		expect(word is String, "a compass word is %s" % [word])
	for key: String in file.get_section_keys("nouns"):
		var forms: Variant = file.get_value("nouns", key)
		expect(forms is Array and forms.size() == 2 and forms[0] is String and forms[1] is String, "noun %s isn't an indefinite and a definite form" % key)
	expect(file.get_value("varde", "opening") is String, "the varde's opening is %s" % [file.get_value("varde", "opening")])
	var slots: Dictionary = {"direction": "nord", "feature": "et vann", "the_feature": "vannet"}
	for key: String in file.get_section_keys("templates"):
		var templates: Variant = file.get_value("templates", key)
		expect(templates is Array and not templates.is_empty(), "templates %s is %s" % [key, templates])
		if templates is Array:
			for template: Variant in templates:
				expect(template is String, "a template for %s is %s" % [key, template])
				if template is String:
					expect(not template.format(slots).contains("{"), "a template for %s has an unknown slot: %s" % [key, template])
					expect(not template.begins_with("{"), "a template for %s starts with a slot, which the writer doesn't capitalize: %s" % [key, template])
	for kind: String in ["wreck", "summit", "direction", "lake", "river", "fork", "cove", "forest"]:
		expect(file.has_section_key("templates", kind), "no templates for %s" % kind)


func test_the_wreck_and_each_line_top_hold_a_note() -> void:
	var file := ConfigFile.new()
	file.load(Notes.path(Notes.LANGUAGE))
	var opening: String = file.get_value("varde", "opening")
	var words: Array = file.get_value("compass", "words")
	var named: int = 0
	var below_summit: int = 0
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var tops := PackedInt32Array([data.wreck])
		for i: int in data.vardes.size():
			if i == data.vardes.size() - 1 or data.varde_peaks[i + 1] != data.varde_peaks[i]:
				tops.append(data.vardes[i])
		expect(PackedInt32Array(data.notes.keys()) == tops, "seed %d: notes lie on %s, not the wreck and the tops %s" % [island_seed, data.notes.keys(), tops])
		expect(file.get_value("templates", "wreck").has(data.notes.get(data.wreck)), "seed %d: the wreck's note is %s" % [island_seed, data.notes.get(data.wreck)])
		for i: int in data.vardes.size():
			var cell: int = data.vardes[i]
			if not data.notes.has(cell):
				continue
			var note: String = data.notes[cell]
			var top: int = data.varde_peaks[i]
			expect(note.begins_with(opening), "seed %d: varde %d's note doesn't open as a varde's" % [island_seed, i])
			if top == data.peaks[0].cell:
				expect(file.get_value("templates", "summit").has(note.trim_prefix(opening)), "seed %d: the summit line's note doesn't say none stands higher" % island_seed)
			else:
				var word: String = words[Notes.compass(top, Trail.higher_peak(data, top))]
				expect(note.to_lower().contains("mot %s" % word), "seed %d: varde %d's note doesn't name %s: %s" % [island_seed, i, word, note])
				below_summit += 1
				var plain: Array = file.get_value("templates", "direction").map(func(template: String) -> String: return template.format({"direction": word}))
				named += int(not plain.has(note.trim_prefix(opening)))
			if island_seed < 2:
				print("seed %d, peak %d (%.0f m): %s" % [island_seed, top, IslandData.meters(data.height[top]), note.trim_prefix(opening)])
	print("%d of %d notes below the summit name a feature on seeds 0 to %d" % [named, below_summit, SEEDS - 1])
	# A feature lies within reach of nearly every peak, so most notes should name one.
	expect(named * 2 >= below_summit, "only %d of %d notes name a feature" % [named, below_summit])


## The writer picks sentences it hasn't used on the island yet, and each list holds more sentences
## than an island has notes, so no sentence shows up twice on one island.
func test_no_sentence_repeats_on_an_island() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var seen: Dictionary[String, bool] = {}
		for cell: int in data.notes:
			for sentence: String in data.notes[cell].split("\n\n")[-1].split(". ", false):
				expect(not seen.has(sentence), "seed %d: \"%s\" shows up twice" % [island_seed, sentence])
				seen[sentence] = true
