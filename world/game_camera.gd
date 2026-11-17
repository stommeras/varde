class_name GameCamera
extends Camera3D
## The game's orthographic camera. It faces north, looks down at tilt from vertical, and keeps focus
## in the middle of the screen. The game scene and the debug view both place it with place().

## Cells of ground from the top to the bottom of the screen, chosen by eye in milestone 2 and recorded
## in SPEC.md. Raising it shows more of the island at less detail, lowering it shows less, closer up.
const ZOOM: float = 80.0
## Degrees from looking straight down, chosen by eye in milestone 2 and recorded in SPEC.md. Raising it
## shows more of the slopes and less of the ground plan, lowering it flattens the view toward a map.
const TILT_DEGREES: float = 45.0
## How far the camera sits behind the point it looks at. An orthographic view doesn't change with
## distance, so this only has to keep the near plane in front of the camera. The worst case is the
## tallest summit at the steepest tilt and widest zoom, about 2250 units nearer than sea level.
const DISTANCE: float = 3000.0
## World units the camera's depth range reaches past the terrain on each side, so the summit and the
## farthest sea never touch the near or far plane.
const DEPTH_MARGIN: float = 2.0

## Cells of flat ground at sea level from the top to the bottom of the screen.
var zoom: float = ZOOM
## Degrees from looking straight down.
var tilt_degrees: float = TILT_DEGREES
## World units from sea level to the highest cell, which sets how near the near plane must come.
var summit_height: float = IslandTerrain.SUMMIT_HEIGHT
## The ground point at sea level in the middle of the screen.
var focus := Vector3(IslandData.SIZE / 2.0, 0.0, IslandData.SIZE / 2.0)


func _init() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL


## Moves and turns the camera to show focus at the current zoom and tilt. Call it after changing any of them.
func place() -> void:
	var tilt: float = deg_to_rad(tilt_degrees)
	rotation = Vector3(tilt - PI / 2.0, 0.0, 0.0)
	# Flat ground along north-south shrinks by cos(tilt) on screen, so the view is that much
	# shorter than the ground it covers.
	size = zoom * cos(tilt)
	# Godot ignores the sun's shadow distance for an orthographic camera and fits the shadow map around
	# the camera's whole depth range, so a range deeper than the terrain spreads the map thin. A ray
	# through the screen's center meets sea level DISTANCE from the camera, and the rays through the
	# top and bottom edges meet it zoom * sin(tilt) / 2 nearer and farther. The summit can stand
	# summit / cos(tilt) nearer than sea level on the same ray.
	var reach: float = zoom * sin(tilt) / 2.0
	near = DISTANCE - reach - summit_height / cos(tilt) - DEPTH_MARGIN
	far = DISTANCE + reach + DEPTH_MARGIN
	# A camera that moves by part of a pixel makes every edge and dither pattern crawl. Snapping its
	# position along its right and up axes to whole pixels moves the image in whole pixels instead.
	# focus keeps the exact position, so slow panning still adds up.
	var pixel: float = size / get_window().content_scale_size.y
	var local: Vector3 = basis.inverse() * (focus + basis.z * DISTANCE)
	local.x = snappedf(local.x, pixel)
	local.y = snappedf(local.y, pixel)
	position = basis * local
