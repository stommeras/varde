extends "res://tests/test_case.gd"

## A varde stands on the first route cell past its drawn reach, so a gap can overshoot by one
## diagonal step.
const STEP: float = 1.5


func test_trail_lies_on_the_route_at_the_spec_spacing() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var vardes: PackedInt32Array = data.vardes
		expect(vardes.size() >= 5 and vardes.size() <= 10, "seed %d: %d old vardes" % [island_seed, vardes.size()])
		if vardes.is_empty():
			continue
		var first: float = _distance(vardes[0], data.wreck)
		expect(first >= 60.0 and first <= 120.0 + STEP, "seed %d: the first varde is %.0f cells from the wreck" % [island_seed, first])
		var last_index: int = -1
		for i: int in vardes.size():
			var at: int = data.route.find(vardes[i])
			expect(at > last_index, "seed %d: varde %d is off the route or out of order" % [island_seed, i])
			last_index = at
			for peak: Peak in data.peaks:
				expect(_distance(vardes[i], peak.cell) > Trail.PEAK_GAP, "seed %d: varde %d stands in reach of a peak's zone" % [island_seed, i])
			if i > 0:
				var gap: float = _distance(vardes[i], vardes[i - 1])
				expect(gap >= 40.0 and gap <= 60.0 + STEP, "seed %d: varde %d is %.0f cells from the one before" % [island_seed, i, gap])
		expect(_distance(vardes[-1], data.peaks[0].cell) >= 40.0, "seed %d: the last varde stands by the summit" % island_seed)
		print("seed %d: %d old vardes" % [island_seed, vardes.size()])


func test_some_vardes_have_fallen_or_stand_hidden_in_forest() -> void:
	var kinds: Dictionary[int, int] = {}
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		expect(data.varde_kinds.size() == data.vardes.size(), "seed %d: a kind per varde" % island_seed)
		if data.varde_kinds.is_empty():
			continue
		expect(data.varde_kinds[0] == Trail.Kind.STANDING, "seed %d: the varde seen from the wreck isn't standing" % island_seed)
		for i: int in data.varde_kinds.size():
			var kind: int = data.varde_kinds[i]
			kinds[kind] = kinds.get(kind, 0) + 1
			if kind == Trail.Kind.HIDDEN:
				expect(data.material[data.vardes[i]] == Ramps.Terrain.FOREST, "seed %d: hidden varde %d is not in forest" % [island_seed, i])
	print("kinds over seeds: %s" % kinds)
	for kind: int in Trail.Kind.values():
		expect(kinds.get(kind, 0) > 0, "no varde of kind %d on seeds 0 to 9" % kind)


func _distance(a: int, b: int) -> float:
	return IslandData.center(a).distance_to(IslandData.center(b))


func test_each_note_points_to_the_next_varde_and_the_last_to_the_summit() -> void:
	var data: IslandData = island(0)
	var reading := Reading.new()
	reading.start(data)
	var vardes: PackedInt32Array = data.vardes
	for i: int in vardes.size():
		var next: int = data.peaks[0].cell if i == vardes.size() - 1 else vardes[i + 1]
		var word: String = reading.tr("COMPASS_%d" % Reading.compass(vardes[i], next))
		expect(reading.note_at(vardes[i]).ends_with(word + "."), "varde %d's note doesn't name %s" % [i, word])
	expect(reading.note_at(vardes[-1]) != reading.note_at(vardes[0]), "the last note reads like the others")
	reading.free()
