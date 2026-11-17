class_name Player
extends Node3D
## The figure the player walks. It moves freely in 8 directions, checks each step from cell to cell
## with Walkability, stands on the terrain mesh's surface, and keeps the game camera centered on it.

## Cells per second on any ground. Raising it crosses the island faster. At 6, walking across the
## 142 cells of a 960×540 screen at zoom 80 takes about 24 s.
const SPEED: float = 6.0
## Longest frame the movement takes in one go. A longer one, such as a hitch while loading, moves
## the player by less than it lasted. It keeps a step under one cell, which _can_move() relies on.
const MAX_DELTA: float = 0.1
## Seconds the fade in front of the player takes to open or shut. Raising it makes the hole grow and
## shrink more slowly, and at 0 it pops open as soon as terrain hides the figure.
const FADE_SECONDS: float = 0.25
## World units between the samples hidden() takes toward the camera. Half a cell finds a ridge one
## cell wide, and raising it can step over a thin one.
const HIDE_STEP: float = 0.5
## Speed multiplier in god mode. At 8 the player crosses the 1024-cell grid in about 21 s.
const GOD_SPEED: float = 8.0
## The camera that follows the player. Set it before adding the player.
var camera: GameCamera
## The terrain that fades in front of the player. Set it before placing the player.
var terrain: IslandTerrain
## The player's exact position on the grid, x east and y south, in cells. The node's own position
## is this snapped to whole screen pixels.
var grid_position: Vector2
var _island: IslandData
var _figure := Figure.new()
## Cells walked, which drives the walk cycle.
var _walked: float = 0.0
## For checking terrain while tuning: G toggles it in debug builds. The player walks GOD_SPEED times
## faster and through anything the step check refuses, such as cliffs and the sea.
var _god: bool = false
## The feet in world units, unsnapped, where the fade centers.
var _feet: Vector3
## True while terrain hides the figure, which opens the fade.
var _hidden: bool = false
## How far the fade is open, from 0 to 1.
var _fade: float = 0.0


func _ready() -> void:
	# The player starts facing south, toward the camera.
	_figure.face(Vector2.DOWN)
	add_child(_figure)
	# Hidden until place() puts it on an island, so it doesn't stand at the grid's corner meanwhile.
	visible = false


## Puts the player on the center of cell on island and moves the camera there. A cell of -1, from an
## island with no start, leaves the player out.
func place(island: IslandData, cell: int) -> void:
	if cell < 0:
		return
	_island = island
	grid_position = Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
	visible = true
	_update_position()


func _unhandled_key_input(event: InputEvent) -> void:
	# A raw key, not an input action, because the editor rewrites project.godot while it's open.
	var key := event as InputEventKey
	if OS.is_debug_build() and key.pressed and not key.echo and key.physical_keycode == KEY_G:
		_god = not _god
		print("God mode ", "on" if _god else "off")


func _process(delta: float) -> void:
	if _island == null:
		return
	_fade = move_toward(_fade, 1.0 if _hidden else 0.0, delta / maxf(FADE_SECONDS, 0.001))
	terrain.fade_around(_feet, _fade)
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == Vector2.ZERO:
		_walked = 0.0
		_figure.walk(_walked)
		return
	_figure.face(Vector2.from_angle(facing(direction) * PI / 4.0))
	var motion: Vector2 = direction * SPEED * minf(delta, MAX_DELTA)
	var moved: Vector2
	if _god:
		# Several cells a frame, which move() can't take, so it skips the step check.
		var edge: float = IslandData.SIZE - 0.001
		moved = (grid_position + motion * GOD_SPEED).clamp(Vector2.ZERO, Vector2(edge, edge))
	else:
		moved = move(_island, grid_position, motion)
	# Pushing into a wall moves nothing, so the legs stand instead of freezing mid-step.
	_walked = 0.0 if moved == grid_position else _walked + moved.distance_to(grid_position)
	grid_position = moved
	_update_position()
	_figure.walk(_walked)


func _update_position() -> void:
	var point := Vector3(grid_position.x, height_at(_island, grid_position), grid_position.y)
	camera.focus = point
	camera.place()
	# The same snap as the camera's, so the figure stays on the same screen pixel while the ground
	# moves under it in whole pixels.
	position = camera.snap(point)
	_feet = point
	# The middle and the top of the figure. Terrain that only hides the feet leaves the fade shut, so
	# a small bump in front doesn't open a hole in the hills beside the player.
	_hidden = hidden(_island, point + Vector3.UP * (Figure.HEIGHT / 2.0), camera.basis.z) \
		or hidden(_island, point + Vector3.UP * Figure.HEIGHT, camera.basis.z)


## The nearest of the 8 facings to a walking direction, x east and y south, counted clockwise from
## east in steps of 45°.
static func facing(direction: Vector2) -> int:
	return posmod(roundi(direction.angle() / (PI / 4.0)), 8)


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


## True when terrain stands between point, in world units, and a camera that looks along -toward.
## It steps from point toward the camera until the line rises above the summit. toward must point up.
static func hidden(island: IslandData, point: Vector3, toward: Vector3) -> bool:
	var steps: int = ceili((IslandTerrain.SUMMIT_HEIGHT - point.y) / (toward.y * HIDE_STEP))
	for i: int in range(1, steps + 1):
		var sample: Vector3 = point + toward * (i * HIDE_STEP)
		if height_at(island, Vector2(sample.x, sample.z)) > sample.y:
			return true
	return false


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
