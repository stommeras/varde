class_name IslandLoader
extends CanvasLayer
## Generates an island and its terrain chunk meshes on a background thread, and covers the screen
## with "Kartlegger øya", a progress bar and the running step's name while it runs. The title screen,
## the game scene and the debug view use it.

## Sent on the main thread when an island is ready. msec is the generator's time, without the mesh.
signal loaded(island: IslandData, meshes: Array[ArrayMesh], msec: int)

## Milliseconds each step took for seed "varde" on a desktop, in the order the steps run, with the
## terrain mesh last. The bar fills by these, and within a step by the time since it started, up to
## its share, so it moves on through the long erosion step. Only the shares matter, so a slower
## machine fills the bar at the same places, just later.
const STEP_MSEC: Dictionary[String, int] = {
	"height": 1130, "erosion": 1560, "crags": 310, "moisture": 330, "material": 180,
	"main_island": 260, "rivers": 430, "peaks": 600, "contenders": 800, "start": 480, "ways_up": 1480, "mesh": 460,
}

## True keeps the cover hidden, for an island the player isn't waiting for.
var quiet: bool = false
## How much the cover hides the scene behind it, from 0 to 1. The text and the bar show either way.
var cover_alpha: float = 1.0
## Null means no generation is running.
var _thread: Thread
var _cover := ColorRect.new()
var _bar := ProgressBar.new()
var _step_label := Label.new()
## Typical milliseconds of the steps that have finished.
var _done_msec: int = 0
## The running step's index in STEP_MSEC.
var _step: int = 0
var _step_started: int = 0


func _ready() -> void:
	# Above the scenes' own UI, which sits on the default layer.
	layer = 10
	_cover.color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.hide()
	add_child(_cover)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	var label := Label.new()
	label.text = tr("CHARTING_ISLAND")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	column.add_child(label)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(240, 4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Ramps.RAMPS[Ramps.Terrain.SNOW][3]
	var track := StyleBoxFlat.new()
	track.bg_color = Ramps.RAMPS[Ramps.Terrain.WATER][2]
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", track)
	column.add_child(_bar)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][1])
	column.add_child(_step_label)


func _process(_delta: float) -> void:
	if _thread == null:
		return
	if not _thread.is_alive():
		_finish()
		return
	var share: int = STEP_MSEC.values()[_step]
	var into_step: int = mini(Time.get_ticks_msec() - _step_started, share)
	_bar.value = float(_done_msec + into_step) / _total_msec()


## Starts the generator on a thread. A request while one is running is dropped.
func start(island_seed: int) -> void:
	if _thread != null:
		return
	_cover.color.a = cover_alpha
	_cover.visible = not quiet
	_done_msec = 0
	_show_step(0)
	_thread = Thread.new()
	# The generator reports from its own thread, and only the main thread may touch the nodes.
	_thread.start(_build.bind(island_seed, func(step: String) -> void: _on_step_done.call_deferred(step)))


## The seed for text typed into a seed field. A whole number is used as it is, so a seed shown on
## screen loads the same island again. Other text is hashed, and empty text gives a random seed.
static func seed_from(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return randi()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	return trimmed.hash()


## Runs on the generator thread. Returns the island, its terrain chunk meshes and their build time.
static func _build(island_seed: int, on_step: Callable) -> Array:
	var island: IslandData = IslandGenerator.generate(island_seed, on_step)
	var started: int = Time.get_ticks_msec()
	var meshes: Array[ArrayMesh] = TerrainMesh.build(island)
	return [island, meshes, Time.get_ticks_msec() - started]


func _finish() -> void:
	var result: Array = _thread.wait_to_finish()
	_thread = null
	var island: IslandData = result[0]
	# The total sums the steps instead of timing from start, because a hidden window runs at
	# about 1 frame per second and the poll in _process would add up to a second.
	var total: int = 0
	var steps := PackedStringArray()
	for step: String in island.step_msec:
		total += island.step_msec[step]
		steps.append("%s %d ms" % [step, island.step_msec[step]])
	print("Seed %d: %s, total %d ms, then the mesh %d ms" % [island.island_seed, ", ".join(steps), total, result[2]])
	var meshes: Array[ArrayMesh] = result[1]
	# Hidden first, so a handler that starts the next island keeps the cover up.
	_cover.hide()
	loaded.emit(island, meshes, total)


func _on_step_done(step: String) -> void:
	_done_msec += STEP_MSEC[step]
	_show_step(STEP_MSEC.keys().find(step) + 1)


func _show_step(index: int) -> void:
	_step = index
	_step_started = Time.get_ticks_msec()
	_bar.value = float(_done_msec) / _total_msec()
	_step_label.text = tr("STEP_" + STEP_MSEC.keys()[index].to_upper())


func _total_msec() -> int:
	var total: int = 0
	for msec: int in STEP_MSEC.values():
		total += msec
	return total


# A thread still running when the node leaves must be joined, or Godot reports a leaked thread.
func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
