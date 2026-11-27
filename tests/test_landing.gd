extends "res://tests/test_case.gd"


func test_route_walks_from_the_start_to_beside_the_summit() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var route: PackedInt32Array = data.route
		if route.is_empty():
			failures.append("seed %d: no route to the summit" % island_seed)
			continue
		expect(route[0] == data.start, "seed %d: the route doesn't start at the start" % island_seed)
		var top: int = data.peaks[0].cell
		var last: int = route[-1]
		expect(absi(last % IslandData.SIZE - top % IslandData.SIZE) <= 1 and absi(last / IslandData.SIZE - top / IslandData.SIZE) <= 1,
			"seed %d: the route ends at %d, not beside the summit at %d" % [island_seed, last, top])
		var refused: int = 0
		for i: int in range(1, route.size()):
			refused += int(not Walkability.can_step(data, route[i - 1], route[i]))
		expect(refused == 0, "seed %d: %d steps of the route can't be walked" % [island_seed, refused])
		print("seed %d: route of %d cells, start %.0f cells from the summit" % [island_seed, route.size(), _distance(data.start, top)])


func test_wreck_lies_on_the_shore_beside_the_start() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var wreck: int = data.wreck
		expect(data.main_island[wreck] == 1 and data.material[wreck] == Ramps.Terrain.BEACH,
			"seed %d: the wreck at %d is not on a beach of the main island" % [island_seed, wreck])
		var shore: bool = false
		for offset: int in [-1, 1, -IslandData.SIZE, IslandData.SIZE]:
			shore = shore or data.height[wreck + offset] <= 0.0
		expect(shore, "seed %d: the wreck doesn't touch the sea" % island_seed)
		expect(_distance(wreck, data.start) <= Landing.READ_REACH, "seed %d: the start is out of the wreck's reach" % island_seed)


func _distance(a: int, b: int) -> float:
	return Vector2(a % IslandData.SIZE, a / IslandData.SIZE).distance_to(Vector2(b % IslandData.SIZE, b / IslandData.SIZE))


func test_compass_counts_clockwise_from_north() -> void:
	var size: int = IslandData.SIZE
	var middle: int = IslandData.index(500, 500)
	expect(Reading.compass(middle, middle - 90 * size) == 0, "north isn't 0")
	expect(Reading.compass(middle, middle - 60 * size + 60) == 1, "north-east isn't 1")
	expect(Reading.compass(middle, middle + 100) == 2, "east isn't 2")
	expect(Reading.compass(middle, middle + 80 * size) == 4, "south isn't 4")
	expect(Reading.compass(middle, middle - 70) == 6, "west isn't 6")
	expect(Reading.compass(middle, middle - 50 * size - 50) == 7, "north-west isn't 7")
