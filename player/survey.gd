class_name Survey
extends Node
## Surveying from a peak. Inside a peak's survey zone it shows "Kartlegg toppen", and the survey
## action walks the figure up beside the top and starts the survey: the camera pulls out and turns once around in quarter turns, the
## figure turns with it to look out over each side, and the fog clears from the surveyed land in a ring that spreads from the peak, then the figure stacks a
## varde on the peak as the camera comes back. Each peak can be surveyed once.

## Cells from a peak's top within which the player can survey it. Peak holds the value and its
## tuning notes.
const ZONE_RADIUS: float = Peak.ZONE_RADIUS
## Cells from a peak's top within which a ring floats over the edge of its zone, so the player can
## find the top. Raising it shows the ring from further down. It reaches twice the zone's radius.
const MARKER_REACH: float = 10.0
## Seconds the zone ring takes to dither in or out.
const MARKER_FADE_SECONDS: float = 0.5
## How many times the walking view radius a survey reaches.
const REACH_SCALE: float = 2.0
## Seconds the figure and the camera take to turn once around, looking out. Raising it slows the
## whole reveal. At 3 s a smooth turn of the figure looked hurried.
const LOOK_SECONDS: float = 5.0
## Seconds the ring of clearing fog takes to reach the edge of the survey. Shorter than LOOK_SECONDS,
## so the fog has cleared from the farthest land before the camera comes back in.
const RING_SECONDS: float = 4.5
## Quarter turns the camera makes while the figure looks around, clockwise, so the player sees the fog clear on every side of the peak. Each side holds still for LOOK_SECONDS / 4
## less the turn. Quarter steps instead of a smooth spin, because the camera snaps to its pixel grid
## only on whole quarters, and between them the dither and the edges shimmer. 4 brings the camera
## back to the heading it started at, and 0 keeps it still.
const LOOK_TURNS: int = 4
## Seconds the stones take to go up, while the camera eases back in.
const BUILD_SECONDS: float = 1.5
## Seconds the camera takes to pull out at the start.
const ZOOM_SECONDS: float = 2.0
## Cells from the top to the bottom of the screen at the furthest pull-out. At 120 it shows three
## times the walking view, half the survey's radius from the summit. At 80 the pull-out was too tame,
## and at 160 the figure and the varde shrank to a few pixels.
const SURVEY_ZOOM: float = 120.0
## Cells between the player and the varde at the least. The varde's base is about 0.6 units wide,
## so at 1 the stones stand clear of the figure.
const VARDE_GAP: float = 1.0
## Cells from a waypoint at which the walk to the top moves on to the next one. Lowering it walks the
## figure closer through each cell's middle.
const ARRIVE: float = 0.1
## Seconds the walk to the top may take before the survey starts where the player stands. It only
## runs out if something stops the figure, since the walk is a few cells at the walking speed.
const WALK_LIMIT: float = 4.0
## Cells the search for a way to the top looks at before it gives up. The zone holds about 29 cells.
const PATH_LIMIT: int = 400
## Distance bands the survey's cells are split into, each revealed at its own time. Raising it gives
## a smoother ring, and each band costs one mark_cells() call.
const RINGS: int = 48

## Set these before adding the node.
var player: Player
var camera: GameCamera
var terrain: IslandTerrain
var _island: IslandData
## One byte per peak in the island's peaks, 1 once surveyed.
var surveyed := PackedByteArray()
## The index of the peak being surveyed, or -1.
var _peak: int = -1
## Seconds since the survey started.
var _time: float = 0.0
var _varde: Varde
## The WorkerThreadPool task casting the survey, or -1. From the summit it reaches 240 cells and
## takes 170 to 180 ms natively, which would freeze the frame.
var _task: int = -1
## The survey's cells in RINGS bands from the peak outward, written by the task.
var _rings: Array[PackedInt32Array] = []
## How far the zone ring shows, from 0 to 1.
var _marker: float = 0.0
## The index of the peak whose zone ring shows, or -1.
var _marker_peak: int = -1
var _zone_ring := ZoneRing.new()
## The camera zoom when the survey started, which the camera pulls out from and comes back to, so a
## survey in god mode keeps the zoom the player chose.
var _base_zoom: float = GameCamera.ZOOM
## Quarter turns the camera has started in this survey.
var _turns: int = 0
## Bands marked so far. Each is marked when the ring reaches it, because marking all of them in one
## frame took 6 to 11 ms for the 60,000 to 126,000 cells of a survey.
var _marked: int = 0
var _prompt := Prompt.new("SURVEY_PEAK")
## The cells the figure walks through to the top before the look starts, and the index of the next.
var _path := PackedInt32Array()
var _step: int = 0
## Seconds spent walking to the top.
var _walk_time: float = 0.0


