class_name TerrainMaterial
## Builds the terrain shader's material for one island from its height and material grids.

const SHADER: Shader = preload("res://world/terrain.gdshader")
## Pixels along one side of the noise tile. The shader stretches the tile over many cells, so 256
## gives smooth curves with no visible texels.
const NOISE_SIZE: int = 256


## A material for the terrain mesh of island. Its textures share the island's grid.
static func create(island: IslandData) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var height := Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_RF, island.height.to_byte_array())
	var terrain := Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_R8, island.material)
	material.set_shader_parameter("height_map", ImageTexture.create_from_image(height))
	material.set_shader_parameter("material_map", ImageTexture.create_from_image(terrain))
	material.set_shader_parameter("ramps", ImageTexture.create_from_image(ramp_image()))
	var sizes := PackedInt32Array()
	for kind: Ramps.Terrain in Ramps.Terrain.values():
		sizes.append(Ramps.RAMPS[kind].size())
	material.set_shader_parameter("ramp_sizes", sizes)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Four waves across the tile, so it holds detail at both scales the shader samples it at.
	noise.frequency = 4.0 / NOISE_SIZE
	material.set_shader_parameter("noise", ImageTexture.create_from_image(noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE)))
	return material


## One row per Ramps.Terrain value, each ramp's steps from darkest on the left. Rows shorter than the
## longest ramp end in black pixels that the shader never reads.
static func ramp_image() -> Image:
	var width: int = 0
	for ramp: PackedColorArray in Ramps.RAMPS.values():
		width = maxi(width, ramp.size())
	var image := Image.create_empty(width, Ramps.Terrain.size(), false, Image.FORMAT_RGB8)
	for kind: Ramps.Terrain in Ramps.Terrain.values():
		var ramp: PackedColorArray = Ramps.RAMPS[kind]
		for i: int in ramp.size():
			image.set_pixel(i, kind, ramp[i])
	return image
