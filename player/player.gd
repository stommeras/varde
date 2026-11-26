class_name Player
extends Node3D
## The figure the player walks. It moves freely in 8 directions, checks each step from cell to cell
## with Walkability, stands on the terrain mesh's surface, and keeps the game camera on it, trailing
## its height by CAMERA_LAG.

## Cells per second on any ground. Raising it crosses the island faster. At 5, walking across the
## 50 cells of a 960×540 screen at zoom 40 takes about 10 s. At 3.5 the walks between massifs, often
## 100 to 200 cells, felt slow, and at 6 the figure, about 1.5 units tall, crossed four of its own
## heights a second and looked like it was sprinting.
const SPEED: float = 5.0
## Seconds the player takes to reach full speed from standing, and to stop again. Raising it gives
## the figure more weight and makes it slide further after the key comes up. At 0 it starts and
## stops dead, which made it float.
const EASE_SECONDS: float = 0.15
## Seconds the camera takes to follow about two thirds of a change in the ground's height. While the
## player climbs, the camera lags below, so the figure rises on screen, and going down it sinks.
## Raising it shows climbing more and lets the figure drift further from the middle of the screen.
## With the camera locked on the feet, walking up a slope only slid the ground diagonally past a
## figure that never moved on screen.
const CAMERA_LAG: float = 0.8
## Longest frame the movement takes in one go. A longer one, such as a hitch while loading, moves
## the player by less than it lasted. It keeps a step under one cell, which _can_move() relies on.
const MAX_DELTA: float = 0.1
## Seconds the fade in front of the player takes to open or shut. Raising it makes the hole grow and
## shrink more slowly, and at 0 it pops open as soon as terrain hides the figure.
const FADE_SECONDS: float = 0.25
## World units between the samples hidden() takes toward the camera. Half a cell finds a ridge one
## cell wide, and raising it can step over a thin one.
const HIDE_STEP: float = 0.5
## World units the figure sits nearer the camera than its feet. The orthographic camera shows it on
## the same pixels, but terrain must stand this far in front of it to hide it. Without it the boots
## sink into a slope that rises to the side. Raising it lets the figure show over more of a bump or
## ridge that stands in front of it.
const DEPTH_PUSH: float = 0.3
## True while something else, such as a survey, holds the player still. The figure stands and takes
## no input, and the camera keeps following.
var frozen: bool = false
## A grid direction, x east and y south, the player walks in while frozen, for walks the game makes,
## such as up to a peak's top before a survey. Its length scales the speed.
var steer: Vector2 = Vector2.ZERO
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
## Cells per second, x east and y south. It eases toward SPEED in the direction held.
var _velocity: Vector2 = Vector2.ZERO
## World height the camera centers on, which trails the feet by CAMERA_LAG.
var _camera_height: float = 0.0
## True in god mode, which GodMode toggles. The player walks god_speed times faster and through
## anything the step check refuses, such as cliffs and the sea.
var god: bool = false
## Speed multiplier in god mode.
var god_speed: float = 1.0
## The feet in world units, unsnapped, where the fade centers.
var _feet: Vector3
## True while terrain hides the figure, which opens the fade.
var _hidden: bool = false
## How far the fade is open, from 0 to 1.
var _fade: float = 0.0
## The cell the last line of sight was cast from, or -1 before the first.
var _sight_cell: int = -1
## The WorkerThreadPool task casting the line of sight, or -1 when none runs. A cast from the summit
## takes about 35 ms natively, which would drop frames on the main thread.
var _sight_task: int = -1
## The cells the running task sees, written by the task and read once it completes.
var _sight_cells := PackedInt32Array()
## The way the figure faces, x east and y south, for the map's arrow.
var facing_direction: Vector2 = Vector2.DOWN


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
	# The terrain already holds the new island's knowledge, so a cast from the old one is dropped.
	_finish_sight(false)
	_sight_cell = -1
	_island = island
	grid_position = Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
	_velocity = Vector2.ZERO
	visible = true
	# The first cast runs here instead of on a worker, and its fog counts as already cleared, so the
	# run doesn't open in fog. At the start beach it takes about 4 ms.
	if terrain.knowledge != null:
		terrain.knowledge.mark_cells(LineOfSight.visible_cells(island, cell), Knowledge.Level.SEEN, Knowledge.LONG_AGO)
		_sight_cell = cell
	_update_position(1.0)


