class_name IslandTerrain
extends Node3D
## Holds two MeshInstance3D per terrain chunk, one for the ground drawn by the terrain shader and one
## for the ground details standing on it. Its y scale is the summit height.

## World units from sea level to the highest cell, chosen by eye in milestone 2. Raising it makes the
## mountains steeper and their shadows longer, lowering it flattens the island. Walkability holds the
## value, because the slope the player can climb depends on it and the generator can't read a node.
const SUMMIT_HEIGHT: float = Walkability.SUMMIT_UNITS

## What the player knows about the island. A new island starts with all of it unknown.
var knowledge: Knowledge
var _material: ShaderMaterial
var _details: ShaderMaterial


func _init() -> void:
	scale.y = SUMMIT_HEIGHT
	# After the default 0, so the upload in _process sees this frame's marks: the player's, and the
	# start's cast marked when the loader emits from its own _process. Otherwise the first frame of an
	# island draws all of it as flat fog.
	process_priority = 1


## Replaces the terrain with a new island's chunk meshes.
func show_island(meshes: Array[ArrayMesh], island: IslandData) -> void:
	for chunk: Node in get_children():
		# Removed now, so _apply_lod_bias doesn't also walk the chunks waiting to be freed.
		remove_child(chunk)
		chunk.queue_free()
	knowledge = Knowledge.new()
	_material = TerrainMaterial.create(island, knowledge)
	_details = GroundDetails.create(_material, island.island_seed)
	for mesh: ArrayMesh in meshes:
		var chunk := MeshInstance3D.new()
		chunk.mesh = mesh
		chunk.material_override = _material
		add_child(chunk)
	for i: int in meshes.size():
		var details := MeshInstance3D.new()
		details.mesh = GroundDetails.mesh()
		details.material_override = _details
		# The shader builds each quad facing the view, which in the shadow pass is the sun's, so its
		# shadow wouldn't match the sprite.
		details.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		details.position = Vector3(i % TerrainMesh.CHUNKS, 0, i / TerrainMesh.CHUNKS) * TerrainMesh.CHUNK
		add_child(details)
	_apply_lod_bias()


func _process(delta: float) -> void:
	if knowledge == null:
		return
	knowledge.now += delta
	knowledge.upload()
	for material: ShaderMaterial in [_material, _details]:
		material.set_shader_parameter("reveal_now", knowledge.now)


## The terrain shader's material, whose grid textures the map screen draws from too.
func ground_material() -> ShaderMaterial:
	return _material


## Fades the terrain that stands between the camera and feet, the player's feet in world units.
## amount runs from 0, shut, to 1, the full radius. Call it after show_island(), which makes a new
## material with the fade shut.
func fade_around(feet: Vector3, amount: float) -> void:
	for material: ShaderMaterial in [_material, _details]:
		material.set_shader_parameter("fade_amount", amount)
		material.set_shader_parameter("player_position", feet)


## Stretches the terrain so the highest cell stands height world units above sea level.
func set_summit_height(height: float) -> void:
	scale.y = height
	_apply_lod_bias()


# Godot scales a mesh's level-of-detail distances by the node's largest scale, which is the summit
# height here. That only stretches heights, so the bias cancels it and the level follows the zoom.
func _apply_lod_bias() -> void:
	for chunk: MeshInstance3D in get_children():
		chunk.lod_bias = 1.0 / maxf(scale.y, 1.0)
