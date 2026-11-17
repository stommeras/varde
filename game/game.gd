class_name Game
extends Node3D
## One run on one island. The island generates on a background thread behind "Kartlegger øya" and
## then shows through the game camera at the view values in SPEC.md. Once the island shows, Escape
## ends the run and goes back to the title screen.

const TITLE_SCREEN: String = "res://game/title_screen.tscn"

## The title screen sets it before it adds the scene. Running the scene on its own gives seed 0.
var island_seed: int = 0
var _terrain := IslandTerrain.new()
var _camera := GameCamera.new()
var _loader := IslandLoader.new()
## False while the island generates. Leaving then would join the generator thread on the main thread
## and freeze the window for the rest of the load, about 3 s.
var _loaded: bool = false


func _ready() -> void:
	# The sea beyond the grid's edge, set here too so the scene also runs on its own.
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	add_child(_terrain)
	add_child(_camera)
	add_child(Sun.new())
	# The middle of the island until the camera follows the player in #45.
	_camera.place()
	_loader.loaded.connect(_on_loaded)
	add_child(_loader)
	_loader.start(island_seed)


func _unhandled_input(event: InputEvent) -> void:
	if _loaded and event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(TITLE_SCREEN)


func _on_loaded(island: IslandData, meshes: Array[ArrayMesh], _msec: int) -> void:
	_terrain.show_island(meshes, island)
	_loaded = true
