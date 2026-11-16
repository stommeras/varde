class_name IslandGenerator
## Runs the generator steps in order. Takes a seed and returns IslandData, with no nodes or scenes.


static func generate(island_seed: int) -> IslandData:
	var data := IslandData.new()
	data.island_seed = island_seed
	# One generator feeds the noise steps in a fixed order, so the same seed gives the same island.
	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed
	data.height = Height.generate(rng)
	data.moisture = Moisture.generate(rng)
	data.material = MaterialLookup.generate(data.height, data.moisture)
	data.main_island = MainIsland.generate(data.height)
	return data
