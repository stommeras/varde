class_name Backdrop
extends Sprite2D
## The island behind the title screen. A still image that game/render_backdrop.gd rendered ahead of
## time shows from the first frame, while the same island generates on a background thread. Once it
## is ready, the still fades out over the live terrain, with its moving water, at the same spot. Later
## title screens reuse the island and show it live at once. The view starts at a random edge of the
## island, pans in toward the middle, and turns back in a slow arc whenever it drifts out past the
## land, so it doesn't drift off over open sea.

## Text the seed comes from, as if typed into the seed field. Chosen by eye from frames of a few
## candidates.
const SEED_TEXT: String = "varde"
## Cells of ground from the top to the bottom of the screen. Far above the game's zoom, so the island
## reads as a whole. Raising it shows more island, smaller. Render the image again after changing it.
const ZOOM: float = 256.0
const IMAGE_PATH: String = "res://game/backdrop.png"
## Screen pixels the view moves per second. 10 is about 4 cells a second at zoom 256. Raising it makes
## the drift livelier, lowering it calmer.
const SPEED: float = 10.0
## How fast the view turns back once it's past the land, as a share of the remaining turn per second.
## Raising it makes tighter turns, lowering it wider arcs that show more sea.
const TURN: float = 0.3
## Screen pixels inside the farthest the view can go where the turn begins, and where the view starts.
## The image covers the whole grid, and its outer part is open sea. At 400 the first frame of a launch
## has land on screen, and the arc ends before the view runs off the image. Lowering it starts further
## out over more sea, raising it keeps the view on a smaller middle part of the island.
const TURN_MARGIN: float = 400.0
## Radians the first heading may miss the middle by, so each launch takes a different line.
const AIM_SPREAD: float = 0.4
## Seconds the still takes to fade out over the live island.
const FADE_SECONDS: float = 1.0

# ponytail: holds the island and its meshes, about 40 MB, through every run. Rebuild them on return to
# the title screen if memory gets tight, as on the web.
static var _island: IslandData
static var _meshes: Array[ArrayMesh]

var _terrain := IslandTerrain.new()
var _camera := GameCamera.new()
var _loader := IslandLoader.new()
## The image pixel in the middle of the screen.
var _center: Vector2
## Radians, as Vector2.angle() gives them.
var _heading: float


## Cells of ground one image pixel covers, across and down, for a screen screen_height pixels tall.
## Ground along z shows cos(tilt) as long on screen, so a pixel down covers more of it.
static func pixel_cells(screen_height: float) -> Vector2:
	var tilt: float = deg_to_rad(GameCamera.TILT_DEGREES)
	var across: float = ZOOM * cos(tilt) / screen_height
	return Vector2(across, across / cos(tilt))


## The ground at sea level under the image's top left corner, as x and z in cells. The image covers
## the grid, and its top reaches a summit's height times tan(tilt) further north, since high ground
## shows that much north of its cell. Snapped to the camera's pixel grid, so the live view lines up
## with the image.
static func top_left(screen_height: float) -> Vector2:
	var tilt: float = deg_to_rad(GameCamera.TILT_DEGREES)
	return Vector2(0.0, snappedf(-IslandTerrain.SUMMIT_HEIGHT * tan(tilt), pixel_cells(screen_height).y))


func _ready() -> void:
	texture = load(IMAGE_PATH)
	centered = false
	_camera.zoom = ZOOM
	add_child(_terrain)
	add_child(_camera)
	add_child(Sun.new())
	var steer: Rect2 = _inside().grow(-TURN_MARGIN)
	var middle: Vector2 = steer.get_center()
	# A point far out in a random direction, pulled back onto the edge of the turning box.
	var far: Vector2 = middle + Vector2.from_angle(randf() * TAU) * steer.size.length()
	_center = far.clamp(steer.position, steer.end)
	_heading = (middle - _center).angle() + randf_range(-AIM_SPREAD, AIM_SPREAD)
	_place()
	if _island != null:
		self_modulate.a = 0.0
		_show()
		return
	_loader.quiet = true
	_loader.loaded.connect(_on_loaded)
	add_child(_loader)
	_loader.start(IslandLoader.seed_from(SEED_TEXT))


func _process(delta: float) -> void:
	var steer: Rect2 = _inside().grow(-TURN_MARGIN)
	if not steer.has_point(_center):
		_heading = lerp_angle(_heading, (steer.get_center() - _center).angle(), minf(TURN * delta, 1.0))
	_center += Vector2.from_angle(_heading) * SPEED * delta
	_place()


# Where the middle of the screen can go with the whole screen still on the image.
func _inside() -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	return Rect2(screen / 2.0, texture.get_size() - screen)


func _place() -> void:
	var inside: Rect2 = _inside()
	_center = _center.clamp(inside.position, inside.end)
	var screen: Vector2 = get_viewport_rect().size
	# Whole pixels, so the dither pattern doesn't shimmer. The camera snaps itself.
	position = (screen / 2.0 - _center).round()
	var ground: Vector2 = top_left(screen.y) + _center * pixel_cells(screen.y)
	_camera.focus = Vector3(ground.x, 0.0, ground.y)
	_camera.place()


func _on_loaded(island: IslandData, meshes: Array[ArrayMesh], _msec: int) -> void:
	_island = island
	_meshes = meshes
	_show()
	create_tween().tween_property(self, "self_modulate:a", 0.0, FADE_SECONDS)


func _show() -> void:
	_terrain.show_island(_meshes, _island)
	# The backdrop shows the whole island, with no fog.
	_terrain.knowledge.mark_all(Knowledge.Level.SURVEYED, Knowledge.LONG_AGO)
