class_name Survey
extends Node
## Surveying from a peak. Inside a peak's survey zone it shows "Kartlegg toppen", and the survey
## action starts the survey: the camera pulls out while the figure turns to look around and the
## fog clears from the surveyed land in a ring that spreads from the peak, then the figure stacks a
## varde on the peak as the camera comes back. Each peak can be surveyed once.

## Cells from a peak's top within which the player can survey it. Raising it lets the player survey
## from further down the slope. At 6 the prompt came up well below the top of a steep peak, so the
## survey didn't feel like it happened on the top.
const ZONE_RADIUS: float = 3.0
## Cells from a peak's top within which a ring floats over the edge of its zone, so the player can
## find the top. Raising it shows the ring from further down.
const MARKER_REACH: float = 6.0
## Seconds the zone ring takes to dither in or out.
const MARKER_FADE_SECONDS: float = 0.5
## How many times the walking view radius a survey reaches.
const REACH_SCALE: float = 2.0
## Seconds the figure takes to turn once around, looking out. Raising it slows the whole reveal. At
## 3 s the turn looked hurried, and at 5 s it rests about 0.6 s on each of the 8 directions.
const LOOK_SECONDS: float = 5.0
## Seconds the ring of clearing fog takes to reach the edge of the survey. Shorter than LOOK_SECONDS,
## so the fog has cleared from the farthest land before the camera comes back in.
const RING_SECONDS: float = 4.5
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
## In god mode, every peak not yet surveyed shows its zone ring, however far away it is.
var show_all: bool = false
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
## A ring per peak for show_all, made the first time show_all is on for this island.
var _all_rings: Array[ZoneRing] = []
## The camera zoom when the survey started, which the camera pulls out from and comes back to, so a
## survey in god mode keeps the zoom the player chose.
var _base_zoom: float = GameCamera.ZOOM
## Bands marked so far. Each is marked when the ring reaches it, because marking all of them in one
## frame took 6 to 11 ms for the 60,000 to 126,000 cells of a survey.
var _marked: int = 0
var _prompt := Label.new()


func _ready() -> void:
	add_child(_zone_ring)
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
	surveyed.resize(island.peaks.size())
	surveyed.fill(0)
	_peak = -1
	player.frozen = false
	_marker = 0.0
	_marker_peak = -1
	_zone_ring.fade(0.0)
	for ring: ZoneRing in _all_rings:
		ring.queue_free()
	_all_rings.clear()


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
	_base_zoom = camera.zoom
	player.frozen = true
	var cell: int = _island.peaks[peak].cell
	var island: IslandData = _island
	_task = WorkerThreadPool.add_task(func() -> void: _rings = rings(island, cell))
	_varde = Varde.new(cell)
	var top := Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
	# A player standing on the top would have the stones built around their feet, so the varde
	# goes up VARDE_GAP in front of them instead, to the north if they stand right on the center.
	var away: Vector2 = top - player.grid_position
	if away.length() < VARDE_GAP:
		top = player.grid_position + (away.normalized() if away != Vector2.ZERO else Vector2.UP) * VARDE_GAP
	_varde.position = Vector3(top.x, Player.height_at(_island, top), top.y)
	terrain.get_parent().add_child(_varde)


func _process(delta: float) -> void:
	if _island == null:
		return
	var wanted: bool = _peak < 0 and peak_in_reach(_island, player.grid_position, surveyed) >= 0
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if wanted else 0.0, delta / PROMPT_SECONDS)
	_update_marker(delta)
	_update_all_rings()
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
		camera.zoom = lerpf(_base_zoom, SURVEY_ZOOM, smoothstep(0.0, ZOOM_SECONDS, _time))
		# One full turn, clockwise from south, the way the figure faced when it walked up.
		player.face(Vector2.DOWN.rotated(TAU * _time / LOOK_SECONDS))
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


func _update_all_rings() -> void:
	if show_all and _all_rings.is_empty():
		for peak: Peak in _island.peaks:
			var ring := ZoneRing.new()
			add_child(ring)
			ring.place(_island, peak.cell, ZONE_RADIUS)
			_all_rings.append(ring)
	# Scaled with the zoom, so a ring keeps its size on screen and still shows on a peak when the
	# camera zooms far out.
	var size := Vector3.ONE * maxf(camera.zoom / GameCamera.ZOOM, 1.0)
	for i: int in _all_rings.size():
		_all_rings[i].scale = size
		_all_rings[i].fade(1.0 if show_all and surveyed[i] == 0 else 0.0)


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
