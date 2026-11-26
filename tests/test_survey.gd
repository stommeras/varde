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
	expect(Survey.peak_in_reach(island, Vector2(100.5, 105.5), surveyed, Survey.MARKER_REACH) == 0, "a peak 5 cells away shows no ring")
	surveyed[0] = 1
	expect(Survey.peak_in_reach(island, Vector2(100.5, 100.5), surveyed) == -1, "a surveyed peak is in reach again")


## Pressing survey at the zone's edge walks the figure to a cell beside the top, so the varde can
## stand on the top itself, and every step of the way is one the player can take.
func test_the_walk_to_the_top_ends_beside_it() -> void:
	var island := IslandData.new()
	island.height.resize(IslandData.SIZE * IslandData.SIZE)
	island.height.fill(0.1)
	island.lake.resize(island.height.size())
	island.cliff.resize(island.height.size())
	var top: int = IslandData.index(CENTER, CENTER)
	# A wall west of the top, so the way has to go around it.
	for y: int in range(CENTER - 2, CENTER + 3):
		island.cliff[IslandData.index(CENTER - 1, y)] = 1
	var from: int = IslandData.index(CENTER - 3, CENTER)
	var path: PackedInt32Array = Survey.path_to_top(island, from, top)
	expect(path.size() > 1 and path[0] == from, "the walk doesn't start where the player stands")
	var last: int = path[-1]
	expect(last != top and absi(last % IslandData.SIZE - CENTER) <= 1 and absi(last / IslandData.SIZE - CENTER) <= 1, "the walk doesn't end beside the top")
	for i: int in path.size() - 1:
		expect(Walkability.can_step(island, path[i], path[i + 1]), "the walk takes a step the player can't")
	island.cliff.fill(0)
	for y: int in range(CENTER - 1, CENTER + 2):
		for x: int in range(CENTER - 1, CENTER + 2):
			island.cliff[IslandData.index(x, y)] = 1 if IslandData.index(x, y) != top else 0
	expect(Survey.path_to_top(island, from, top).is_empty(), "a walled-in top has a way up")


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


func test_varde_cells_are_the_surveyed_peaks() -> void:
	var survey := Survey.new()
	var island := IslandData.new()
	island.peaks = [Peak.new(IslandData.index(100, 100), 1.0, 1.0), Peak.new(IslandData.index(105, 100), 0.8, 0.5)]
	survey._island = island
	survey.surveyed = PackedByteArray([0, 1])
	expect(survey.varde_cells() == PackedInt32Array([IslandData.index(105, 100)]), "varde cells are %s" % [survey.varde_cells()])
	# Out of the tree, _ready never adopted these, so freeing the survey would leak them.
	survey._zone_ring.free()
	survey._prompt.free()
	survey.free()


func test_the_map_has_its_keys() -> void:
	for action: String in ["map", "zoom_in", "zoom_out"]:
		expect(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "%s lacks its key" % action)
