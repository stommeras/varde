class_name Backdrop
extends Node3D
## The island behind the title screen, seen through the game camera as it circles the summit. The
## island generates on a background thread the first time, and later title screens reuse it.

## Sent once the island shows, on the main thread.
signal shown

## Text the seed comes from, as if typed into the seed field. Chosen by eye from frames of a few
## candidates.
const SEED_TEXT: String = "varde"
## Cells of ground from the top to the bottom of the screen. Above the game's zoom, so the view takes
## in the summit and the land around it.
const ZOOM: float = 120.0
## Cells from the summit to the circle the camera follows. Raising it shows more coast and less of the
## mountain.
const RADIUS: float = 50.0
## Cells the camera moves per second. Raising it makes the drift livelier, lowering it calmer.
const SPEED: float = 2.0

# ponytail: holds the island and its meshes, about 40 MB, through every run. Rebuild them on return to
# the title screen if memory gets tight, as on the web.
static var _island: IslandData
static var _meshes: Array[ArrayMesh]

var _terrain := IslandTerrain.new()
var _camera := GameCamera.new()
var _loader := IslandLoader.new()
var _summit := Vector3.ZERO
## Radians around the circle, from east of the summit toward the south.
var _angle: float = 0.0


func _ready() -> void:
	add_child(_terrain)
	_camera.zoom = ZOOM
	add_child(_camera)
	add_child(Sun.new())
	if _island != null:
		_show.call_deferred()
		return
	_loader.quiet = true
	_loader.loaded.connect(_on_loaded)
	add_child(_loader)
	_loader.start(IslandLoader.seed_from(SEED_TEXT))


func _process(delta: float) -> void:
	_angle += SPEED / RADIUS * delta
	_camera.focus = _summit + Vector3(cos(_angle), 0.0, sin(_angle)) * RADIUS
	_camera.place()


func _on_loaded(island: IslandData, meshes: Array[ArrayMesh], _msec: int) -> void:
	_island = island
	_meshes = meshes
	_show()


func _show() -> void:
	_terrain.show_island(_meshes, _island)
	# The backdrop shows the whole island, already risen out of the fog.
	_terrain.knowledge.mark_all(Knowledge.Level.SURVEYED, Knowledge.LONG_AGO)
	var highest: int = 0
	for i: int in _island.height.size():
		if _island.height[i] > _island.height[highest]:
			highest = i
	# At sea level below the summit, as in the debug view, so the circle runs at one depth.
	_summit = Vector3(highest % IslandData.SIZE + 0.5, 0.0, highest / IslandData.SIZE + 0.5)
	shown.emit()
