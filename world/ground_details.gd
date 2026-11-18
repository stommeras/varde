class_name GroundDetails
## The tufts, stones, shrubs, reeds and driftwood that stand on the ground, so walking shows the land
## passing and their bases show where the ground lies. The sprites are drawn here once, and
## ground_details.gdshader scatters them across the island on the GPU, one chance per cell.

const SHADER: Shader = preload("res://world/ground_details.gdshader")
## Pixels along one side of a sprite's square in the atlas. The tallest sprite, a reed, is 9 pixels
## high against the figure's 16, and the widest, a shrub, is 10 across.
const SPRITE: int = 16
## Sprites per ground material. SPEC.md asks for 20 to 30 per biome. Fewer and the same tuft shows
## up twice on one screen.
const VARIANTS: int = 24
## The sprites are the same on every island, so they take a fixed seed instead of the island's.
const SPRITE_SEED: int = 56
## The terrain material's parameters the details read too, so both decide material, water and light alike.
const SHARED: Array[String] = ["height_map", "material_map", "fresh_water_map", "knowledge_map", "ramps", "ramp_sizes", "noise", "cliff_normal_y"]

enum Detail { TUFT, FLOWER, STONE, SHRUB, REED, DRIFTWOOD, PEBBLES }

## What each ground holds, as the detail, how many of the VARIANTS sprites, and the ramp it is drawn
## in. Each row's counts add up to VARIANTS, and the ground's share of each detail is its count over
## VARIANTS.
static var ROWS: Dictionary[Ramps.Terrain, Array] = {
	Ramps.Terrain.BEACH: [[Detail.PEBBLES, 8], [Detail.STONE, 5], [Detail.DRIFTWOOD, 6], [Detail.TUFT, 5, Ramps.Terrain.GRASS]],
	Ramps.Terrain.GRASS: [[Detail.TUFT, 16], [Detail.FLOWER, 2], [Detail.STONE, 3], [Detail.SHRUB, 3]],
	Ramps.Terrain.FOREST: [[Detail.TUFT, 6], [Detail.SHRUB, 12], [Detail.TUFT, 3, Ramps.Terrain.GRASS], [Detail.STONE, 3]],
	Ramps.Terrain.MARSH: [[Detail.REED, 14], [Detail.TUFT, 6], [Detail.TUFT, 4, Ramps.Terrain.GRASS]],
	Ramps.Terrain.ROCK: [[Detail.STONE, 16], [Detail.TUFT, 8, Ramps.Terrain.GRASS]],
	Ramps.Terrain.SNOW: [[Detail.STONE, 20], [Detail.PEBBLES, 4]],
}

## Built once, because they are the same for every island.
static var _atlas: ImageTexture
static var _mesh: ArrayMesh


## The details' material for an island whose terrain draws with terrain, which TerrainMaterial made.
static func create(terrain: ShaderMaterial, island_seed: int) -> ShaderMaterial:
	if _atlas == null:
		_atlas = ImageTexture.create_from_image(atlas())
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for parameter: String in SHARED:
		material.set_shader_parameter(parameter, terrain.get_shader_parameter(parameter))
	material.set_shader_parameter("atlas", _atlas)
	material.set_shader_parameter("sprite_pixels", SPRITE)
	material.set_shader_parameter("island_seed", island_seed)
	return material


## One quad per cell of a terrain chunk, each with its vertices on the cell's center and its corner
## in UV. The shader moves the corners to where the detail stands. Every chunk shares it, at its own
## position.
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var cells: int = TerrainMesh.CHUNK * TerrainMesh.CHUNK
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(cells * 4)
	uvs.resize(cells * 4)
	indices.resize(cells * 6)
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for cell: int in cells:
		var center := Vector3(cell % TerrainMesh.CHUNK + 0.5, 0.0, cell / TerrainMesh.CHUNK + 0.5)
		for k: int in 4:
			vertices[cell * 4 + k] = center
			uvs[cell * 4 + k] = corners[k]
		var first: int = cell * 4
		for k: int in 6:
			indices[cell * 6 + k] = first + [0, 1, 2, 0, 2, 3][k]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# The vertices lie flat at sea level, but the shader lifts them up to the summit, which the node's
	# y scale puts at 1.0. The margin covers sprites that reach over the chunk's edge.
	_mesh.custom_aabb = AABB(Vector3(-1.0, 0.0, -1.0), Vector3(TerrainMesh.CHUNK + 2.0, 1.1, TerrainMesh.CHUNK + 2.0))
	return _mesh


