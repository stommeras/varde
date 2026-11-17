class_name IslandGenerator
## Runs the generator steps in order. Takes a seed and returns IslandData, with no nodes or scenes,
## so it can run on a background thread.


static func generate(island_seed: int) -> IslandData:
	var data := IslandData.new()
	data.island_seed = island_seed
	# One generator feeds the noise steps in a fixed order, so the same seed gives the same island.
	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed
	var started: int = Time.get_ticks_msec()
	var smooth: PackedFloat32Array = Height.smooth(rng)
	started = _record(data, "height", started)
	# Erosion draws hundreds of thousands of numbers, as many as its tuning asks for, so it gets a
	# generator of its own. Retuning it then leaves the noise of the later steps as it was.
	var erosion_rng := RandomNumberGenerator.new()
	erosion_rng.seed = rng.randi()
	Erosion.apply(smooth, erosion_rng)
	started = _record(data, "erosion", started)
	data.height = Height.crags(smooth, rng)
	started = _record(data, "crags", started)
	data.moisture = Moisture.generate(rng)
	started = _record(data, "moisture", started)
	data.material = MaterialLookup.generate(data.height, data.moisture)
	started = _record(data, "material", started)
	data.main_island = MainIsland.generate(data.height)
	_record(data, "main_island", started)
	return data


## Stores how long a step took since started, and returns the time now for the next step.
static func _record(data: IslandData, step: String, started: int) -> int:
	var now: int = Time.get_ticks_msec()
	data.step_msec[step] = now - started
	return now
