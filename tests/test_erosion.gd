extends "res://tests/test_case.gd"


## Erosion should cut valleys into the mountains and leave the coast and the lowland alone.
func test_erosion_keeps_coast_and_lowland() -> void:
	for island_seed: int in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = island_seed
		var smooth: PackedFloat32Array = Height.smooth(rng)
		var massif_rng := RandomNumberGenerator.new()
		massif_rng.seed = rng.randi()
		Massifs.place(smooth, massif_rng)
		var eroded: PackedFloat32Array = smooth.duplicate()
		Erosion.apply(eroded, rng)
		var coast_moved: int = 0
		var lowland_changed: int = 0
		var deepest: float = 0.0
		for i: int in smooth.size():
			if (smooth[i] > 0.0) != (eroded[i] > 0.0):
				coast_moved += 1
			# Well below ERODE_FROM. The bilinear lookup at a steep mountain's foot reaches a few of
			# these cells, by about 0.002 at most on seeds 0 to 2.
			if smooth[i] < Erosion.ERODE_FROM * 0.5 and absf(eroded[i] - smooth[i]) > 0.005:
				lowland_changed += 1
			deepest = maxf(deepest, smooth[i] - eroded[i])
		expect(coast_moved == 0, "seed %d: erosion moved %d coast cells" % [island_seed, coast_moved])
		expect(lowland_changed == 0, "seed %d: erosion changed %d lowland cells" % [island_seed, lowland_changed])
		# The deepest valleys on seeds 0 to 2 cut about 0.5 into mountains about 1 high.
		expect(deepest > 0.1, "seed %d: the deepest cut is only %f" % [island_seed, deepest])
