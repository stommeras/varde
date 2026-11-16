extends "res://tests/test_case.gd"

func test_same_seed_gives_same_island() -> void:
	var a: IslandData = IslandGenerator.generate(7)
	var b: IslandData = island(7)
	expect(a.height == b.height, "seed 7 gave two different heights")
	expect(a.moisture == b.moisture, "seed 7 gave two different moistures")
	expect(a.material == b.material, "seed 7 gave two different materials")
	expect(a.main_island == b.main_island, "seed 7 gave two different main islands")


func test_different_seeds_differ() -> void:
	expect(island(7).height != island(8).height, "seeds 7 and 8 gave the same island")


func test_islands_have_sea_edges_and_a_summit() -> void:
	var size: int = IslandData.SIZE
	for island_seed: int in SEEDS:
		var height: PackedFloat32Array = island(island_seed).height
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
