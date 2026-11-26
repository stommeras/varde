extends "res://tests/test_case.gd"


func test_same_seed_gives_same_contenders() -> void:
	var again: IslandData = IslandGenerator.generate(0)
	expect(again.contenders == island(0).contenders, "seed 0 gave different contenders the second time")


## Every contender is still a peak after WaysUp, the summit comes first, and all of them stand in the
## band under it.
func test_contenders_lie_in_the_band() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var count: int = data.contenders.size()
		expect(count >= Contenders.MIN_COUNT and count <= Contenders.MAX_COUNT, "seed %d has %d contenders" % [island_seed, count])
		if count == 0:
			continue
		expect(data.contenders[0] == data.peaks[0].cell, "seed %d: the first contender is not the summit" % island_seed)
		var peak_cells := PackedInt32Array()
		for peak: Peak in data.peaks:
			peak_cells.append(peak.cell)
		var summit: float = data.height[data.contenders[0]]
		for cell: int in data.contenders.slice(1):
			expect(cell in peak_cells, "seed %d: the contender at %d is no longer a peak" % [island_seed, cell])
			var share: float = data.height[cell] / summit
			expect(share >= 1.0 - Contenders.MAX_BAND and share < 1.0, "seed %d: a contender stands at %f of the summit" % [island_seed, share])
