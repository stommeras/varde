extends "res://tests/test_case.gd"


func test_mesh_covers_the_grid_and_faces_up() -> void:
	var started: int = Time.get_ticks_msec()
	var arrays: Array = TerrainMesh.build_arrays(island(0))
	print("TerrainMesh.build_arrays: %d ms" % (Time.get_ticks_msec() - started))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n: int = IslandData.SIZE / TerrainMesh.STEP
	expect(vertices.size() == n * n, "%d vertices, expected %d" % [vertices.size(), n * n])
	expect(indices.size() == (n - 1) * (n - 1) * 6, "%d indices, expected %d" % [indices.size(), (n - 1) * (n - 1) * 6])
	var lowest: float = INF
	var highest: float = -INF
	for vertex: Vector3 in vertices:
		lowest = minf(lowest, vertex.y)
		highest = maxf(highest, vertex.y)
	expect(lowest == 0.0, "the lowest vertex is at %f, expected the flat sea at 0.0" % lowest)
	expect(highest > 0.9 and highest <= 1.0, "the highest vertex is at %f, expected near 1.0" % highest)
	# A clockwise triangle seen from above has cross(c - a, b - a) pointing up.
	var down: int = 0
	for t: int in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[t]]
		var b: Vector3 = vertices[indices[t + 1]]
		var c: Vector3 = vertices[indices[t + 2]]
		if (c - a).cross(b - a).y <= 0.0:
			down += 1
	expect(down == 0, "%d triangles face down" % down)
