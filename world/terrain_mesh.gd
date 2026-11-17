class_name TerrainMesh
## Builds an island's terrain as square chunks of mesh, one world unit per cell, so the renderer can
## cull the chunks off screen and draw the rest with fewer triangles when zoomed out. It uses no
## nodes, so it can build on a background thread.

## Cells along one side of a chunk. Every step in STEPS must divide it. Raising it means fewer
## chunks to cull and draw, lowering it culls more tightly at the screen's edges.
const CHUNK: int = 64
## Cells between neighboring vertices at each level of detail, finest first. Godot draws the
## coarsest level whose step is at most about one screen pixel. The camera is orthographic, so that
## depends on the zoom and not the distance, and every chunk on screen draws at the same level. At
## the SPEC's zoom of 90 cells every chunk draws step 1. Zoomed out to the whole island on 270 rows
## at 45° tilt, a pixel is 2.7 cells and Godot draws step 2. The debug view can't zoom out to 4
## cells per pixel, so a step of 4 would never draw. Add coarser steps when a view can.
const STEPS: Array[int] = [1, 2]
## Chunks along one side of the island.
const CHUNKS: int = IslandData.SIZE / CHUNK


## The terrain as CHUNKS * CHUNKS meshes, row by row, each covering CHUNK * CHUNK cells with its
## levels of detail. A vertex sits at each cell's center, and its y is the cell's height, from 0.0 at
## sea level to 1.0 at the summit, so the nodes' y scale sets the summit height. The sea is flat at
## 0.0. Neighboring chunks share their edge vertices, and every step divides CHUNK, so chunks drawn
## at the same level meet without cracks.
##
## Godot picks the level per chunk from the screen size of a step times the node's largest scale,
## so set the node's lod_bias to 1 / its y scale when that is above 1. The y scale only stretches
## heights, and it would otherwise hold every chunk at full detail.
static func build(island: IslandData) -> Array[ArrayMesh]:
	var lods: Dictionary = {}
	for step: int in STEPS.slice(1):
		lods[float(step)] = _indices(step)
	var base: PackedInt32Array = _indices(STEPS[0])

	# One vertex grid for the whole island, one vertex wider than the cells so the last chunk in each
	# row has its far edge. That edge copies the last cell, which is always flat sea.
	var size: int = IslandData.SIZE
	var n: int = size + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for row: int in n:
		for column: int in n:
			heights[row * n + column] = maxf(island.height[IslandData.index(mini(column, size - 1), mini(row, size - 1))], 0.0)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(n * n)
	normals.resize(n * n)
	for row: int in n:
		var north: int = maxi(row - 1, 0) * n
		var south: int = mini(row + 1, n - 1) * n
		for column: int in n:
			var i: int = row * n + column
			vertices[i] = Vector3(column + 0.5, heights[i], row + 0.5)
			# Central differences give the slope, and the surface y = h(x, z) has the normal
			# (-dh/dx, 1, -dh/dz). The terrain shader computes its own normal from the height map,
			# so these only matter to Godot's passes that read the mesh, such as shadow bias.
			var dx: float = (heights[row * n + mini(column + 1, n - 1)] - heights[row * n + maxi(column - 1, 0)]) / 2.0
			var dz: float = (heights[south + column] - heights[north + column]) / 2.0
			normals[i] = Vector3(-dx, 1.0, -dz).normalized()

	var meshes: Array[ArrayMesh] = []
	for chunk_row: int in CHUNKS:
		for chunk_column: int in CHUNKS:
			var chunk_vertices := PackedVector3Array()
			var chunk_normals := PackedVector3Array()
			for row: int in CHUNK + 1:
				var start: int = (chunk_row * CHUNK + row) * n + chunk_column * CHUNK
				chunk_vertices.append_array(vertices.slice(start, start + CHUNK + 1))
				chunk_normals.append_array(normals.slice(start, start + CHUNK + 1))
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = chunk_vertices
			arrays[Mesh.ARRAY_NORMAL] = chunk_normals
			arrays[Mesh.ARRAY_INDEX] = base
			var mesh := ArrayMesh.new()
			# Every chunk has the same vertex layout, so all of them share one index array per level.
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
			meshes.append(mesh)
	return meshes


## Two triangles for each square of step * step cells in a chunk's (CHUNK + 1)² vertex grid.
static func _indices(step: int) -> PackedInt32Array:
	var side: int = CHUNK + 1
	var quads: int = CHUNK / step
	var indices := PackedInt32Array()
	indices.resize(quads * quads * 6)
	var k: int = 0
	for row: int in quads:
		for column: int in quads:
			var a: int = row * step * side + column * step
			var b: int = a + step
			var c: int = a + step * side
			# Godot treats clockwise triangles as front faces, seen from above with north up.
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c + step
			indices[k + 3] = a
			indices[k + 4] = c + step
			indices[k + 5] = c
			k += 6
	return indices
