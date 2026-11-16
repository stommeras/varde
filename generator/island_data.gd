class_name IslandData
extends RefCounted
## Everything the generator knows about one island. Each array has SIZE * SIZE cells, row by row.

const SIZE: int = 1024

var island_seed: int
## Sea level is 0.0, the highest cell is exactly 1.0, and the sea floor is negative.
var height: PackedFloat32Array


static func index(x: int, y: int) -> int:
	return y * SIZE + x
