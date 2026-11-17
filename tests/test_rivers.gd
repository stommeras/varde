extends "res://tests/test_case.gd"


## Every river must end in the sea, or on an earlier river that does, with no gaps along the way.
func test_every_river_reaches_the_sea() -> void:
	var size: int = IslandData.SIZE
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		expect(data.rivers.size() >= 5, "seed %d has only %d rivers" % [island_seed, data.rivers.size()])
		# The river each cell first belongs to, plus 1.
		var owner: Dictionary[int, int] = {}
		for r: int in data.rivers.size():
			var path: PackedInt32Array = data.rivers[r]
			var spring: int = path[0]
			expect(data.height[spring] >= Rivers.SPRING_HEIGHT and data.main_island[spring] == 1,
				"seed %d: river %d starts at height %f" % [island_seed, r, data.height[spring]])
			var mouth: int = path[-1]
			var joins: bool = owner.has(mouth) and owner[mouth] < r + 1
			expect(data.height[mouth] <= 0.0 or joins, "seed %d: river %d ends on land at height %f" % [island_seed, r, data.height[mouth]])
			for k: int in range(1, path.size()):
				var a: int = path[k - 1]
				var b: int = path[k]
				var apart: int = maxi(absi(a % size - b % size), absi(a / size - b / size))
				expect(apart == 1, "seed %d: river %d jumps %d cells at step %d" % [island_seed, r, apart, k])
				expect(data.fresh_water[a] == 1, "seed %d: river %d's cell %d is not fresh water" % [island_seed, r, a])
			for i: int in path:
				if not owner.has(i):
					owner[i] = r + 1
