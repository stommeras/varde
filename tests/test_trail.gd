extends "res://tests/test_case.gd"


func test_summit_and_a_contender_are_among_half_the_peaks_marked() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var marked: Dictionary[int, bool] = {}
		for top: int in data.varde_peaks:
			marked[top] = true
		expect(marked.has(data.peaks[0].cell), "seed %d: the summit has no line of vardes" % island_seed)
		var contenders: int = 0
		for top: int in marked:
			contenders += int(top != data.peaks[0].cell and data.contenders.has(top))
		expect(contenders >= 1, "seed %d: no contender besides the summit has a line" % island_seed)
		expect(marked.size() == ceili(data.peaks.size() / 2.0), "seed %d: %d of %d peaks marked" % [island_seed, marked.size(), data.peaks.size()])
		print("seed %d: %d old vardes on %d of %d peaks" % [island_seed, data.vardes.size(), marked.size(), data.peaks.size()])


func test_lines_climb_from_the_foot_to_just_below_the_top() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		for i: int in data.vardes.size():
			var varde: int = data.vardes[i]
			var top: int = data.varde_peaks[i]
			expect(data.height[varde] >= data.height[top] * Trail.FOOT_SHARE, "seed %d: varde %d stands in the lowland" % [island_seed, i])
			for peak: Peak in data.peaks:
				expect(_distance(varde, peak.cell) > Trail.PEAK_GAP, "seed %d: varde %d stands in reach of a peak's zone" % [island_seed, i])
			var last_of_line: bool = i == data.vardes.size() - 1 or data.varde_peaks[i + 1] != top
			if last_of_line:
				# The walk ends beside the top, so its last cell outside the gap lies within a step or two of it.
				expect(_distance(varde, top) <= Trail.PEAK_GAP + 2.0, "seed %d: the top varde of a line stands %.0f cells from its top" % [island_seed, _distance(varde, top)])
			else:
				expect(_distance(varde, data.vardes[i + 1]) >= Trail.GAP_MIN, "seed %d: vardes %d and %d stand too close" % [island_seed, i, i + 1])


func test_some_vardes_have_fallen_or_stand_hidden_in_forest() -> void:
	var kinds: Dictionary[int, int] = {}
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		expect(data.varde_kinds.size() == data.vardes.size() and data.varde_peaks.size() == data.vardes.size(), "seed %d: a kind and a peak per varde" % island_seed)
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
