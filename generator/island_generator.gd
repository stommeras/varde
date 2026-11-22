class_name IslandGenerator
## Runs the generator steps in order. Takes a seed and returns IslandData, with no nodes or scenes,
## so it can run on a background thread.


## on_step, if valid, is called on the generator's thread with each step's name as the step finishes.
static func generate(island_seed: int, on_step: Callable = Callable()) -> IslandData:
	var data := IslandData.new()
	data.island_seed = island_seed
	# One generator feeds the noise steps in a fixed order, so the same seed gives the same island.
	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed
	var started: int = Time.get_ticks_msec()
	var softness := PackedFloat32Array()
	var smooth: PackedFloat32Array = Height.smooth(rng, softness)
	started = _record(data, "height", started, on_step)
	# Erosion draws hundreds of thousands of numbers, as many as its tuning asks for, so it gets a
	# generator of its own. Retuning it then leaves the noise of the later steps as it was.
	var erosion_rng := RandomNumberGenerator.new()
	erosion_rng.seed = rng.randi()
	Erosion.apply(smooth, erosion_rng, softness)
	started = _record(data, "erosion", started, on_step)
	data.height = Height.crags(smooth, rng)
	started = _record(data, "crags", started, on_step)
	data.moisture = Moisture.generate(rng)
	started = _record(data, "moisture", started, on_step)
	data.material = MaterialLookup.generate(data.height, data.moisture)
	started = _record(data, "material", started, on_step)
	data.main_island = MainIsland.generate(data.height)
	started = _record(data, "main_island", started, on_step)
	# Its own generator too, so moving the springs leaves the steps after it as they were.
	var river_rng := RandomNumberGenerator.new()
	river_rng.seed = rng.randi()
	Rivers.generate(data, river_rng)
	started = _record(data, "rivers", started, on_step)
	data.peaks = Peaks.generate(data.height, data.main_island)
	started = _record(data, "peaks", started, on_step)
	var start_rng := RandomNumberGenerator.new()
	start_rng.seed = rng.randi()
	data.start = Walkability.start_cell(data, start_rng)
	started = _record(data, "start", started, on_step)
	WaysUp.open(data)
	_record(data, "ways_up", started, on_step)
	return data


## Stores how long a step took since started, reports it to on_step, and returns the time now for the
## next step.
static func _record(data: IslandData, step: String, started: int, on_step: Callable) -> int:
	if on_step.is_valid():
		on_step.call(step)
	var now: int = Time.get_ticks_msec()
	data.step_msec[step] = now - started
	return now
