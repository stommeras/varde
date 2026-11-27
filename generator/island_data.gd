class_name IslandData
extends RefCounted
## Everything the generator knows about one island. Each array has SIZE * SIZE cells, row by row.

const SIZE: int = 1024
## Meters per cell, and per world unit up and down, since the world uses one unit in every direction.
## A map scale, not the figure's: at 10 the island is about 10 km across and the summit stands
## Walkability.SUMMIT_UNITS × 10 = 1000 m high, while the figure, drawn 1.5 units tall, would be 15 m.
## The figure-true scale of about 1.2 m made a 120 m summit with snow on it.
const METERS_PER_CELL: float = 10.0

var island_seed: int
## Sea level is 0.0, the highest cell is exactly 1.0, and the sea floor is negative.
## A cell is land when its height is above 0.0. Lakes are flat, filled up to the lowest point on
## their rim.
var height: PackedFloat32Array
## 0.0 on the driest cell and 1.0 on the wettest, over sea and land alike.
var moisture: PackedFloat32Array
## A Ramps.Terrain value per cell. Water exactly where the height is 0.0 or below.
var material: PackedByteArray
## 1 on the main island, the largest connected land area, and 0 on islets and sea.
## Stats, peaks, vardes and points of interest use only these cells.
var main_island: PackedByteArray
## Each river's cells, from its spring down to the first sea cell, or to the cell of an earlier
## river it flows into. Consecutive cells are neighbors, edge or corner.
var rivers: Array[PackedInt32Array] = []
## 1 on every cell a river or lake covers and 0 elsewhere. Rivers widen downstream, so this covers
## more than the cells in rivers.
var fresh_water: PackedByteArray
## 1 on every cell a lake covers and 0 elsewhere, so the fresh water cells it leaves out are rivers.
var lake: PackedByteArray
## 1 on every land cell next to a step steeper than the walk limit and 0 elsewhere. The player can't
## stand on it, and the terrain shader draws it as cliff rock. Walkability.mark_cliffs() builds it.
var cliff: PackedByteArray
## Every peak of the main island that rises at least Peaks.MIN_PROMINENCE times the summit's height
## above its key saddle, highest first, so peaks[0] is the summit.
var peaks: Array[Peak] = []
## The top cells of the contender peaks, whose heights lie in a narrow band under the summit (see
## Contenders). contenders[0] is the true summit, the same cell as peaks[0].
var contenders: PackedInt32Array
## The cell the player starts on, a beach cell of the main island beside the wreck, or -1 if the
## generator found none.
var start: int = -1
## The shore cell of the landing beach the shipwreck lies on, or -1 with no start. See Landing.
var wreck: int = -1
## The cells of a walk from start to the summit's top or a cell beside it, start first. Every step
## passes Walkability.can_step(). Empty with no start. The summit's line of old vardes follows it.
var route := PackedInt32Array()
## The cells of the old vardes, one line up each marked peak after another, each line foot first.
## See Trail.
var vardes := PackedInt32Array()
## A Trail.Kind per varde, in the order of vardes.
var varde_kinds := PackedByteArray()
## The top cell of the peak each varde's line climbs, in the order of vardes. The last varde of each
## line holds its note.
var varde_peaks := PackedInt32Array()
## The cells of each lake, largest first. See Features.
var lakes: Array[PackedInt32Array] = []
## The cell where each river that runs into an earlier one meets it, in the order of rivers.
var river_forks := PackedInt32Array()
## The sea cell at the head of each cove of the main island, farthest in from the open sea, largest cove first. See Features.
var coves := PackedInt32Array()
## The cells of the largest connected forest on the main island.
var forest := PackedInt32Array()
## Milliseconds each generator step took, in the order the steps ran. Timing differs between runs,
## so this is the one field that the same seed doesn't reproduce.
var step_msec: Dictionary[String, int] = {}


## Meters above sea level of a height in the units of the height array, negative under the sea.
static func meters(cell_height: float) -> float:
	return cell_height * Walkability.SUMMIT_UNITS * METERS_PER_CELL


## The middle of cell in grid units, x east and y south.
static func center(cell: int) -> Vector2:
	return Vector2(cell % SIZE + 0.5, cell / SIZE + 0.5)


## The array index of the cell at column x, row y.
static func index(x: int, y: int) -> int:
	return y * SIZE + x
