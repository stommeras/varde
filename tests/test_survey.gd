extends "res://tests/test_case.gd"

const CENTER: int = 512


func test_a_survey_reaches_twice_the_walking_radius() -> void:
	var island := IslandData.new()
	island.height.resize(IslandData.SIZE * IslandData.SIZE)
	var cell: int = IslandData.index(CENTER, CENTER)
	var walk: int = LineOfSight.visible_cells(island, cell).size()
	var rings: Array[PackedInt32Array] = Survey.rings(island, cell)
	var seen := {}
	var total: int = 0
	for band: PackedInt32Array in rings:
		total += band.size()
		for index: int in band:
			seen[index] = true
	expect(rings.size() == Survey.RINGS, "the survey has %d bands" % rings.size())
	expect(total == seen.size(), "a cell lies in two bands")
	var far: int = int(LineOfSight.SEA_RADIUS * Survey.REACH_SCALE) - 2
	expect(seen.has(IslandData.index(CENTER + far, CENTER)), "a cell near twice the walking radius is not surveyed")
	expect(total > 3 * walk, "the survey reaches %d cells against %d walking" % [total, walk])
	expect(rings[0].has(cell) and not rings[Survey.RINGS - 1].is_empty() and not rings[Survey.RINGS - 1].has(cell), "the bands don't run from the peak outward")


func test_only_unsurveyed_peaks_in_their_zone_are_in_reach() -> void:
	var island := IslandData.new()
	island.peaks = [Peak.new(IslandData.index(100, 100), 1.0, 1.0), Peak.new(IslandData.index(105, 100), 0.8, 0.5)]
	var surveyed := PackedByteArray([0, 0])
	expect(Survey.peak_in_reach(island, Vector2(100.5, 100.5), surveyed) == 0, "the peak underfoot is out of reach")
	expect(Survey.peak_in_reach(island, Vector2(103.5, 100.5), surveyed) == 1, "the nearer of two zones isn't chosen")
	expect(Survey.peak_in_reach(island, Vector2(100.5, 105.5), surveyed) == -1, "a peak 5 cells away is in reach")
	expect(Survey.peak_in_reach(island, Vector2(100.5, 105.5), surveyed, Survey.CIRCLE_REACH) == 0, "a peak 5 cells away shows no circle")
	surveyed[0] = 1
	expect(Survey.peak_in_reach(island, Vector2(100.5, 100.5), surveyed) == -1, "a surveyed peak is in reach again")


func test_survey_has_its_key() -> void:
	expect(InputMap.has_action("survey") and InputMap.action_get_events("survey").size() == 1, "survey lacks its key")


func test_a_varde_builds_bottom_first() -> void:
	var varde := Varde.new(3)
	varde.build(0.5)
	var shown: Array[bool] = []
	for stone: Node in varde.get_children():
		shown.append((stone as MeshInstance3D).visible)
	var half: int = roundi(shown.size() / 2.0)
	expect(shown.size() > Varde.LAYERS.size(), "a varde has one stone per layer")
	expect(shown.count(true) == half and not shown.slice(0, half).has(false), "half a varde shows %s" % [shown])
	varde.free()
