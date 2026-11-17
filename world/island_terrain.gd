class_name IslandTerrain
extends Node3D
## Holds one MeshInstance3D per terrain chunk, drawn by the terrain shader. Its y scale is the summit height.

## World units from sea level to the highest cell, chosen by eye in milestone 2. Raising it makes the
## mountains steeper and their shadows longer, lowering it flattens the island.
const SUMMIT_HEIGHT: float = 100.0


func _init() -> void:
	scale.y = SUMMIT_HEIGHT


## Replaces the terrain with a new island's chunk meshes.
func show_island(meshes: Array[ArrayMesh], island: IslandData) -> void:
	for chunk: Node in get_children():
		# Removed now, so _apply_lod_bias doesn't also walk the chunks waiting to be freed.
		remove_child(chunk)
		chunk.queue_free()
	var material: ShaderMaterial = TerrainMaterial.create(island)
	for mesh: ArrayMesh in meshes:
		var chunk := MeshInstance3D.new()
		chunk.mesh = mesh
		chunk.material_override = material
		add_child(chunk)
	_apply_lod_bias()


## Stretches the terrain so the highest cell stands height world units above sea level.
func set_summit_height(height: float) -> void:
	scale.y = height
	_apply_lod_bias()


# Godot scales a mesh's level-of-detail distances by the node's largest scale, which is the summit
# height here. That only stretches heights, so the bias cancels it and the level follows the zoom.
func _apply_lod_bias() -> void:
	for chunk: MeshInstance3D in get_children():
		chunk.lod_bias = 1.0 / maxf(scale.y, 1.0)
