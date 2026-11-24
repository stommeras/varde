class_name GameCamera
extends Camera3D
## The game's orthographic camera. It looks down at tilt from vertical, faces north until the player
## turns it in quarter turns, and keeps focus in the middle of the screen. The game scene and the
## debug view both place it with place().

## Cells of ground from the top to the bottom of the screen, recorded in SPEC.md. Raising it shows more
## of the island at less detail, lowering it shows less, closer up. Milestone 2 chose 80 by eye, where
## the figure was only about 6×12 pixels, so the game moved to 40.
const ZOOM: float = 40.0
## Degrees from looking straight down, chosen by eye in milestone 2 and recorded in SPEC.md. Raising it
## shows more of the slopes and less of the ground plan, lowering it flattens the view toward a map.
const TILT_DEGREES: float = 45.0
## World units between the camera and its near plane. An orthographic view doesn't change with
## distance, but Godot fits the sun's shadow map from the camera itself out to the far plane, so every
## unit of gap spreads the map thinner. With the camera 3000 units back, a figure 1.5 units tall cast
## no shadow at all. Raising it changes nothing on screen except coarser shadows.
const NEAR_GAP: float = 1.0
## World units the camera's depth range reaches past the terrain on each side, so the summit and the
## farthest sea never touch the near or far plane.
const DEPTH_MARGIN: float = 2.0
## Seconds a quarter turn takes, eased in and out, so the player sees the world turn and keeps their
## bearings. Raising it makes the turn calmer, and at 0 it cuts straight to the new heading.
const TURN_SECONDS: float = 0.4

## Cells of flat ground at sea level from the top to the bottom of the screen.
var zoom: float = ZOOM
## Degrees from looking straight down.
var tilt_degrees: float = TILT_DEGREES
## World units from sea level to the highest cell, which sets how near the near plane must come.
var summit_height: float = IslandTerrain.SUMMIT_HEIGHT
## The point in the middle of the screen. The game puts it on the player, the debug view at sea level.
var focus := Vector3(IslandData.SIZE / 2.0, 0.0, IslandData.SIZE / 2.0)
## Radians the camera has turned counterclockwise from north, seen from above, so a quarter turn
## faces west. It eases between whole quarters while a turn runs.
var heading: float = 0.0
## Quarter turns counterclockwise from north the camera is turning to, or stands at.
var _quarters: int = 0
## The heading the running turn started from, and the seconds since it started.
var _turn_from: float = 0.0
var _turn_time: float = TURN_SECONDS


func _init() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL


## Starts turning the camera by quarters quarter turns, counterclockwise from above for a positive
## count. A turn started during another starts from where the camera has got to.
func turn(quarters: int) -> void:
	_turn_from = heading
	_quarters += quarters
	_turn_time = 0.0


## The heading the camera is turning to, or stands at, in radians as heading counts them.
func target_heading() -> float:
	return _quarters * PI / 2.0


func _process(delta: float) -> void:
	if _turn_time >= TURN_SECONDS:
		return
	_turn_time += delta
	# The last frame lands on the whole quarter, so the camera rests on the same pixel grid at every heading.
	heading = lerpf(_turn_from, target_heading(), smoothstep(0.0, 1.0, _turn_time / maxf(TURN_SECONDS, 0.001)))
	if _turn_time >= TURN_SECONDS:
		heading = target_heading()


## Moves and turns the camera to show focus at the current zoom, tilt and heading. Call it after
## changing any of them. The player places the camera every frame, which picks up a running turn.
func place() -> void:
	var tilt: float = deg_to_rad(tilt_degrees)
	# Godot applies the yaw before the pitch, so the camera turns about the world's up axis.
	rotation = Vector3(tilt - PI / 2.0, heading, 0.0)
	# Flat ground along the view shrinks by cos(tilt) on screen, so the view is that much
	# shorter than the ground it covers.
	size = zoom * cos(tilt)
	# Godot ignores the sun's shadow distance for an orthographic camera and fits the shadow map around
	# the camera's whole depth range, so a range deeper than the terrain spreads the map thin. A ray
	# through the screen's center meets focus, and the rays through the top and bottom edges meet the
	# same height zoom * sin(tilt) / 2 nearer and farther. Along a ray, sea level lies focus.y / cos(tilt)
	# farther than focus and the summit the rest of its height nearer. The camera sits NEAR_GAP in front
	# of the nearest of them.
	var reach: float = zoom * sin(tilt) / 2.0
	var nearest: float = reach + (summit_height - focus.y) / cos(tilt) + DEPTH_MARGIN
	near = NEAR_GAP
	far = NEAR_GAP + nearest + reach + focus.y / cos(tilt) + DEPTH_MARGIN
	# A camera that moves by part of a pixel makes every edge and dither pattern crawl. Snapping its
	# position along its right and up axes to whole pixels moves the image in whole pixels instead.
	# focus keeps the exact position, so slow panning still adds up. Moving along basis.z doesn't
	# move the image, so snapping focus first and then backing off gives the same pixel grid as snap().
	position = snap(focus) + basis.z * (nearest + NEAR_GAP)


## World units one screen pixel covers.
func pixel() -> float:
	return size / get_window().content_scale_size.y


## point moved to the nearest whole pixel on screen, along the camera's right and up axes. A sprite
## snapped with it sits on the same pixel grid as the camera, so it doesn't shimmer as it moves.
func snap(point: Vector3) -> Vector3:
	var local: Vector3 = basis.inverse() * point
	local.x = snappedf(local.x, pixel())
	local.y = snappedf(local.y, pixel())
	return basis * local
