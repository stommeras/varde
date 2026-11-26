extends "res://tests/test_case.gd"

## Share of the main island's open land, off lakes and cliffs, the start must reach. On seeds 0 to 9
## the lowest was 96.9%.
const MIN_REACHABLE: float = 0.95


## The whole walk of seeds 0 to 4 takes about as long as generating them, so this test uses those.
func test_start_is_walkable_and_reaches_most_of_the_main_island() -> void:
	for island_seed: int in 5:
		var data: IslandData = island(island_seed)
		var start: int = data.start
		expect(start >= 0 and data.main_island[start] == 1 and data.material[start] == Ramps.Terrain.BEACH,
			"seed %d: the start cell %d is not a beach on the main island" % [island_seed, start])
		if start < 0:
			continue
		expect(not Walkability.blocked(data, start), "seed %d: the start cell is blocked" % island_seed)
		var land: int = 0
		for i: int in data.main_island.size():
			land += int(data.main_island[i] == 1 and not Walkability.blocked(data, i))
		var reached: PackedInt32Array = Walkability.reachable(data, start)
		var share: float = float(reached.size()) / land
		print("seed %d: %.1f%% of the main island's open land reachable" % [island_seed, share * 100.0])
		expect(share >= MIN_REACHABLE, "seed %d: only %.1f%% of the main island's open land is reachable" % [island_seed, share * 100.0])
		var off_island: int = 0
		for i: int in reached:
			off_island += 1 - data.main_island[i]
		expect(off_island == 0, "seed %d: %d reachable cells lie off the main island" % [island_seed, off_island])


## Rules on a hand-made patch of the first island, so each case doesn't depend on where the
## generator happened to put a cliff. The patch is 4 by 4 cells of flat land, with a, east, south
## and corner in its middle, so each of those four has all its neighbors in the patch.
func test_steps_block_water_lakes_and_cliffs() -> void:
	var data: IslandData = island(0)
	var size: int = IslandData.SIZE
	var a: int = data.start
	if a < 0:
		failures.append("seed 0 has no start cell to build the patch around")
		return
	var east: int = a + 1
	var south: int = a + size
	var corner: int = a + size + 1
	var saved: Dictionary[int, Array] = {}
	for dy: int in range(-1, 3):
		for dx: int in range(-1, 3):
			var i: int = a + dy * size + dx
			saved[i] = [data.height[i], data.lake[i], data.fresh_water[i], data.cliff[i]]
			data.height[i] = 0.1
			data.lake[i] = 0
			data.fresh_water[i] = 0
			data.cliff[i] = 0
	expect(Walkability.can_step(data, a, east), "a flat step blocks")
	expect(Walkability.can_step(data, a, corner), "a flat corner step blocks")
	expect(not Walkability.is_cliff(data, a), "flat land is a cliff")
	data.height[east] = 0.1 + Walkability.MAX_SLOPE * 1.01
	expect(Walkability.is_cliff(data, a) and Walkability.is_cliff(data, east), "a step past the walk limit doesn't make both its cells cliffs")
	data.height[east] = 0.1 + Walkability.MAX_SLOPE * 0.6
	data.height[south] = 0.1 + Walkability.MAX_SLOPE * 0.6
	data.height[corner] = 0.1 + Walkability.MAX_SLOPE * 1.3
	expect(not Walkability.is_cliff(data, a), "a corner step below the walk limit over its length makes a cliff")
	data.height[corner] = 0.1 + Walkability.MAX_SLOPE * 1.5
	expect(Walkability.is_cliff(data, a), "a corner step past the walk limit over its length makes no cliff")
	data.height[east] = 0.1
	data.height[south] = 0.1
	data.height[corner] = 0.1
	data.cliff[east] = 1
	expect(not Walkability.can_step(data, a, east), "a cliff is open")
	expect(not Walkability.can_step(data, a, corner), "a corner step slips past a cliff")
	data.cliff[east] = 0
	data.fresh_water[east] = 1
	expect(Walkability.can_step(data, a, east), "a river blocks")
	data.lake[east] = 1
	expect(not Walkability.can_step(data, a, east), "a lake is open")
	expect(not Walkability.can_step(data, a, corner), "a corner step slips past a lake")
	data.height[south] = 0.0
	expect(not Walkability.can_step(data, a, south), "the sea is open")
	for i: int in saved:
		data.height[i] = saved[i][0]
		data.lake[i] = saved[i][1]
		data.fresh_water[i] = saved[i][2]
		data.cliff[i] = saved[i][3]


## The generator's cliff grid is the one the final heights give, so the shader draws the cells
## walking blocks even after WaysUp raised some.
func test_cliffs_match_the_final_heights() -> void:
	for island_seed: int in [0, 7]:
		var data: IslandData = island(island_seed)
		var cliff: PackedByteArray = data.cliff
		Walkability.mark_cliffs(data)
		expect(data.cliff == cliff, "seed %d: the cliff grid doesn't match the heights" % island_seed)


## WaysUp raises cells after the start is placed, and must never turn the start into a cliff.
func test_start_stays_open_after_ways_up() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		expect(data.start >= 0 and not Walkability.blocked(data, data.start), "seed %d: the start is blocked" % island_seed)


## A lone cliff cell on open land clears, and a lone open cell walled in by cliffs fills.
func test_specks_and_pockets_clear() -> void:
	var data: IslandData = island(0)
	var size: int = IslandData.SIZE
	var cliff: PackedByteArray = data.cliff.duplicate()
	var lake: PackedByteArray = data.lake.duplicate()
	var middle: int = data.peaks[0].cell
	for dy: int in range(-8, 9):
		for dx: int in range(-8, 9):
			var i: int = middle + dy * size + dx
			data.lake[i] = 0
			data.cliff[i] = int(absi(dx) <= 4 and absi(dy) <= 4)
	data.cliff[middle] = 0
	var speck: int = middle + 7
	data.cliff[speck] = 1
	Walkability._clear_specks(data)
	expect(data.cliff[middle] == 1, "a walled-in pocket stays open")
	expect(data.cliff[speck] == 0, "a lone cliff cell stays")
	expect(data.cliff[middle + 4] == 1, "a big cliff patch clears")
	data.cliff = cliff
	data.lake = lake
