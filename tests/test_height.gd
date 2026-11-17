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


## A gap or dip in the terrace would put a seam or a ditch along every ledge.
func test_terrace_is_continuous_and_rising() -> void:
	var previous: float = Height._terrace(-1.0)
	for k: int in range(1, 20001):
		var v: float = -1.0 + k * 0.0001
		var t: float = Height._terrace(v)
		expect(t >= previous and t - previous < 0.001, "terrace jumps from %f to %f at %f" % [previous, t, v])
		previous = t


## Fine noise octaves put a small top on every bump. Before #31 the high ground had 150 to 370
## local tops per island. With smooth lowland and craggy tops on the big mountains it had 17 to 51
## on seeds 0 to 9, and with the eroded ridges of #33 it has 46 to 90.
func test_high_ground_has_few_tops() -> void:
	# Room for crags on the big mountains, but well under the 150 tops of the old bumpy terrain.
	const MAX_TOPS: int = 100
	var size: int = IslandData.SIZE
	for island_seed: int in SEEDS:
		var height: PackedFloat32Array = island(island_seed).height
		var tops: int = 0
		for y: int in range(1, size - 1):
			for x: int in range(1, size - 1):
				var h: float = height[IslandData.index(x, y)]
				if h < 0.3:
					continue
				var top: bool = true
				for ny: int in range(y - 1, y + 2):
					for nx: int in range(x - 1, x + 2):
						if (nx != x or ny != y) and height[IslandData.index(nx, ny)] >= h:
							top = false
				if top:
					tops += 1
		expect(tops <= MAX_TOPS, "seed %d: %d tops above 0.3, more than %d" % [island_seed, tops, MAX_TOPS])
