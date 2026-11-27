class_name IslandTerrain
extends Node3D
## Holds three MeshInstance3D per terrain chunk: the ground drawn by the terrain shader, the same mesh
## again casting the sun's shadow, and the ground details standing on it. Its y scale is the summit height.

## World units from sea level to the highest cell, chosen by eye in milestone 2. Raising it makes the
## mountains steeper and their shadows longer, lowering it flattens the island. Walkability holds the
## value, because the slope the player can climb depends on it and the generator can't read a node.
const SUMMIT_HEIGHT: float = Walkability.SUMMIT_UNITS
const SHADOW_SHADER: Shader = preload("res://world/terrain_shadow.gdshader")

## What the player knows about the island. A new island starts with all of it unknown.
var knowledge: Knowledge
var _material: ShaderMaterial
var _details: ShaderMaterial
var _island: IslandData
## How far each cloud in the island's clouds has faded, from 0 while it stands to 1 once gone.
var _cloud_gone := PackedFloat32Array()


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
	_island = island
	_cloud_gone.resize(Contenders.MAX_COUNT)
	_cloud_gone.fill(0.0)
	_material = TerrainMaterial.create(island, knowledge)
	_details = GroundDetails.create(_material, island.island_seed)
	var shadow := ShaderMaterial.new()
	shadow.shader = SHADOW_SHADER
	for mesh: ArrayMesh in meshes:
		var chunk := MeshInstance3D.new()
		chunk.mesh = mesh
		chunk.material_override = _material
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chunk)
		var caster := MeshInstance3D.new()
		caster.mesh = mesh
		caster.material_override = shadow
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(caster)
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
	_set_shared("reveal_now", knowledge.now)


## Hides the fog everywhere while on is true, as god mode does, without marking any cell known.
## Call it after show_island(), which makes a new material with the fog shown.
func show_all(on: bool) -> void:
	_set_shared("show_all", on)


## True while a cloud that hasn't faded covers cell.
func clouded(cell: int) -> bool:
	return _island != null and _island.cloud[cell] > 0 and _cloud_gone[_island.cloud[cell] - 1] < 1.0


## Fades the cloud on the peak whose top is top to gone, from 0 while it stands to 1 when it has gone
## for the rest of the run. A peak with no cloud is left as it is.
func fade_cloud(top: int, gone: float) -> void:
	var index: int = _island.cloud_tops.find(top)
	if index < 0:
		return
	_cloud_gone[index] = gone
	_set_shared("cloud_gone", _cloud_gone)


## Opens the clouds around point, the player's position in cells, so they see the ground they stand on.
func open_clouds(point: Vector2) -> void:
	_set_shared("cloud_hole", point)


# Sets a parameter on the terrain and the ground details, which read the same fog and clouds.
func _set_shared(parameter: String, value: Variant) -> void:
	for material: ShaderMaterial in [_material, _details]:
		material.set_shader_parameter(parameter, value)


## The terrain shader's material, whose grid textures the map screen draws from too.
func ground_material() -> ShaderMaterial:
	return _material


## Stretches the terrain so the highest cell stands height world units above sea level.
func set_summit_height(height: float) -> void:
	scale.y = height
	_apply_lod_bias()


# Godot scales a mesh's level-of-detail distances by the node's largest scale, which is the summit
# height here. That only stretches heights, so the bias cancels it and the level follows the zoom.
func _apply_lod_bias() -> void:
	for chunk: MeshInstance3D in get_children():
		chunk.lod_bias = 1.0 / maxf(scale.y, 1.0)
