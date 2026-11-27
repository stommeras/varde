class_name Ramps
## Every color in the game. Shaders and scripts read from here, never from their own literals.
## Each ramp runs from darkest to lightest, and lighting snaps to these steps.

## FOAM and FOG are the values no cell holds. The terrain shader draws foam in bands along the shore
## and fog over every cell the player doesn't know yet, land and sea alike.
enum Terrain { WATER, BEACH, GRASS, FOREST, MARSH, ROCK, SNOW, FOAM, FOG }

static var RAMPS: Dictionary[Terrain, PackedColorArray] = {
	Terrain.WATER: PackedColorArray([Color("10223a"), Color("163a5c"), Color("1f5a80"), Color("2f7fa3"), Color("5aa9c4")]),
	Terrain.BEACH: PackedColorArray([Color("8a6f4a"), Color("b39364"), Color("d4b783"), Color("ead3a2"), Color("f6e8c8")]),
	Terrain.GRASS: PackedColorArray([Color("2c4a24"), Color("3f6a2c"), Color("5a8a36"), Color("7aa84a"), Color("a3c56a")]),
	Terrain.FOREST: PackedColorArray([Color("1d3d26"), Color("2a5530"), Color("3a6b38"), Color("4e8545"), Color("6a9e58")]),
	Terrain.MARSH: PackedColorArray([Color("2e3a26"), Color("44523a"), Color("5d6b4a"), Color("7a8660")]),
	Terrain.ROCK: PackedColorArray([Color("2e2c2e"), Color("4a4648"), Color("6a6466"), Color("8e8786"), Color("b3aca8")]),
	Terrain.SNOW: PackedColorArray([Color("8a98b0"), Color("aebbd0"), Color("d2dbe8"), Color("eef2f8")]),
	Terrain.FOAM: PackedColorArray([Color("6f97a8"), Color("a3c4cc"), Color("d3e5e6"), Color("f2f7f4")]),
	# Grey with a little of the sea's blue, darker than snow and foam, so a snowy peak in front of it
	# and the surf along a known coast both stand apart from it.
	Terrain.FOG: PackedColorArray([Color("3c4552"), Color("566170"), Color("717d8b"), Color("8e98a4"), Color("aab2bb")]),
}

## The parts of the walking figure that each have a ramp in FIGURE. HAIR also colors the eyes. STONE,
## WOOD, LICHEN and MOSS are not on the figure but on the vardes, the shipwreck and the old vardes,
## drawn by the figure's shader.
enum FigurePart { SKIN, HAIR, COAT, TROUSERS, BOOTS, PACK, STONE, WOOD, LICHEN, MOSS }

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
	# Every other step of the rock ramp, so a varde reads as the mountain's own stone. With the middle
	# three steps the shaded undersides barely differed from the lit tops, and the stones ran together.
	FigurePart.STONE: PackedColorArray([Color("2e2c2e"), Color("6a6466"), Color("b3aca8")]),
	# Weathered brown planks, greyer and darker than the pack, so the wreck reads as old wood against
	# the light sand. The beach's driftwood is grey rock, and a grey hull read as a rock.
	FigurePart.WOOD: PackedColorArray([Color("3a2e26"), Color("6b5644"), Color("9c8670")]),
	# The stone ramp with grey-green lichen grown over it, so an old varde reads as older than the
	# player's clean grey one, and still as stone against grass and forest.
	FigurePart.LICHEN: PackedColorArray([Color("2c302a"), Color("62695a"), Color("a3a88e")]),
	# Dark, yellower than the forest ramp, for an old varde overgrown where it stands in forest. It
	# shows only up close against the forest floor, so the varde reads as hidden.
	FigurePart.MOSS: PackedColorArray([Color("1f2a1c"), Color("4a5a34"), Color("7e8a52")]),
}


## The parts of the map screen that each have a ramp in MAP, all ink on aged paper.
enum MapPart { PAPER, INK, WATER, MARKER }

## The map screen, darkest step first. The 2D map shader takes these as sRGB uniforms, not through
## image(), because a canvas shader in the 2D renderer works in sRGB.
static var MAP: Dictionary[MapPart, PackedColorArray] = {
	# Aged paper: a stained step for the grain and the yellowed edges, the sheet itself, and a light
	# step for known land.
	MapPart.PAPER: PackedColorArray([Color("b89c70"), Color("d2bb8e"), Color("e6d6b0")]),
	# Brown-black ink for the coast and the thick contours, and a faded step for the thin contours
	# and the outlines of forest and snow.
	MapPart.INK: PackedColorArray([Color("3a2a1c"), Color("8a6c4c")]),
	# Blue ink for rivers and lakes, and a pale wash for the sea the player has seen.
	MapPart.WATER: PackedColorArray([Color("2f5a7a"), Color("a3b8b4")]),
	# Red ink for the player's marker, the coat's red, so the marker reads as the figure.
	MapPart.MARKER: PackedColorArray([Color("6a1e22"), Color("a8342e")]),
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
