class_name Backdrop
extends Sprite2D
## The island behind the title screen, a still image that game/render_backdrop.gd rendered ahead of
## time, so the title screen shows it from the first frame. The view starts at a random edge of the
## island, pans in toward the middle, and turns back in a slow arc whenever it drifts out past the
## land, so it never settles on open sea.

const IMAGE: Texture2D = preload("res://game/backdrop.png")
## Screen pixels the view moves per second. 10 is about 4 cells a second at the image's zoom of 256.
## Raising it makes the drift livelier, lowering it calmer.
const SPEED: float = 10.0
## How fast the view turns back once it's past the land, as a share of the remaining turn per second.
## Raising it makes tighter turns, lowering it wider arcs that show more sea.
const TURN: float = 0.3
## Screen pixels inside the image's edge where the turn begins, so the arc ends before the view runs
## off the image. Lowering it reaches further out but risks showing the edge.
const TURN_MARGIN: float = 200.0
## Radians the first heading may miss the middle by, so each launch takes a different line.
const AIM_SPREAD: float = 0.4

## The image pixel in the middle of the screen.
var _center: Vector2
## Radians, as Vector2.angle() gives them.
var _heading: float


func _ready() -> void:
	texture = IMAGE
	centered = false
	var steer: Rect2 = _inside().grow(-TURN_MARGIN)
	var middle: Vector2 = steer.get_center()
	# A point far out in a random direction, pulled back onto the edge of the turning box.
	var far: Vector2 = middle + Vector2.from_angle(randf() * TAU) * steer.size.length()
	_center = far.clamp(steer.position, steer.end)
	_heading = (middle - _center).angle() + randf_range(-AIM_SPREAD, AIM_SPREAD)
	_place()


func _process(delta: float) -> void:
	var steer: Rect2 = _inside().grow(-TURN_MARGIN)
	if not steer.has_point(_center):
		_heading = lerp_angle(_heading, (steer.get_center() - _center).angle(), minf(TURN * delta, 1.0))
	_center += Vector2.from_angle(_heading) * SPEED * delta
	_place()


# Where the middle of the screen can go with the whole screen still on the image.
func _inside() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	return Rect2(screen / 2.0, IMAGE.get_size() - screen)


func _place() -> void:
	var inside: Rect2 = _inside()
	_center = _center.clamp(inside.position, inside.end)
	# Whole pixels, so the dither pattern doesn't shimmer.
	position = (get_viewport_rect().size / 2.0 - _center).round()
