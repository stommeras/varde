class_name TerrainMesh
## Builds an island's terrain as one coarse mesh, one world unit per cell. It stands in until the
## chunked mesh comes, and it uses no nodes, so it can build on a background thread.

## Cells between neighboring vertices. 1 gives full detail, about 2M triangles that build in about
## 0.6 s. Raising it to 2 quarters both, at the cost of facets 2 cells wide.
const STEP: int = 1


## Surface arrays for ArrayMesh.add_surface_from_arrays. A vertex sits at every STEP-th cell's center.
## Its y is the cell's height, from 0.0 at sea level to 1.0 at the summit, so the node's y scale sets
## the summit height and Godot's normal matrix keeps the normals right under that scale. The sea is
## flat at 0.0. Each UV points at its cell's center in a grid-sized texture.
static func build_arrays(island: IslandData) -> Array:
	var size: int = IslandData.SIZE
	var n: int = size / STEP
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for row: int in n:
		for column: int in n:
			heights[row * n + column] = maxf(island.height[IslandData.index(column * STEP, row * STEP)], 0.0)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(n * n)
	normals.resize(n * n)
	uvs.resize(n * n)
	for row: int in n:
		var north: int = maxi(row - 1, 0) * n
		var south: int = mini(row + 1, n - 1) * n
		for column: int in n:
			var i: int = row * n + column
			var x: float = column * STEP + 0.5
			var z: float = row * STEP + 0.5
			vertices[i] = Vector3(x, heights[i], z)
			uvs[i] = Vector2(x, z) / size
			# Central differences give the slope, and the surface y = h(x, z) has the normal
			# (-dh/dx, 1, -dh/dz). At the edges the difference spans one step instead of two,
			# which only flattens the outermost ring of sea.
			var west: float = heights[row * n + maxi(column - 1, 0)]
			var east: float = heights[row * n + mini(column + 1, n - 1)]
			var dx: float = (east - west) / (2.0 * STEP)
			var dz: float = (heights[south + column] - heights[north + column]) / (2.0 * STEP)
			normals[i] = Vector3(-dx, 1.0, -dz).normalized()

	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var k: int = 0
	for row: int in n - 1:
		for column: int in n - 1:
			var a: int = row * n + column
			var c: int = a + n
			# Godot treats clockwise triangles as front faces, seen from above with north up.
			indices[k] = a
			indices[k + 1] = a + 1
			indices[k + 2] = c + 1
			indices[k + 3] = a
			indices[k + 4] = c + 1
			indices[k + 5] = c
			k += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