## The sprites, one row per Ramps.Terrain value and VARIANTS squares of SPRITE pixels across. Each
## pixel holds its ramp in red and its step offset plus 8 in green, and a sprite stands on the
## bottom of its square with its base between the two middle columns.
static func atlas() -> Image:
	var image := Image.create_empty(SPRITE * VARIANTS, SPRITE * Ramps.Terrain.size(), false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = SPRITE_SEED
	for ground: Ramps.Terrain in ROWS:
		var column: int = 0
		for entry: Array in ROWS[ground]:
			var ramp: Ramps.Terrain = entry[2] if entry.size() > 2 else _ramp(entry[0], ground)
			for i: int in entry[1]:
				var sprite := Sprite.new(image, Vector2i(column, ground) * SPRITE, ground)
				_draw(sprite, entry[0], ramp, rng)
				column += 1
		assert(column == VARIANTS, "GroundDetails.ROWS: %d sprites on ground %d" % [column, ground])
	return image


# The ramp a detail takes when ROWS doesn't name one. Stones and driftwood are gray, the rest
# grow in the ground's own colors.
static func _ramp(detail: Detail, ground: Ramps.Terrain) -> Ramps.Terrain:
	if detail in [Detail.STONE, Detail.DRIFTWOOD, Detail.PEBBLES]:
		return Ramps.Terrain.ROCK
	return ground


# Offsets are ramp steps from the light of the ground under the sprite. The sun stands in the
# south-west, so the left and the top of a detail are lit and its shadow falls to the right.
static func _draw(sprite: Sprite, detail: Detail, ramp: Ramps.Terrain, rng: RandomNumberGenerator) -> void:
	match detail:
		Detail.TUFT:
			for blade: int in rng.randi_range(3, 6):
				# Light blades against dark ones, because blades in the ground's own step vanish into its dither.
				_blade(sprite, 8 + rng.randi_range(-3, 2), rng.randi_range(3, 6), rng.randi_range(-1, 1), ramp, -1 if blade % 2 == 0 else 1)
		Detail.FLOWER:
			for blade: int in rng.randi_range(2, 3):
				_blade(sprite, 8 + rng.randi_range(-3, 2), rng.randi_range(2, 3), rng.randi_range(-1, 1), ramp, -1)
			for flower: int in rng.randi_range(1, 3):
				var x: int = 8 + rng.randi_range(-3, 2)
				var height: int = rng.randi_range(3, 5)
				for up: int in height:
					sprite.put(x, up, ramp, -1)
				# White petals, or pale yellow ones from the light end of the beach ramp.
				var petals: Ramps.Terrain = Ramps.Terrain.SNOW if rng.randf() < 0.6 else Ramps.Terrain.BEACH
				sprite.put(x, height, petals, 1)
				sprite.put(x - 1, height, petals, 0)
				sprite.put(x + 1, height, petals, 0)
				sprite.put(x, height + 1, petals, 1)
		Detail.STONE:
			var width: int = rng.randi_range(3, 7)
			_stone(sprite, 8 - width / 2, width, rng.randi_range(2, mini(4, width - 1)), ramp)
		Detail.SHRUB:
			_shrub(sprite, rng.randi_range(5, 9), rng.randi_range(4, 7), ramp, rng)
		Detail.REED:
			for stem: int in rng.randi_range(3, 6):
				var x: int = 8 + rng.randi_range(-3, 2)
				var height: int = rng.randi_range(5, 9)
				_blade(sprite, x, height, rng.randi_range(-1, 1) if rng.randf() < 0.4 else 0, ramp, 1 if stem % 2 == 0 else -1)
				if rng.randf() < 0.35:
					# A seed head on top, two pixels of dark brown from the beach ramp.
					sprite.put(x, height - 1, Ramps.Terrain.BEACH, -2)
					sprite.put(x, height - 2, Ramps.Terrain.BEACH, -2)
		Detail.DRIFTWOOD:
			var length: int = rng.randi_range(5, 10)
			var left: int = 8 - length / 2
			sprite.shadow(left + 1, length)
			for x: int in range(left, left + length):
				sprite.put(x, 1, ramp, 1)
				sprite.put(x, 2 if x == left + length - 1 else 0, ramp, 0 if x == left + length - 1 else -1)
			# A knot and a broken branch stub.
			sprite.put(left + rng.randi_range(1, length - 2), 1, ramp, -1)
			if rng.randf() < 0.6:
				sprite.put(left + rng.randi_range(1, length - 2), 2, ramp, 0)
		Detail.PEBBLES:
			for pebble: int in rng.randi_range(2, 4):
				var x: int = rng.randi_range(4, 11)
				# A pebble a row up lies a little farther back. The first lies on the base.
				var up: int = 0 if pebble == 0 else rng.randi_range(0, 1)
				sprite.put(x, up, ramp, 0)
				if rng.randf() < 0.5:
					sprite.put(x + 1, up, ramp, -1)


# A blade of grass or a reed from x at the bottom, height pixels up, its top half leaning lean
# pixels. It darkens toward the root and lightens at the tip.
static func _blade(sprite: Sprite, x: int, height: int, lean: int, ramp: Ramps.Terrain, base: int) -> void:
	for up: int in height:
		var offset: int = base - 1 if up == 0 else (base + 1 if up == height - 1 else base)
		sprite.put(x + (lean if up * 2 >= height else 0), up, ramp, offset)


# A stone width pixels across and height pixels high from left, rounded at the top corners, on a
# dark shadow that reaches one pixel past its right side.
static func _stone(sprite: Sprite, left: int, width: int, height: int, ramp: Ramps.Terrain) -> void:
	sprite.shadow(left + 1, width)
	for up: int in height:
		var inset: int = 1 if up == height - 1 and width > 3 else 0
		for x: int in range(left + inset, left + width - inset):
			var offset: int = 0
			if up == height - 1:
				offset = 1
			elif up == 0 or x == left + width - 1:
				offset = -1
			sprite.put(x, up, ramp, offset)


# A round bush width pixels across and height high, ragged at its edge, lit on the upper left and
# speckled with darker leaves, on a short dark stem.
static func _shrub(sprite: Sprite, width: int, height: int, ramp: Ramps.Terrain, rng: RandomNumberGenerator) -> void:
	var center := Vector2(8.0, height / 2.0 + 1.0)
	var radius := Vector2(width / 2.0, height / 2.0)
	sprite.shadow(8 - width / 2 + 1, width - 1)
	sprite.put(7, 0, ramp, -2)
	for up: int in range(1, height + 1):
		for x: int in range(8 - width / 2 - 1, 8 + width / 2 + 1):
			var d := (Vector2(x + 0.5, up + 0.5) - center) / radius
			if d.length_squared() > 1.0 + rng.randf_range(-0.35, 0.1):
				continue
			var offset: int = 0
			var light: float = -d.x * 0.6 + d.y * 0.8
			if light > 0.45:
				offset = 1
			elif light < -0.35 or rng.randf() < 0.15:
				offset = -1
			sprite.put(x, up, ramp, offset)


## One sprite's square in the atlas, which draws its pixels by column and height above the base.
class Sprite:
	var _image: Image
	var _origin: Vector2i
	var _ground: Ramps.Terrain

	func _init(image: Image, origin: Vector2i, ground: Ramps.Terrain) -> void:
		_image = image
		_origin = origin
		_ground = ground

	## Sets the pixel in column x, up pixels above the bottom, to ramp, offset steps from the light.
	## Pixels outside the square are dropped.
	func put(x: int, up: int, ramp: Ramps.Terrain, offset: int) -> void:
		if x < 0 or x >= SPRITE or up < 0 or up >= SPRITE:
			return
		_image.set_pixel(_origin.x + x, _origin.y + SPRITE - 1 - up, Color8(ramp, offset + 8, 0, 255))

	## A contact shadow along the bottom row from column left, width pixels long, two steps darker
	## than the ground. A detail drawn after it covers all but the part to its right.
	func shadow(left: int, width: int) -> void:
		for x: int in range(left, left + width):
			put(x, 0, _ground, -2)
