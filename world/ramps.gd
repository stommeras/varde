class_name Ramps
## Every color in the game. Shaders and scripts read from here, never from their own literals.
## Each ramp runs from darkest to lightest, and lighting snaps to these steps.

## FOAM is the one value no cell holds. The terrain shader draws it in bands along the shore.
enum Terrain { WATER, BEACH, GRASS, FOREST, MARSH, ROCK, SNOW, FOAM }

static var RAMPS: Dictionary[Terrain, PackedColorArray] = {
	Terrain.WATER: PackedColorArray([Color("10223a"), Color("163a5c"), Color("1f5a80"), Color("2f7fa3"), Color("5aa9c4")]),
	Terrain.BEACH: PackedColorArray([Color("8a6f4a"), Color("b39364"), Color("d4b783"), Color("ead3a2"), Color("f6e8c8")]),
	Terrain.GRASS: PackedColorArray([Color("2c4a24"), Color("3f6a2c"), Color("5a8a36"), Color("7aa84a"), Color("a3c56a")]),
	Terrain.FOREST: PackedColorArray([Color("1d3d26"), Color("2a5530"), Color("3a6b38"), Color("4e8545"), Color("6a9e58")]),
	Terrain.MARSH: PackedColorArray([Color("2e3a26"), Color("44523a"), Color("5d6b4a"), Color("7a8660")]),
	Terrain.ROCK: PackedColorArray([Color("2e2c2e"), Color("4a4648"), Color("6a6466"), Color("8e8786"), Color("b3aca8")]),
	Terrain.SNOW: PackedColorArray([Color("8a98b0"), Color("aebbd0"), Color("d2dbe8"), Color("eef2f8")]),
	Terrain.FOAM: PackedColorArray([Color("6f97a8"), Color("a3c4cc"), Color("d3e5e6"), Color("f2f7f4")]),
}

## The parts of the walking figure that each have a ramp in FIGURE. HAIR also colors the eyes.
enum FigurePart { SKIN, HAIR, COAT, TROUSERS, BOOTS, PACK }

## The walking figure, lit like the terrain. Three steps per part give a shade side, a middle and a
## lit side. The red coat and cap stand out against every terrain ramp, so the player is easy to find
## on screen, and the tan pack keeps the back view from reading as one red block.
static var FIGURE: Dictionary[FigurePart, PackedColorArray] = {
	FigurePart.SKIN: PackedColorArray([Color("b0705a"), Color("e0a07a"), Color("f4c8a0")]),
	FigurePart.HAIR: PackedColorArray([Color("16121a"), Color("2e2630"), Color("4a3c40")]),
	FigurePart.COAT: PackedColorArray([Color("6a1e22"), Color("a8342e"), Color("d4553e")]),
	FigurePart.TROUSERS: PackedColorArray([Color("23253a"), Color("3b3d52"), Color("5a5e78")]),
	FigurePart.BOOTS: PackedColorArray([Color("1c1610"), Color("3a2a1e"), Color("58402c")]),
	FigurePart.PACK: PackedColorArray([Color("4e3824"), Color("7a5a38"), Color("a07c50")]),
}


## ramps as an image, row r holding ramps[r] with its steps from darkest on the left. Rows shorter than
## the longest ramp end in black pixels that the shaders never read. The colors are linear, in half
## floats, because the Compatibility renderer of the web build doesn't decode a source_color texture
## that a shader reads with texelFetch, and its colors came out one sRGB curve too light.
static func image(ramps: Dictionary) -> Image:
	var width: int = 0
	for ramp: PackedColorArray in ramps.values():
		width = maxi(width, ramp.size())
	var result := Image.create_empty(width, ramps.size(), false, Image.FORMAT_RGBH)
	for row: int in ramps:
		var ramp: PackedColorArray = ramps[row]
		for i: int in ramp.size():
			result.set_pixel(i, row, ramp[i].srgb_to_linear())
	return result


## The middle step of a ramp, used where a terrain needs one flat color, as in the debug view.
static func base(terrain: Terrain) -> Color:
	var ramp: PackedColorArray = RAMPS[terrain]
	return ramp[ramp.size() / 2]


## A color from anywhere along a ramp, blending between its steps. t runs from 0 (darkest) to 1 (lightest).
## Only debug views blend. The game itself snaps to the steps.
static func sample(terrain: Terrain, t: float) -> Color:
	var ramp: PackedColorArray = RAMPS[terrain]
	var position: float = clampf(t, 0.0, 1.0) * (ramp.size() - 1)
	var step: int = mini(int(position), ramp.size() - 2)
	return ramp[step].lerp(ramp[step + 1], position - step)
