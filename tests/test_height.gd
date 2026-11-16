extends "res://tests/test_case.gd"

const SEEDS: int = 10


func test_same_seed_gives_same_height() -> void:
	expect(IslandGenerator.generate(7).height == IslandGenerator.generate(7).height, "seed 7 gave two different islands")


func test_different_seeds_differ() -> void:
	expect(IslandGenerator.generate(7).height != IslandGenerator.generate(8).height, "seeds 7 and 8 gave the same island")


func test_islands_have_sea_edges_and_a_summit() -> void:
	var size: int = IslandData.SIZE
	for island_seed: int in SEEDS:
		var height: PackedFloat32Array = IslandGenerator.generate(island_seed).height
		var land: int = 0
		var highest: float = -INF
		for h: float in height:
			if h > 0.0:
				land += 1
			highest = maxf(highest, h)
		var land_share: float = float(land) / height.size()
		expect(highest == 1.0, "seed %d: summit is %f, not 1.0" % [island_seed, highest])
		expect(land_share > 0.15 and land_share < 0.6, "seed %d: land share is %.2f" % [island_seed, land_share])
		var border_land: int = 0
		for i: int in size:
			for cell: int in [IslandData.index(i, 0), IslandData.index(i, size - 1), IslandData.index(0, i), IslandData.index(size - 1, i)]:
				if height[cell] >= 0.0:
					border_land += 1
		expect(border_land == 0, "seed %d: %d border cells are land" % [island_seed, border_land])
