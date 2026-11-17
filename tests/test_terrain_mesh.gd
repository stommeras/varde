extends "res://tests/test_case.gd"

const SIDE: int = TerrainMesh.CHUNK + 1


func test_chunks_cover_the_grid_and_face_up() -> void:
	var started: int = Time.get_ticks_msec()
	var meshes: Array[ArrayMesh] = TerrainMesh.build(island(0))
	print("TerrainMesh.build: %d ms" % (Time.get_ticks_msec() - started))
	var chunks: int = TerrainMesh.CHUNKS
	expect(meshes.size() == chunks * chunks, "%d chunks, expected %d" % [meshes.size(), chunks * chunks])
	var lowest: float = INF
	var highest: float = -INF
	for chunk: int in meshes.size():
		var vertices: PackedVector3Array = meshes[chunk].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var corner := Vector3((chunk % chunks) * TerrainMesh.CHUNK + 0.5, 0.0, (chunk / chunks) * TerrainMesh.CHUNK + 0.5)
		if vertices.size() != SIDE * SIDE:
			expect(false, "chunk %d has %d vertices, expected %d" % [chunk, vertices.size(), SIDE * SIDE])
			return
		if not is_equal_approx(vertices[0].x, corner.x) or not is_equal_approx(vertices[0].z, corner.z):
			expect(false, "chunk %d starts at %s, expected %s" % [chunk, vertices[0], corner])
			return
		# Godot stores indices as 16 bits when a surface has under 65536 vertices.
		var lods: Array = RenderingServer.mesh_get_surface(meshes[chunk].get_rid(), 0)["lods"]
		if lods.size() != TerrainMesh.STEPS.size() - 1 or lods[0]["edge_length"] != float(TerrainMesh.STEPS[1]) or lods[0]["index_data"].size() != TerrainMesh._indices(TerrainMesh.STEPS[1]).size() * 2:
			expect(false, "chunk %d has the coarser levels %s" % [chunk, lods.map(func(lod: Dictionary) -> Array: return [lod["edge_length"], lod["index_data"].size()])])
			return
		for vertex: Vector3 in vertices:
			lowest = minf(lowest, vertex.y)
			highest = maxf(highest, vertex.y)
	expect(lowest == 0.0, "the lowest vertex is at %f, expected the flat sea at 0.0" % lowest)
	expect(highest > 0.9 and highest <= 1.0, "the highest vertex is at %f, expected near 1.0" % highest)


## Chunks drawn at the same level meet without cracks when each edge vertex sits exactly on its
## neighbor's. The next test checks that each level keeps those edge vertices.
func test_neighboring_chunks_share_their_edges() -> void:
	var meshes: Array[ArrayMesh] = TerrainMesh.build(island(1))
	var chunks: int = TerrainMesh.CHUNKS
	var vertices: Array[PackedVector3Array] = []
	for mesh: ArrayMesh in meshes:
		vertices.append(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var mismatched: int = 0
	for chunk: int in meshes.size():
		var east: bool = chunk % chunks < chunks - 1
		var south: bool = chunk / chunks < chunks - 1
		for i: int in SIDE:
			if east and vertices[chunk][i * SIDE + SIDE - 1] != vertices[chunk + 1][i * SIDE]:
				mismatched += 1
			if south and vertices[chunk][(SIDE - 1) * SIDE + i] != vertices[chunk + chunks][i]:
				mismatched += 1
	expect(mismatched == 0, "%d edge vertices differ from their neighbor's" % mismatched)


func test_every_level_covers_the_chunk_and_faces_up() -> void:
	var vertices := PackedVector3Array()
	for row: int in SIDE:
		for column: int in SIDE:
			# A bumpy surface, so a triangle that winds the wrong way can't hide on flat ground.
			vertices.append(Vector3(column, sin(column * 0.7) * cos(row * 0.3), row))
	for step: int in TerrainMesh.STEPS:
		var indices: PackedInt32Array = TerrainMesh._indices(step)
		var quads: int = TerrainMesh.CHUNK / step
		expect(indices.size() == quads * quads * 6, "step %d has %d indices, expected %d" % [step, indices.size(), quads * quads * 6])
		var area: float = 0.0
		var down: int = 0
		var off_grid: int = 0
		for t: int in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[t]]
			var b: Vector3 = vertices[indices[t + 1]]
			var c: Vector3 = vertices[indices[t + 2]]
			# A clockwise triangle seen from above has cross(c - a, b - a) pointing up.
			var up: Vector3 = (c - a).cross(b - a)
			if up.y <= 0.0:
				down += 1
			area += up.y / 2.0
			for vertex: Vector3 in [a, b, c]:
				if int(vertex.x) % step != 0 or int(vertex.z) % step != 0:
					off_grid += 1
		expect(down == 0, "step %d: %d triangles face down" % [step, down])
		expect(off_grid == 0, "step %d: %d corners off the step's grid" % [step, off_grid])
		expect(is_equal_approx(area, TerrainMesh.CHUNK * TerrainMesh.CHUNK), "step %d covers %f cells, expected %d" % [step, area, TerrainMesh.CHUNK * TerrainMesh.CHUNK])
