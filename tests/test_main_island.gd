extends "res://tests/test_case.gd"


## Labels the land areas with a flood fill of its own, so the test doesn't trust MainIsland's.
func test_exactly_one_main_island_and_it_is_the_largest() -> void:
	var size: int = IslandData.SIZE
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var visited := PackedByteArray()
		visited.resize(data.height.size())
		var largest: int = 0
		# Each entry is [cells, masked cells] for one land area that touches the mask.
		var masked_areas: Array[Vector2i] = []
		var masked_water: int = 0
		for start: int in data.height.size():
			if data.height[start] <= 0.0:
				masked_water += data.main_island[start]
				continue
			if visited[start] == 1:
				continue
			visited[start] = 1
			var stack: PackedInt32Array = [start]
			var cells: int = 0
			var masked: int = 0
			while not stack.is_empty():
				var i: int = stack[-1]
				stack.resize(stack.size() - 1)
				cells += 1
				masked += data.main_island[i]
				var x: int = i % size
				var y: int = i / size
				for neighbor: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= size or neighbor.y >= size:
						continue
					var n: int = IslandData.index(neighbor.x, neighbor.y)
					if visited[n] == 0 and data.height[n] > 0.0:
						visited[n] = 1
						stack.append(n)
			largest = maxi(largest, cells)
			if masked > 0:
				masked_areas.append(Vector2i(cells, masked))
		expect(masked_water == 0, "seed %d: %d water cells are on the main island" % [island_seed, masked_water])
		expect(masked_areas.size() == 1, "seed %d: the mask touches %d land areas" % [island_seed, masked_areas.size()])
		if masked_areas.size() == 1:
			var main: Vector2i = masked_areas[0]
			expect(main.x == main.y, "seed %d: the mask covers %d of the main island's %d cells" % [island_seed, main.y, main.x])
			expect(main.x == largest, "seed %d: the main island has %d cells, but the largest area has %d" % [island_seed, main.x, largest])