func _process(delta: float) -> void:
	if _island == null:
		return
	_fade = move_toward(_fade, 1.0 if _hidden else 0.0, delta / maxf(FADE_SECONDS, 0.001))
	terrain.fade_around(_feet, _fade)
	var step: float = minf(delta, MAX_DELTA)
	var direction: Vector2 = steer if frozen else walk_direction(Input.get_vector("move_left", "move_right", "move_up", "move_down"), camera.heading)
	_velocity = _velocity.move_toward(direction * SPEED, SPEED / maxf(EASE_SECONDS, 0.001) * step)
	if _velocity != Vector2.ZERO and (not frozen or steer != Vector2.ZERO):
		# The way it moves, not the keys, so a turn doesn't slide the figure backward while it eases.
		face(Vector2.from_angle(facing(_velocity) * PI / 4.0))
	var moved: Vector2 = grid_position
	if god:
		# Several cells a frame, which move() can't take, so it skips the step check.
		var edge: float = IslandData.SIZE - 0.001
		moved = (grid_position + _velocity * god_speed * step).clamp(Vector2.ZERO, Vector2(edge, edge))
	elif _velocity != Vector2.ZERO:
		moved = move(_island, grid_position, _velocity * step)
	if moved == grid_position:
		# Pushing into a wall moves nothing, so the legs stand instead of freezing mid-step, and the
		# player starts from standing when it turns away from the wall.
		_velocity = Vector2.ZERO
		_walked = 0.0
	else:
		_walked += moved.distance_to(grid_position)
	grid_position = moved
	# The camera keeps catching up on height after the player stops, so this runs every frame.
	_update_position(1.0 - exp(-delta / CAMERA_LAG))
	_update_sight()
	_figure.walk(_walked, _velocity.length() / SPEED)


# follow is the share of the gap between the camera's height and the feet's that it closes now.
func _update_position(follow: float) -> void:
	var point := Vector3(grid_position.x, height_at(_island, grid_position), grid_position.y)
	_camera_height = lerpf(_camera_height, point.y, follow)
	camera.focus = Vector3(point.x, _camera_height, point.z)
	camera.place()
	# The same snap as the camera's, so the figure moves on screen only in whole pixels, and only
	# while the camera catches up on its height.
	position = camera.snap(point) + camera.basis.z * DEPTH_PUSH
	_feet = point
	# The middle and the top of the figure. Terrain that only hides the feet leaves the fade shut, so
	# a small bump in front doesn't open a hole in the hills beside the player.
	var known: Knowledge = terrain.knowledge if terrain != null else null
	_hidden = hidden(_island, point + Vector3.UP * (Figure.HEIGHT / 2.0), camera.basis.z, known) \
		or hidden(_island, point + Vector3.UP * Figure.HEIGHT, camera.basis.z, known)


# Marks what the finished cast saw, and casts again once the player stands in a new cell. One cast
# runs at a time, so in god mode the player can cross cells that never get a cast of their own.
func _update_sight() -> void:
	if _sight_task >= 0 and WorkerThreadPool.is_task_completed(_sight_task):
		_finish_sight(true)
	var cell: int = _cell(grid_position)
	# God mode sees everything without learning it, so leaving it shows the fog the player left.
	if _sight_task >= 0 or cell == _sight_cell or terrain.knowledge == null or god:
		return
	_sight_cell = cell
	var island: IslandData = _island
	_sight_task = WorkerThreadPool.add_task(func() -> void: _sight_cells = LineOfSight.visible_cells(island, cell))


# Waits for the running cast, if any, and marks what it saw if keep is true.
func _finish_sight(keep: bool) -> void:
	if _sight_task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_sight_task)
	_sight_task = -1
	if keep:
		terrain.knowledge.mark_cells(_sight_cells, Knowledge.Level.SEEN)


func _exit_tree() -> void:
	# The task writes to this node, so it must end before the node is freed.
	_finish_sight(false)


## Turns the figure to face direction, x east and y south.
func face(direction: Vector2) -> void:
	facing_direction = direction.normalized()
	_figure.face(direction)


## The grid direction, x east and y south, that the walking keys' input means for a camera at heading,
## so up always walks away from the camera. It follows a turn while it runs.
static func walk_direction(input: Vector2, heading: float) -> Vector2:
	return input.rotated(-heading)


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
## With knowledge, land the player hasn't seen hides nothing, because the terrain shader draws its fog
## behind everything else.
static func hidden(island: IslandData, point: Vector3, toward: Vector3, knowledge: Knowledge = null) -> bool:
	var steps: int = ceili((IslandTerrain.SUMMIT_HEIGHT - point.y) / (toward.y * HIDE_STEP))
	for i: int in range(1, steps + 1):
		var sample: Vector3 = point + toward * (i * HIDE_STEP)
		var ground := Vector2(sample.x, sample.z)
		if knowledge != null and knowledge.levels[_cell(ground.clamp(Vector2.ZERO, Vector2(IslandData.SIZE - 0.001, IslandData.SIZE - 0.001)))] == Knowledge.Level.UNKNOWN:
			continue
		if height_at(island, ground) > sample.y:
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
