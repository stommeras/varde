extends "res://tests/test_case.gd"


func test_every_cell_has_a_material_that_agrees_with_height() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		expect(data.material.size() == data.height.size(), "seed %d: material has %d cells" % [island_seed, data.material.size()])
		var invalid: int = 0
		var mismatched: int = 0
		for i: int in data.material.size():
			# FOAM is drawn by the shader, never stored in a cell.
			if data.material[i] >= Ramps.Terrain.FOAM:
				invalid += 1
			if (data.material[i] == Ramps.Terrain.WATER) != (data.height[i] <= 0.0):
				mismatched += 1
		expect(invalid == 0, "seed %d: %d cells have no valid material" % [island_seed, invalid])
		expect(mismatched == 0, "seed %d: %d cells disagree with height on land or water" % [island_seed, mismatched])


func test_moisture_spans_zero_to_one() -> void:
	for island_seed: int in SEEDS:
		var moisture: PackedFloat32Array = island(island_seed).moisture
		var lowest: float = INF
		var highest: float = -INF
		for m: float in moisture:
			lowest = minf(lowest, m)
			highest = maxf(highest, m)
		expect(lowest == 0.0 and highest == 1.0, "seed %d: moisture runs from %f to %f" % [island_seed, lowest, highest])
