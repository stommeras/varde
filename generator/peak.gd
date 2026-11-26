class_name Peak
extends RefCounted
## One peak on the main island, as Peaks finds it.

## Cells from a peak's top within which the player can survey it. Raising it lets the player survey
## from further down the slope. The figure walks up beside the top before the survey starts, so the
## survey still happens on the top, and at 3 the player had to find the top's few cells first.
const ZONE_RADIUS: float = 5.0

## The array index of the peak's highest cell.
var cell: int
## The cell's height, where the summit is 1.0.
var height: float
## How far the peak rises above its key saddle, the lowest pass to any higher peak, in the same
## units as height. The summit has no higher peak, so its prominence is its height above the sea.
var prominence: float


func _init(peak_cell: int, peak_height: float, peak_prominence: float) -> void:
	cell = peak_cell
	height = peak_height
	prominence = peak_prominence
