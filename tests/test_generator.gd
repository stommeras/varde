extends "res://tests/test_case.gd"


## The game generates on a background thread, so the result there must match the main thread's.
func test_thread_gives_same_island() -> void:
	var thread := Thread.new()
	thread.start(IslandGenerator.generate.bind(7))
	var threaded: IslandData = thread.wait_to_finish()
	var data: IslandData = island(7)
	expect(threaded.height == data.height, "seed 7 gave a different height on a thread")
	expect(threaded.moisture == data.moisture, "seed 7 gave a different moisture on a thread")
	expect(threaded.material == data.material, "seed 7 gave a different material on a thread")
	expect(threaded.main_island == data.main_island, "seed 7 gave a different main island on a thread")
	expect(threaded.rivers == data.rivers, "seed 7 gave different rivers on a thread")
	expect(threaded.fresh_water == data.fresh_water, "seed 7 gave different fresh water on a thread")
	expect(threaded.lake == data.lake, "seed 7 gave different lakes on a thread")
	expect(threaded.cliff == data.cliff, "seed 7 gave different cliffs on a thread")
	expect(peaks_text(threaded.peaks) == peaks_text(data.peaks), "seed 7 gave different peaks on a thread")
	expect(threaded.lakes == data.lakes and threaded.river_forks == data.river_forks and threaded.coves == data.coves and threaded.forest == data.forest, "seed 7 gave different features on a thread")
	expect(threaded.start == data.start, "seed 7 gave a different start cell on a thread")
	expect(threaded.wreck == data.wreck, "seed 7 gave a different wreck on a thread")
	expect(threaded.route == data.route, "seed 7 gave a different route on a thread")
	expect(threaded.vardes == data.vardes and threaded.varde_kinds == data.varde_kinds and threaded.varde_peaks == data.varde_peaks, "seed 7 gave different old vardes on a thread")


func test_every_step_is_timed() -> void:
	var steps: Array[String] = island(0).step_msec.keys()
	expect(steps == ["height", "erosion", "crags", "moisture", "material", "main_island", "rivers", "peaks", "contenders", "start", "ways_up", "features", "route"], "timed steps are %s" % [steps])