func _ready() -> void:
	add_child(_zone_ring)
	add_child(_prompt)


## Starts a new island with no peak surveyed.
func start(island: IslandData) -> void:
	_finish_task()
	_island = island
	surveyed.resize(island.peaks.size())
	surveyed.fill(0)
	_peak = -1
	player.frozen = false
	_marker = 0.0
	_marker_peak = -1
	_zone_ring.fade(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _island == null or _peak >= 0 or not event.is_action_pressed("survey"):
		return
	var peak: int = peak_in_reach(_island, player.grid_position, surveyed)
	if peak < 0:
		return
	get_viewport().set_input_as_handled()
	_peak = peak
	surveyed[peak] = 1
	_time = 0.0
	_marked = 0
	# The step's zoom, not the camera's, in case a step is still easing toward it.
	_base_zoom = GameCamera.STEPS[camera.step] if not player.god else camera.zoom
	_turns = 0
	player.frozen = true
	var cell: int = _island.peaks[peak].cell
	var island: IslandData = _island
	_task = WorkerThreadPool.add_task(func() -> void: _rings = rings(island, cell))
	_varde = Varde.new(cell)
	var top: Vector2 = _center(cell)
	# The figure walks up beside the top first, so the survey happens on the summit and the varde
	# stands on the top cell itself.
	_path = path_to_top(island, IslandData.index(int(player.grid_position.x), int(player.grid_position.y)), cell)
	_step = 0
	_walk_time = 0.0
	var stand: Vector2 = player.grid_position if _path.is_empty() else _center(_path[-1])
	# When the only open cell is the top itself, the stones would go up around the figure's feet, so
	# the varde goes up VARDE_GAP away instead, to the north if the figure stands right on the center.
	var away: Vector2 = top - stand
	if away.length() < VARDE_GAP:
		top = stand + (away.normalized() if away != Vector2.ZERO else Vector2.UP) * VARDE_GAP
	_varde.position = Vector3(top.x, Player.height_at(_island, top), top.y)
	terrain.get_parent().add_child(_varde)


func _process(delta: float) -> void:
	if _island == null:
		return
	var wanted: bool = _peak < 0 and peak_in_reach(_island, player.grid_position, surveyed) >= 0
	_prompt.fade(wanted, delta)
	_update_marker(delta)
	if _peak < 0:
		return
	if _walking(delta):
		return
	_time += delta
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish_task()
	# The cast takes up to 180 ms, so the first frames after it catch up on the bands it held back.
	while _task < 0 and _marked < RINGS and _time >= RING_SECONDS * _marked / RINGS:
		terrain.knowledge.mark_cells(_rings[_marked], Knowledge.Level.SURVEYED)
		_marked += 1
	if _time < LOOK_SECONDS:
		camera.zoom = lerpf(_base_zoom, SURVEY_ZOOM, smoothstep(0.0, ZOOM_SECONDS, _time))
		# Away from the camera, over the side it shows, turning as the camera turns. A smooth turn of
		# the figure clockwise with the camera only swung it within a quarter of facing the camera.
		player.face(Player.walk_direction(Vector2.UP, camera.heading))
		# Each turn starts so that it ends on its quarter of the look, and the last one as the look ends.
		while _turns < LOOK_TURNS and _time >= LOOK_SECONDS * (_turns + 1) / LOOK_TURNS - GameCamera.TURN_SECONDS:
			camera.turn(-1)
			_turns += 1
		return
	var build: float = (_time - LOOK_SECONDS) / BUILD_SECONDS
	camera.zoom = lerpf(SURVEY_ZOOM, _base_zoom, smoothstep(0.0, 1.0, build))
	var top := Vector2(_varde.position.x, _varde.position.z)
	if top != player.grid_position:
		player.face(top - player.grid_position)
	_varde.build(build)
	if build >= 1.0 and _marked == RINGS:
		_peak = -1
		player.frozen = false


# Steers the figure along _path. Returns true while it is still on its way.
func _walking(delta: float) -> bool:
	_walk_time += delta
	while _step < _path.size() and _center(_path[_step]).distance_to(player.grid_position) < ARRIVE:
		_step += 1
	if _step >= _path.size() or _walk_time > WALK_LIMIT:
		player.steer = Vector2.ZERO
		return false
	var gap: Vector2 = _center(_path[_step]) - player.grid_position
	# Full speed through the cells on the way, slowing into the last one so it stops on its middle.
	player.steer = gap.limit_length(1.0) if _step == _path.size() - 1 else gap.normalized()
	return true


## The cells the player walks through from cell from to stand beside the peak's top at cell top,
## starting with from and ending on a cell next to the top. It ends on the top itself if no cell
## beside it can be reached, and it is empty if the top can't be reached either.
static func path_to_top(island: IslandData, from: int, top: int) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var came := {from: from}
	var queue := PackedInt32Array([from])
	var head: int = 0
	var fallback: int = -1
	while head < queue.size() and queue.size() < PATH_LIMIT:
		var cell: int = queue[head]
		head += 1
		if cell == top:
			fallback = cell
		elif absi(cell % size - top % size) <= 1 and absi(cell / size - top / size) <= 1:
			return _trace(came, cell)
		for to: int in Walkability.steps(island, cell):
			if not came.has(to):
				came[to] = cell
				queue.append(to)
	return _trace(came, fallback) if fallback >= 0 else PackedInt32Array()


# The cells from the search's first cell to cell, following came back.
static func _trace(came: Dictionary, cell: int) -> PackedInt32Array:
	var path := PackedInt32Array([cell])
	while came[cell] != cell:
		cell = came[cell]
		path.append(cell)
	path.reverse()
	return path


static func _center(cell: int) -> Vector2:
	return Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)


