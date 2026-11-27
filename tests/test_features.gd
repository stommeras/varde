extends "res://tests/test_case.gd"

## The issue asks for seeds 0 to 4.
const FEATURE_SEEDS: int = 5


func test_lakes_are_large_main_island_lakes() -> void:
	for island_seed: int in FEATURE_SEEDS:
		var data: IslandData = island(island_seed)
		var covered := PackedByteArray()
		covered.resize(data.lake.size())
		for lake: PackedInt32Array in data.lakes:
			expect(lake.size() >= Features.MIN_LAKE_CELLS, "seed %d: a lake has only %d cells" % [island_seed, lake.size()])
			for i: int in lake:
				expect(data.lake[i] == 1 and data.main_island[i] == 1, "seed %d: lake cell %d is not a main island lake" % [island_seed, i])
				expect(covered[i] == 0, "seed %d: cell %d is in two lakes" % [island_seed, i])
				covered[i] = 1
		expect(data.lakes.size() >= 2 and data.lakes.size() <= 12, "seed %d has %d lakes" % [island_seed, data.lakes.size()])


## Finding the features again from the same island gives the same features. The thread test in
## test_generator.gd covers the steps before them.
func test_same_island_gives_same_features() -> void:
	for island_seed: int in FEATURE_SEEDS:
		var data: IslandData = island(island_seed)
		var again := IslandData.new()
		again.height = data.height
		again.material = data.material
		again.main_island = data.main_island
		again.rivers = data.rivers
		again.lake = data.lake
		Features.find(again)
		expect(again.lakes == data.lakes and again.river_forks == data.river_forks and again.coves == data.coves and again.forest == data.forest, "seed %d gave different features" % island_seed)


## A fork is where a river runs into an earlier one, so it lies on land on two rivers' cells.
func test_river_forks_lie_where_two_rivers_meet() -> void:
	for island_seed: int in FEATURE_SEEDS:
		var data: IslandData = island(island_seed)
		for fork: int in data.river_forks:
			expect(data.river_forks.count(fork) == 1, "seed %d: fork %d is listed twice" % [island_seed, fork])
			var rivers: int = 0
			for river: PackedInt32Array in data.rivers:
				if river.has(fork):
					rivers += 1
			expect(data.height[fork] > 0.0 and rivers >= 2, "seed %d: fork %d lies on %d rivers at height %f" % [island_seed, fork, rivers, data.height[fork]])
		expect(data.river_forks.size() >= 3 and data.river_forks.size() <= 30, "seed %d has %d river forks" % [island_seed, data.river_forks.size()])


## The forest is one connected area of forest cells on the main island, and a big one.
func test_forest_is_one_connected_area_of_forest() -> void:
	var size: int = IslandData.SIZE
	for island_seed: int in FEATURE_SEEDS:
		var data: IslandData = island(island_seed)
		var inside: Dictionary[int, bool] = {}
		for i: int in data.forest:
			expect(data.material[i] == Ramps.Terrain.FOREST and data.main_island[i] == 1, "seed %d: forest cell %d is not main island forest" % [island_seed, i])
			inside[i] = true
		expect(data.forest.size() >= 5000, "seed %d: the largest forest has only %d cells" % [island_seed, data.forest.size()])
		if data.forest.is_empty():
			continue
		var reached: Dictionary[int, bool] = {data.forest[0]: true}
		var stack: Array[int] = [data.forest[0]]
		while not stack.is_empty():
			var i: int = stack.pop_back()
			for n: int in [i - 1, i + 1, i - size, i + size]:
				if inside.has(n) and not reached.has(n) and absi(n % size - i % size) <= 1:
					reached[n] = true
					stack.append(n)
		expect(reached.size() == inside.size(), "seed %d: only %d of the forest's %d cells connect" % [island_seed, reached.size(), inside.size()])


## A cove is sea that the main island wraps round. From its middle cell, rays in at least 5 of the
## 8 directions reach the main island within COVE_REACH cells.
const COVE_REACH: int = 80


func test_coves_are_sea_the_main_island_wraps_round() -> void:
	var size: int = IslandData.SIZE
	for island_seed: int in FEATURE_SEEDS:
		var data: IslandData = island(island_seed)
		for cove: int in data.coves:
			expect(data.height[cove] <= 0.0 and data.main_island[cove] == 0, "seed %d: cove %d is not sea" % [island_seed, cove])
			var walled: int = 0
			for k: int in 8:
				var step := Vector2.from_angle(k * TAU / 8.0)
				for r: int in range(1, COVE_REACH):
					var at: Vector2i = Vector2i(IslandData.center(cove) + step * r)
					if at.x < 0 or at.y < 0 or at.x >= size or at.y >= size:
						break
					if data.main_island[IslandData.index(at.x, at.y)] == 1:
						walled += 1
						break
			expect(walled >= 5, "seed %d: cove %d is walled in %d of 8 directions" % [island_seed, cove, walled])
		expect(data.coves.size() >= 1 and data.coves.size() <= 15, "seed %d has %d coves" % [island_seed, data.coves.size()])
