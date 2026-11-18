class_name TerrainMaterial
## Builds the terrain shader's material for one island from its height and material grids.

const SHADER: Shader = preload("res://world/terrain.gdshader")
## Pixels along one side of the noise tile. The shader stretches the tile over many cells, so 256
## gives smooth curves with no visible texels.
const NOISE_SIZE: int = 256

## The ramp and noise textures are the same for every island, so they are built once.
static var _ramps: ImageTexture
static var _noise: ImageTexture


## A material for the terrain mesh of island, with knowledge as the player's map of what they know.
## Its textures share the island's grid.
static func create(island: IslandData, knowledge: Knowledge) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var height := Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_RF, island.height.to_byte_array())
	var terrain := Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_R8, island.material)
	material.set_shader_parameter("height_map", ImageTexture.create_from_image(height))
	material.set_shader_parameter("material_map", ImageTexture.create_from_image(terrain))
	var fresh_water := Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_R8, island.fresh_water)
	material.set_shader_parameter("fresh_water_map", ImageTexture.create_from_image(fresh_water))
	material.set_shader_parameter("knowledge_map", knowledge.texture)
	if _ramps == null:
		_ramps = ImageTexture.create_from_image(Ramps.image(Ramps.RAMPS))
		_noise = _noise_texture()
	material.set_shader_parameter("ramps", _ramps)
	material.set_shader_parameter("noise", _noise)
	var sizes := PackedInt32Array()
	for kind: Ramps.Terrain in Ramps.Terrain.values():
		sizes.append(Ramps.RAMPS[kind].size())
	material.set_shader_parameter("ramp_sizes", sizes)
	# Walkability blocks steps at this slope, so the rock the shader draws marks the walls.
	material.set_shader_parameter("cliff_normal_y", Walkability.CLIFF_NORMAL_Y)
	return material


static func _noise_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Four waves across the tile, so it holds detail at both scales the shader samples it at.
	noise.frequency = 4.0 / NOISE_SIZE
	return ImageTexture.create_from_image(noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE))