## The cells of the peaks the player has surveyed, each of which has one of the player's vardes. The
## peak under survey is left out until its varde stands.
func varde_cells() -> PackedInt32Array:
	var cells := PackedInt32Array()
	if _island != null:
		for i: int in surveyed.size():
			if surveyed[i] != 0 and i != _peak:
				cells.append(_island.peaks[i].cell)
	return cells


# Dithers in the zone ring of the nearest unsurveyed peak within MARKER_REACH, and out once the player
# leaves or surveys it. Another peak's ring shows only after the old one has gone.
func _update_marker(delta: float) -> void:
	var near: int = -1 if _peak >= 0 else peak_in_reach(_island, player.grid_position, surveyed, MARKER_REACH)
	if _marker <= 0.0 and near != _marker_peak:
		_marker_peak = near
		if near >= 0:
			_zone_ring.place(_island, _island.peaks[near].cell, ZONE_RADIUS)
	_marker = move_toward(_marker, 1.0 if near >= 0 and near == _marker_peak else 0.0, delta / MARKER_FADE_SECONDS)
	_zone_ring.fade(_marker)


func _finish_task() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _exit_tree() -> void:
	# The task writes to this node, so it must end before the node is freed.
	_finish_task()


## The index in island.peaks of the peak not yet surveyed whose top lies within reach cells of point,
## the nearest if several do, or -1. surveyed holds a byte per peak, 1 once surveyed.
static func peak_in_reach(island: IslandData, point: Vector2, surveyed: PackedByteArray, reach: float = ZONE_RADIUS) -> int:
	var nearest: int = -1
	var best: float = reach
	for i: int in island.peaks.size():
		if surveyed[i] != 0:
			continue
		var cell: int = island.peaks[i].cell
		var distance: float = point.distance_to(Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5))
		if distance <= best:
			best = distance
			nearest = i
	return nearest


## The cells a survey from cell reaches, split into RINGS bands by distance, nearest first. It only
## reads island, so it can run on a worker thread.
static func rings(island: IslandData, cell: int) -> Array[PackedInt32Array]:
	var cells: PackedInt32Array = LineOfSight.visible_cells(island, cell, REACH_SCALE)
	var reach: float = LineOfSight.radius(maxf(island.height[cell], 0.0)) * REACH_SCALE
	# Plain arrays while filling, because appending to a packed array inside an Array appends to a copy.
	var bands: Array[Array] = []
	for i: int in RINGS:
		bands.append([])
	var x: int = cell % IslandData.SIZE
	var y: int = cell / IslandData.SIZE
	for index: int in cells:
		var distance: float = Vector2(index % IslandData.SIZE - x, index / IslandData.SIZE - y).length()
		bands[mini(int(distance / reach * RINGS), RINGS - 1)].append(index)
	var result: Array[PackedInt32Array] = []
	for band: Array in bands:
		result.append(PackedInt32Array(band))
	return result
