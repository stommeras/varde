class_name Ramps
## Every color in the game. Shaders and scripts read from here, never from their own literals.
## Each ramp runs from darkest to lightest, and lighting snaps to these steps.

enum Terrain { WATER, BEACH, GRASS, FOREST, MARSH, ROCK, SNOW }

static var RAMPS: Dictionary[Terrain, PackedColorArray] = {
	Terrain.WATER: PackedColorArray([Color("10223a"), Color("163a5c"), Color("1f5a80"), Color("2f7fa3"), Color("5aa9c4")]),
	Terrain.BEACH: PackedColorArray([Color("8a6f4a"), Color("b39364"), Color("d4b783"), Color("ead3a2"), Color("f6e8c8")]),
	Terrain.GRASS: PackedColorArray([Color("2c4a24"), Color("3f6a2c"), Color("5a8a36"), Color("7aa84a"), Color("a3c56a")]),
	Terrain.FOREST: PackedColorArray([Color("142a1c"), Color("1d3d26"), Color("2a5530"), Color("3c6e3a"), Color("55894a")]),
	Terrain.MARSH: PackedColorArray([Color("2e3a26"), Color("44523a"), Color("5d6b4a"), Color("7a8660")]),
	Terrain.ROCK: PackedColorArray([Color("2e2c2e"), Color("4a4648"), Color("6a6466"), Color("8e8786"), Color("b3aca8")]),
	Terrain.SNOW: PackedColorArray([Color("8a98b0"), Color("aebbd0"), Color("d2dbe8"), Color("eef2f8")]),
}


## The middle step of a ramp, used where a terrain needs one flat color, as in the debug view.
static func base(terrain: Terrain) -> Color:
	var ramp: PackedColorArray = RAMPS[terrain]
	return ramp[ramp.size() / 2]
