class_name Game
extends Node3D
## One run on one island. The island generates on a background thread behind "Kartlegger øya" and
## then shows through the game camera at the view values in SPEC.md. Once the island shows, Escape
## pauses the run behind the pause menu.

const TITLE_SCREEN: String = "res://game/title_screen.tscn"

## The title screen sets it before it adds the scene. Running the scene on its own gives seed 0.
var island_seed: int = 0
var _terrain := IslandTerrain.new()
var _camera := GameCamera.new()
var _loader := IslandLoader.new()
var _menu := PauseMenu.new()
var _player := Player.new()
## False while the island generates. Leaving then would join the generator thread on the main thread
## and freeze the window for the rest of the load, about 3 s, so the menu waits for the island.
var _loaded: bool = false


func _ready() -> void:
	# The sea beyond the grid's edge, set here too so the scene also runs on its own.
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	add_child(_terrain)
	add_child(_camera)
	add_child(Sun.new())
	# The middle of the island while it generates. The player moves the camera once it stands on it.
	_camera.place()
	_player.camera = _camera
	add_child(_player)
	_loader.loaded.connect(_on_loaded)
	add_child(_loader)
	add_child(_menu)
	_loader.start(island_seed)


func _unhandled_input(event: InputEvent) -> void:
	if _loaded and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_menu.open()


func _on_loaded(island: IslandData, meshes: Array[ArrayMesh], _msec: int) -> void:
	_terrain.show_island(meshes, island)
	_player.place(island, island.start)
	_loaded = true
