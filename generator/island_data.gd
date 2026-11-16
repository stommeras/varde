class_name IslandData
extends RefCounted
## Everything the generator knows about one island. Each array has SIZE * SIZE cells, row by row.

const SIZE: int = 1024

var island_seed: int
## Sea level is 0.0, the highest cell is exactly 1.0, and the sea floor is negative.
## A cell is land when its height is above 0.0.
var height: PackedFloat32Array
## 0.0 on the driest cell and 1.0 on the wettest, over sea and land alike.
var moisture: PackedFloat32Array
## A Ramps.Terrain value per cell. Water exactly where the height is 0.0 or below.
var material: PackedByteArray
## 1 on the main island, the largest connected land area, and 0 on islets and sea.
## Stats, peaks, vardes and points of interest use only these cells.
var main_island: PackedByteArray
## Milliseconds each generator step took, in the order the steps ran. Timing differs between runs,
## so this is the one field that the same seed doesn't reproduce.
var step_msec: Dictionary[String, int] = {}


## The array index of the cell at column x, row y.
static func index(x: int, y: int) -> int:
	return y * SIZE + x
