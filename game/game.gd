class_name Game
extends Node3D
## One run on one island. The title screen generates the island and hands it over. Run on its own, the
## scene generates it on a background thread behind "Kartlegger øya". The island then shows through the game camera at the view values in SPEC.md. Once the island shows, Escape
## pauses the run behind the pause menu, Q and E turn the camera, F surveys a peak the player stands
## on, and M opens the map.
## G toggles god mode in debug builds.

const TITLE_SCREEN: String = "res://game/title_screen.tscn"

## The island and its terrain chunk meshes. The title screen sets them before it adds the scene.
## Running the scene on its own leaves them empty and generates seed 0.
var island: IslandData
var meshes: Array[ArrayMesh]
var _terrain := IslandTerrain.new()
var _camera := GameCamera.new()
var _menu := PauseMenu.new()
var _player := Player.new()
var _survey := Survey.new()
var _map := MapScreen.new()
var _god := GodMode.new()
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
	_player.terrain = _terrain
	add_child(_player)
	_survey.player = _player
	_survey.camera = _camera
	_survey.terrain = _terrain
	add_child(_survey)
	_god.player = _player
	_god.camera = _camera
	_god.survey = _survey
	_god.terrain = _terrain
	add_child(_god)
	_map.player = _player
	_map.camera = _camera
	_map.survey = _survey
	add_child(_map)
	add_child(_menu)
	if island != null:
		_on_loaded(island, meshes, 0)
		return
	# Made only here, since a node that never joins the tree is never freed.
	var loader := IslandLoader.new()
	loader.loaded.connect(_on_loaded)
	add_child(loader)
	loader.start(0)


func _unhandled_input(event: InputEvent) -> void:
	if not _loaded:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_menu.open()
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		_map.open()
	# A survey turns the camera itself, and holds the player still while it does.
	elif _player.frozen:
		return
	elif event.is_action_pressed("turn_left"):
		_camera.turn(-1)
	elif event.is_action_pressed("turn_right"):
		_camera.turn(1)
	# God mode zooms freely on the wheel, so the steps wait until it is off, and + and - zoom the
	# map while it is open.
	elif not _player.god and not _map.visible:
		_zoom(event)


# Steps the camera's zoom on the mouse wheel or + and -, which zoom the map too while it is open.
func _zoom(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if event.is_action_pressed("zoom_in") or (wheel != null and wheel.pressed and wheel.button_index == MOUSE_BUTTON_WHEEL_UP):
		_camera.step_zoom(-1)
	elif event.is_action_pressed("zoom_out") or (wheel != null and wheel.pressed and wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_camera.step_zoom(1)


func _on_loaded(loaded_island: IslandData, loaded_meshes: Array[ArrayMesh], _msec: int) -> void:
	_terrain.show_island(loaded_meshes, loaded_island)
	_player.place(loaded_island, loaded_island.start)
	_survey.start(loaded_island)
	_god.start(loaded_island)
	_map.start(_terrain)
	_loaded = true
