extends "res://tests/test_case.gd"


func test_same_seed_gives_same_peaks() -> void:
	var data: IslandData = island(0)
	var again: IslandData = IslandGenerator.generate(0)
	expect(peaks_text(again.peaks) == peaks_text(data.peaks), "seed 0 gave different peaks the second time")


func test_summit_is_a_peak_and_every_peak_is_valid() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var highest: float = 0.0
		for i: int in data.height.size():
			if data.main_island[i] == 1:
				highest = maxf(highest, data.height[i])
		expect(not data.peaks.is_empty(), "seed %d has no peaks" % island_seed)
		if data.peaks.is_empty():
			continue
		expect(data.peaks[0].height == highest, "seed %d: the highest peak is %f, the highest cell %f" % [island_seed, data.peaks[0].height, highest])
		for peak: Peak in data.peaks:
			expect(data.main_island[peak.cell] == 1, "seed %d: a peak is off the main island" % island_seed)
			expect(data.height[peak.cell] == peak.height, "seed %d: a peak's height is not its cell's" % island_seed)
			expect(peak.prominence >= Peaks.MIN_PROMINENCE * highest and peak.prominence <= peak.height,
				"seed %d: a peak of height %f has prominence %f" % [island_seed, peak.height, peak.prominence])


## A ridge with a summit of 1.0, a second peak of 0.6, and a knoll of 0.35 beside the second. The two
## cones meet at 0.3, so the second peak rises 0.3 and the knoll only about 0.05, below the 15% cut.
func test_prominence_on_a_ridge() -> void:
	var size: int = IslandData.SIZE
	var height := PackedFloat32Array()
	height.resize(size * size)
	var main_island := PackedByteArray()
	main_island.resize(size * size)
	for y: int in range(400, 411):
		for x: int in range(100, 901):
			var h: float = maxf(0.05, maxf(1.0 - 0.002 * absf(x - 200), maxf(0.6 - 0.002 * absf(x - 700), 0.35 - 0.05 * absf(x - 850))))
			height[IslandData.index(x, y)] = h
			main_island[IslandData.index(x, y)] = 1
	var peaks: Array[Peak] = Peaks.generate(height, main_island)
	expect(peaks.size() == 2, "the ridge gave %d peaks" % peaks.size())
	if peaks.size() == 2:
		expect(is_equal_approx(peaks[0].prominence, 1.0), "summit prominence is %f" % peaks[0].prominence)
		expect(peaks[1].cell % size == 700, "second peak is at column %d" % (peaks[1].cell % size))
		expect(absf(peaks[1].prominence - 0.3) < 0.001, "second peak prominence is %f, not 0.3" % peaks[1].prominence)
