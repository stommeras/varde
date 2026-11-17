class_name IslandLoader
extends CanvasLayer
## Generates an island and its terrain chunk meshes on a background thread, and covers the screen
## with "Kartlegger øya" while it runs. The game scene and the debug view both use it.

## Sent on the main thread when an island is ready. msec is the generator's time, without the mesh.
signal loaded(island: IslandData, meshes: Array[ArrayMesh], msec: int)

## Null means no generation is running.
var _thread: Thread
var _cover := ColorRect.new()


func _ready() -> void:
	# Above the scenes' own UI, which sits on the default layer.
	layer = 10
	_cover.color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.hide()
	add_child(_cover)
	var label := Label.new()
	label.text = tr("CHARTING_ISLAND")
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	_cover.add_child(label)


func _process(_delta: float) -> void:
	if _thread != null and not _thread.is_alive():
		_finish()


## Starts the generator on a thread. A request while one is running is dropped.
func start(island_seed: int) -> void:
	if _thread != null:
		return
	_cover.show()
	_thread = Thread.new()
	_thread.start(_build.bind(island_seed))


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
static func _build(island_seed: int) -> Array:
	var island: IslandData = IslandGenerator.generate(island_seed)
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


# A thread still running when the node leaves must be joined, or Godot reports a leaked thread.
func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
