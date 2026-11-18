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
	expect(threaded.peaks.map(_peak_text) == data.peaks.map(_peak_text), "seed 7 gave different peaks on a thread")
	expect(threaded.start == data.start, "seed 7 gave a different start cell on a thread")


func test_every_step_is_timed() -> void:
	var steps: Array[String] = island(0).step_msec.keys()
	expect(steps == ["height", "erosion", "crags", "moisture", "material", "main_island", "rivers", "peaks", "start"], "timed steps are %s" % [steps])


func _peak_text(peak: Peak) -> String:
	return "%d %f %f" % [peak.cell, peak.height, peak.prominence]
