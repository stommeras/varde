class_name Player
extends Node3D
## The figure the player walks. It moves freely in 8 directions, checks each step from cell to cell
## with Walkability, stands on the terrain mesh's surface, and keeps the game camera centered on it.

## Cells per second on open ground. Raising it crosses the island faster. At 6, walking across the
## 142 cells of a 960×540 screen at zoom 80 takes about 24 s.
const SPEED: float = 6.0
## Longest frame the movement takes in one go. A longer one, such as a hitch while loading, moves
## the player by less than it lasted. It keeps a step under one cell, which _can_move() relies on.
const MAX_DELTA: float = 0.1
## Cells walked per frame of the walk cycle. Raising it slows the legs against the ground.
const CELLS_PER_FRAME: float = 0.5
## Size of one frame of the figure in pixels.
const FRAME_SIZE := Vector2i(6, 10)
## The walk cycle as columns of the sheet: standing, left foot forward, standing, right foot forward.
const CYCLE: Array[int] = [0, 1, 0, 2]

## Rows of the sheet. West has no row of its own, because it is east flipped.
enum Facing { SOUTH, NORTH, EAST, WEST }

## The camera that follows the player. Set it before adding the player.
var camera: GameCamera
## The player's exact position on the grid, x east and y south, in cells. The node's own position
## is this snapped to whole screen pixels.
var grid_position: Vector2
var _island: IslandData
var _sprite := Sprite3D.new()
var _facing: Facing = Facing.SOUTH
## Cells walked, which drives the walk cycle.
var _walked: float = 0.0


func _ready() -> void:
	_sprite.texture = ImageTexture.create_from_image(sheet())
	_sprite.hframes = 3
	_sprite.vframes = 3
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Facing the camera keeps one texel on one screen pixel at the camera's tilt.
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# The billboard leans back with the camera, so on a slope up to the north the terrain would cut
	# off its head. Drawn over the terrain instead, the figure shows behind a ridge too, as it will
	# once #46 fades the terrain in front of it.
	_sprite.no_depth_test = true
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprite.pixel_size = camera.pixel()
	# Feet on the node's position. An even frame size keeps the frame's edges on whole pixels.
	_sprite.offset = Vector2(0, FRAME_SIZE.y / 2)
	add_child(_sprite)
	# Hidden until place() puts it on an island, so it doesn't stand at the grid's corner meanwhile.
	visible = false
	_show_frame()


## Puts the player on the center of cell on island and moves the camera there. A cell of -1, from an
## island with no start, leaves the player out.
func place(island: IslandData, cell: int) -> void:
	if cell < 0:
		return
	_island = island
	grid_position = Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
	visible = true
	_update_position()


func _process(delta: float) -> void:
	if _island == null:
		return
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == Vector2.ZERO:
		_walked = 0.0
		_show_frame()
		return
	_facing = _facing_of(direction)
	var speed: float = SPEED * Walkability.speed(_island, _cell(grid_position))
	var moved: Vector2 = move(_island, grid_position, direction * speed * minf(delta, MAX_DELTA))
	# Pushing into a wall moves nothing, so the legs stand instead of freezing mid-step.
	_walked = 0.0 if moved == grid_position else _walked + moved.distance_to(grid_position)
	grid_position = moved
	_update_position()
	_show_frame()


func _update_position() -> void:
	var point := Vector3(grid_position.x, height_at(_island, grid_position), grid_position.y)
	camera.focus = point
	camera.place()
	# The same snap as the camera's, so the figure stays on the same screen pixel while the ground
	# moves under it in whole pixels.
	position = camera.snap(point)


func _show_frame() -> void:
	var column: int = CYCLE[int(_walked / CELLS_PER_FRAME) % CYCLE.size()]
	_sprite.flip_h = _facing == Facing.WEST
	_sprite.frame = mini(_facing, Facing.EAST) * 3 + column


## The facing for a walking direction. Diagonals face east or west, where the walk cycle shows best.
static func _facing_of(direction: Vector2) -> Facing:
	if absf(direction.x) >= absf(direction.y) - 0.01:
		return Facing.EAST if direction.x > 0.0 else Facing.WEST
	return Facing.SOUTH if direction.y > 0.0 else Facing.NORTH


## Where the player ends up moving by motion from from. A move that crosses into a cell the step
## check refuses keeps only its east-west or north-south part, so the player slides along a wall
## instead of stopping dead. motion must be shorter than one cell.
static func move(island: IslandData, from: Vector2, motion: Vector2) -> Vector2:
	# A longer motion could reach a cell two away, which can_step() would take for a neighbor.
	assert(absf(motion.x) < 1.0 and absf(motion.y) < 1.0, "Player.move: motion of a cell or more")
	for to: Vector2 in [from + motion, Vector2(from.x + motion.x, from.y), Vector2(from.x, from.y + motion.y)]:
		if _can_move(island, from, to):
			return to
	return from


