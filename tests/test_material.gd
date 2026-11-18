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


## Snow lies in fields, never in specks on the rock below them.
func test_no_snow_patch_is_a_speck() -> void:
	var size: int = IslandData.SIZE
	for island_seed: int in SEEDS:
		var material: PackedByteArray = island(island_seed).material
		var seen := PackedByteArray()
		seen.resize(material.size())
		var specks: int = 0
		for start: int in material.size():
			if seen[start] == 1 or material[start] != Ramps.Terrain.SNOW:
				continue
			seen[start] = 1
			var stack: PackedInt32Array = [start]
			var cells: int = 0
			while not stack.is_empty():
				var i: int = stack[-1]
				stack.resize(stack.size() - 1)
				cells += 1
				for dy: int in [-1, 0, 1]:
					for dx: int in [-1, 0, 1]:
						var n: int = i + dy * size + dx
						if seen[n] == 0 and material[n] == Ramps.Terrain.SNOW:
							seen[n] = 1
							stack.append(n)
			if cells < MaterialLookup.SNOW_PATCH_CELLS:
				specks += 1
		expect(specks == 0, "seed %d: %d patches of snow are smaller than %d cells" % [island_seed, specks, MaterialLookup.SNOW_PATCH_CELLS])


func test_moisture_spans_zero_to_one() -> void:
	for island_seed: int in SEEDS:
		var moisture: PackedFloat32Array = island(island_seed).moisture
		var lowest: float = INF
		var highest: float = -INF
		for m: float in moisture:
			lowest = minf(lowest, m)
			highest = maxf(highest, m)
		expect(lowest == 0.0 and highest == 1.0, "seed %d: moisture runs from %f to %f" % [island_seed, lowest, highest])
