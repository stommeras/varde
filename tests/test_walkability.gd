extends "res://tests/test_case.gd"

## Share of the main island's land cells the start must reach. Lakes and cliffs take the rest.
const MIN_REACHABLE: float = 0.85


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
			land += data.main_island[i]
		var reached: PackedInt32Array = Walkability.reachable(data, start)
		var share: float = float(reached.size()) / land
		print("seed %d: %.1f%% of the main island reachable" % [island_seed, share * 100.0])
		expect(share >= MIN_REACHABLE, "seed %d: only %.1f%% of the main island is reachable" % [island_seed, share * 100.0])
		var off_island: int = 0
		for i: int in reached:
			off_island += 1 - data.main_island[i]
		expect(off_island == 0, "seed %d: %d reachable cells lie off the main island" % [island_seed, off_island])


## Rules on a hand-made patch of the first island, so each case doesn't depend on where the
## generator happened to put a cliff.
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
	for i: int in [a, east, south, corner]:
		saved[i] = [data.height[i], data.lake[i], data.fresh_water[i]]
		data.height[i] = 0.1
		data.lake[i] = 0
		data.fresh_water[i] = 0
	expect(Walkability.can_step(data, a, east), "a flat step blocks")
	expect(Walkability.can_step(data, a, corner), "a flat corner step blocks")
	data.height[east] = 0.1 + Walkability.MAX_SLOPE * 1.01
	expect(not Walkability.can_step(data, a, east), "a step up past the cliff slope is open")
	expect(not Walkability.can_step(data, east, a), "a step down past the cliff slope is open")
	data.height[corner] = 0.1 + Walkability.MAX_SLOPE * 1.2
	data.height[east] = 0.1
	expect(Walkability.can_step(data, a, corner), "a corner step blocks below the cliff slope over its length")
	data.height[corner] = 0.1
	data.height[east] = 0.1 + Walkability.MAX_SLOPE * 2.0
	data.height[south] = 0.1 + Walkability.MAX_SLOPE * 2.0
	expect(not Walkability.can_step(data, a, corner), "a corner step slips between two cliffs")
	data.height[east] = 0.1
	data.height[south] = 0.1
	data.height[corner] = 0.1
	data.fresh_water[east] = 1
	expect(Walkability.can_step(data, a, east), "a river blocks")
	expect(Walkability.speed(data, east) == Walkability.WADE_SPEED, "wading a river is not slowed")
	data.lake[east] = 1
	expect(not Walkability.can_step(data, a, east), "a lake is open")
	expect(not Walkability.can_step(data, a, corner), "a corner step slips past a lake")
	data.height[south] = 0.0
	expect(not Walkability.can_step(data, a, south), "the sea is open")
	for i: int in saved:
		data.height[i] = saved[i][0]
		data.lake[i] = saved[i][1]
		data.fresh_water[i] = saved[i][2]