static func _can_move(island: IslandData, from: Vector2, to: Vector2) -> bool:
	var a: int = _cell(from)
	var b: int = _cell(to)
	return a == b or Walkability.can_step(island, a, b)


static func _cell(point: Vector2) -> int:
	return IslandData.index(int(point.x), int(point.y))


## World height of the terrain mesh at point, in world units. The mesh has a vertex on each cell's
## center and splits each square between four centers along the diagonal from north-west to
## south-east, so this interpolates over the same triangles and the feet never float or sink.
static func height_at(island: IslandData, point: Vector2) -> float:
	var x: float = point.x - 0.5
	var z: float = point.y - 0.5
	var column: int = floori(x)
	var row: int = floori(z)
	var u: float = x - column
	var v: float = z - row
	var nw: float = _vertex(island, column, row)
	var se: float = _vertex(island, column + 1, row + 1)
	var h: float
	if u >= v:
		var ne: float = _vertex(island, column + 1, row)
		h = nw + (ne - nw) * u + (se - ne) * v
	else:
		var sw: float = _vertex(island, column, row + 1)
		h = nw + (sw - nw) * v + (se - sw) * u
	return h * IslandTerrain.SUMMIT_HEIGHT


# The mesh lays the sea flat at 0.0.
static func _vertex(island: IslandData, column: int, row: int) -> float:
	var size: int = IslandData.SIZE
	return maxf(island.height[IslandData.index(clampi(column, 0, size - 1), clampi(row, 0, size - 1))], 0.0)


## The figure's frames, drawn from rectangles in the colors of Ramps.FIGURE. Rows are south, north and
## east, and columns are standing, left foot forward and right foot forward.
static func sheet() -> Image:
	var image := Image.create_empty(FRAME_SIZE.x * 3, FRAME_SIZE.y * 3, false, Image.FORMAT_RGBA8)
	for facing: int in 3:
		for column: int in 3:
			_draw_frame(image, Vector2i(column, facing) * FRAME_SIZE, facing, column)
	return image


# step is 0 standing, 1 with the left foot forward and 2 with the right. Colors index Ramps.FIGURE:
# 0 boots and hair, 1 trousers and pack, 2 coat shade, 3 coat, 4 skin.
static func _draw_frame(image: Image, origin: Vector2i, facing: int, step: int) -> void:
	var ramp: PackedColorArray = Ramps.FIGURE
	var rect := func(x: int, y: int, w: int, h: int, color: int) -> void:
		image.fill_rect(Rect2i(origin + Vector2i(x, y), Vector2i(w, h)), ramp[color])
	if facing == Facing.EAST:
		rect.call(2, 0, 3, 1, 3)  # cap
		rect.call(2, 1, 3, 2, 4)  # face
		rect.call(2, 1, 1, 2, 0)  # hair at the back of the head
		rect.call(1, 3, 1, 3, 1)  # pack
		rect.call(2, 3, 3, 3, 3)  # coat
		rect.call(2, 6, 3, 1, 2)  # hem
		if step == 0:
			rect.call(3, 3, 1, 3, 2)  # arm at the side
			rect.call(3, 6, 1, 1, 4)
			rect.call(2, 7, 2, 2, 1)
			rect.call(2, 9, 3, 1, 0)
		else:
			# The near arm swings against the near leg.
			rect.call(3, 3, 1, 2, 2)
			rect.call(2 if step == 1 else 4, 5, 1, 1, 4)
			rect.call(2, 7, 2, 1, 1)
			rect.call(1, 8, 1, 1, 1)  # back leg
			rect.call(1, 9, 1, 1, 0)
			rect.call(4, 8, 1, 1, 1)  # front leg
			rect.call(4, 9, 2, 1, 0)
		return
	var front: bool = facing == Facing.SOUTH
	rect.call(1, 0, 4, 1, 3)  # cap
	rect.call(1, 1, 4, 2, 4 if front else 0)  # face or hair
	rect.call(0, 3, 6, 3, 3)  # coat
	rect.call(0, 3, 1, 3, 2)  # arms
	rect.call(5, 3, 1, 3, 2)
	if not front:
		rect.call(1, 3, 4, 3, 1)  # pack
	rect.call(1, 6, 4, 1, 2)  # hem
	rect.call(1, 7, 4, 1, 1)  # hips
	# Each leg is its column of trousers ending in a boot. A foot forward lifts that leg a pixel and
	# raises the hand on the other side.
	for side: int in 2:
		var x: int = 1 if side == 0 else 4
		var lifted: bool = step == side + 1
		var swung: bool = step != 0 and not lifted
		rect.call(0 if side == 0 else 5, 5 if swung else 6, 1, 1, 4)  # hand
		rect.call(x, 8, 1, 1, 0 if lifted else 1)
		if not lifted:
			rect.call(x, 9, 1, 1, 0)
