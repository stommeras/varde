class_name Survey
extends Node
## Surveying from a peak. Inside a peak's survey zone it shows "Kartlegg toppen", and the survey
## action starts the survey: the camera pulls out while the figure turns to look around and the
## surveyed land rises from the fog in a ring that spreads from the peak, then the figure stacks a
## varde on the peak as the camera comes back. Each peak can be surveyed once.

## Cells from a peak's top within which the player can survey it. Raising it lets the player survey
## from further down the slope.
const ZONE_RADIUS: float = 6.0
## How many times the walking view radius a survey reaches.
const REACH_SCALE: float = 2.0
## Seconds the figure takes to turn through all 8 facings, looking out. The ring spreads in the same
## time, so raising it slows the whole reveal.
const LOOK_SECONDS: float = 3.0
## Seconds the ring takes to reach the edge of the survey. Shorter than LOOK_SECONDS, so the farthest
## land has risen before the camera comes back in.
const RING_SECONDS: float = 2.5
## Seconds the stones take to go up, while the camera eases back in.
const BUILD_SECONDS: float = 1.0
## Seconds the camera takes to pull out at the start.
const ZOOM_SECONDS: float = 1.0
## Cells from the top to the bottom of the screen at the furthest pull-out. At 80 it shows twice the
## walking view, about a third of the survey's radius from the summit. At 160 the figure and the
## varde shrank to a few pixels.
const SURVEY_ZOOM: float = 80.0
## Seconds the prompt takes to fade in or out.
const PROMPT_SECONDS: float = 0.2
## Distance bands the survey's cells are split into, each revealed at its own time. Raising it gives
## a smoother ring, and each band costs one mark_cells() call.
const RINGS: int = 48

## Set these before adding the node.
var player: Player
var camera: GameCamera
var terrain: IslandTerrain
var _island: IslandData
## One byte per peak in _island.peaks, 1 once surveyed.
var _surveyed := PackedByteArray()
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
## Bands marked so far. Each is marked when the ring reaches it, because marking all of them in one
## frame took 6 to 11 ms for the 60,000 to 126,000 cells of a survey.
var _marked: int = 0
var _prompt := Label.new()


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_prompt.text = tr("SURVEY_PEAK")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.position.y -= 24
	_prompt.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	_prompt.add_theme_color_override("font_outline_color", Ramps.RAMPS[Ramps.Terrain.ROCK][0])
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.modulate.a = 0.0
	layer.add_child(_prompt)


## Starts a new island with no peak surveyed.
func start(island: IslandData) -> void:
	_finish_task()
	_island = island
	_surveyed.resize(island.peaks.size())
	_surveyed.fill(0)
	_peak = -1


func _unhandled_input(event: InputEvent) -> void:
	if _island == null or _peak >= 0 or not event.is_action_pressed("survey"):
		return
	var peak: int = peak_in_reach(_island, player.grid_position, _surveyed)
	if peak < 0:
		return
	get_viewport().set_input_as_handled()
	_peak = peak
	_surveyed[peak] = 1
	_time = 0.0
	_marked = 0
	player.frozen = true
	var cell: int = _island.peaks[peak].cell
	var island: IslandData = _island
	_task = WorkerThreadPool.add_task(func() -> void: _rings = rings(island, cell))
	_varde = Varde.new(cell)
	var top := Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
	_varde.position = Vector3(top.x, Player.height_at(_island, top), top.y)
	terrain.get_parent().add_child(_varde)


func _process(delta: float) -> void:
	if _island == null:
		return
	var wanted: bool = _peak < 0 and peak_in_reach(_island, player.grid_position, _surveyed) >= 0
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if wanted else 0.0, delta / PROMPT_SECONDS)
	if _peak < 0:
		return
	_time += delta
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish_task()
	# The cast takes up to 180 ms, so the first frames after it catch up on the bands it held back.
	while _task < 0 and _marked < RINGS and _time >= RING_SECONDS * _marked / RINGS:
		terrain.knowledge.mark_cells(_rings[_marked], Knowledge.Level.SURVEYED)
		_marked += 1
	if _time < LOOK_SECONDS:
		camera.zoom = lerpf(GameCamera.ZOOM, SURVEY_ZOOM, smoothstep(0.0, ZOOM_SECONDS, _time))
		# One full turn, clockwise from south, the way the figure faced when it walked up.
		player.face(Vector2.DOWN.rotated(TAU * _time / LOOK_SECONDS))
		return
	var build: float = (_time - LOOK_SECONDS) / BUILD_SECONDS
	camera.zoom = lerpf(SURVEY_ZOOM, GameCamera.ZOOM, smoothstep(0.0, 1.0, build))
	var top := Vector2(_varde.position.x, _varde.position.z)
	if top != player.grid_position:
		player.face(top - player.grid_position)
	_varde.build(build)
	if build >= 1.0 and _marked == RINGS:
		_peak = -1
		player.frozen = false


func _finish_task() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _exit_tree() -> void:
	# The task writes to this node, so it must end before the node is freed.
	_finish_task()


## The index in island.peaks of the peak not yet surveyed whose zone holds point, the nearest if
## several do, or -1. surveyed holds a byte per peak, 1 once surveyed.
static func peak_in_reach(island: IslandData, point: Vector2, surveyed: PackedByteArray) -> int:
	var nearest: int = -1
	var best: float = ZONE_RADIUS
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
