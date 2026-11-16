class_name IslandGenerator
## Runs the generator steps in order. Takes a seed and returns IslandData, with no nodes or scenes.


static func generate(seed: int) -> IslandData:
	var data := IslandData.new()
	data.seed = seed
	data.height = Height.generate(seed, IslandData.SIZE)
	return data
