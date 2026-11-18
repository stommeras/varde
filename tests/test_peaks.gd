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
		# One peak per massif, so a massif lost to a high saddle or an islet shows up here.
		expect(data.peaks.size() >= Massifs.MIN_COUNT and data.peaks.size() <= Massifs.MAX_COUNT, "seed %d has %d peaks" % [island_seed, data.peaks.size()])
		for peak: Peak in data.peaks:
			expect(data.main_island[peak.cell] == 1, "seed %d: a peak is off the main island" % island_seed)
			expect(data.height[peak.cell] == peak.height, "seed %d: a peak's height is not its cell's" % island_seed)
			expect(peak.prominence >= Peaks.MIN_PROMINENCE * highest and peak.prominence <= peak.height,
				"seed %d: a peak of height %f has prominence %f" % [island_seed, peak.height, peak.prominence])


## The player must be able to walk from the start to every top, through the way up past the walls.
func test_every_peak_is_reachable_from_the_start() -> void:
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var reached := PackedByteArray()
		reached.resize(data.height.size())
		for cell: int in Walkability.reachable(data, data.start):
			reached[cell] = 1
		for peak: Peak in data.peaks:
			expect(reached[peak.cell] == 1, "seed %d: the peak at %d can't be reached from the start" % [island_seed, peak.cell])


## Each peak is one pointed top. A broad dome put its highest cell at one end, so the survey ring sat
## on a shoulder while a top 0.05 lower looked taller. Every cell near a peak is lower, and the land
## 10 to 15 cells out stands at least 0.03 (3 world units) under it.
func test_each_peak_has_one_clear_top() -> void:
	const NEAR: int = 15
	const SHOULDER: int = 10
	const DROP: float = 0.03
	var size: int = IslandData.SIZE
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		for peak: Peak in data.peaks:
			var shoulder: float = -INF
			var ties: int = 0
			for dy: int in range(-NEAR, NEAR + 1):
				for dx: int in range(-NEAR, NEAR + 1):
					var d2: int = dx * dx + dy * dy
					if d2 == 0 or d2 > NEAR * NEAR:
						continue
					var h: float = data.height[peak.cell + dy * size + dx]
					if h >= peak.height:
						ties += 1
					if d2 >= SHOULDER * SHOULDER:
						shoulder = maxf(shoulder, h)
			expect(ties == 0, "seed %d: %d cells near the peak at %d are as high" % [island_seed, ties, peak.cell])
			expect(peak.height - shoulder >= DROP, "seed %d: the peak at %d stands only %.3f over its shoulder" % [island_seed, peak.cell, peak.height - shoulder])


## Only massifs reach the snow, so every snow cell lies on a peak's massif.
func test_only_peaks_have_snow() -> void:
	var size: int = IslandData.SIZE
	var reach: float = Massifs.MAX_RADIUS * (1.0 + Massifs.OUTLINE_WARP)
	for island_seed: int in SEEDS:
		var data: IslandData = island(island_seed)
		var stray: int = 0
		for i: int in data.height.size():
			if data.material[i] != Ramps.Terrain.SNOW:
				continue
			var near: bool = false
			for peak: Peak in data.peaks:
				if Vector2(i % size - peak.cell % size, i / size - peak.cell / size).length() < reach:
					near = true
					break
			if not near:
				stray += 1
		expect(stray == 0, "seed %d: %d snow cells lie off every massif" % [island_seed, stray])


## A ridge with a summit of 1.0, a second peak of 0.8, and a knoll of 0.55 on the second's slope. The
## two big cones meet at 0.4, so the second peak rises 0.4 and the knoll only about 0.05, below the cut.
func test_prominence_on_a_ridge() -> void:
	var size: int = IslandData.SIZE
	var height := PackedFloat32Array()
	height.resize(size * size)
	var main_island := PackedByteArray()
	main_island.resize(size * size)
	for y: int in range(400, 411):
		for x: int in range(100, 901):
			var h: float = maxf(0.05, maxf(1.0 - 0.002 * absf(x - 200), maxf(0.8 - 0.002 * absf(x - 700), 0.55 - 0.05 * absf(x - 850))))
			height[IslandData.index(x, y)] = h
			main_island[IslandData.index(x, y)] = 1
	var peaks: Array[Peak] = Peaks.generate(height, main_island)
	expect(peaks.size() == 2, "the ridge gave %d peaks" % peaks.size())
	if peaks.size() == 2:
		expect(is_equal_approx(peaks[0].prominence, 1.0), "summit prominence is %f" % peaks[0].prominence)
		expect(peaks[1].cell % size == 700, "second peak is at column %d" % (peaks[1].cell % size))
		expect(absf(peaks[1].prominence - 0.4) < 0.001, "second peak prominence is %f, not 0.4" % peaks[1].prominence)
