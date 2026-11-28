class_name Game
extends Node3D
## One run on one island. The title screen generates the island and hands it over. Run on its own, the
## scene generates it on a background thread behind "Kartlegger øya". The island then shows through the game camera at the view values in SPEC.md. Once the island shows, Escape
## pauses the run behind the pause menu, Q and E turn the camera, F surveys a peak the player stands
## on or reads the note on the shipwreck or an old varde beside it, and M opens the map.
## G toggles god mode in debug builds.

const TITLE_SCREEN: String = "res://game/title_screen.tscn"
## Seconds after the player first sees a cell at which a thing on it shows. The fog over a cell takes
## the terrain shader's clear_seconds, 1 s, to clear, so at 0.5 it shows as the fog thins.
const SHOW_SECONDS: float = 0.5
## Seconds the game takes to fade out after the final reveal. Raising it makes the last fade calmer.
const FADE_SECONDS: float = 1.5

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
var _reading := Reading.new()
## False while the island generates. Leaving then would join the generator thread on the main thread
## and freeze the window for the rest of the load, about 3 s, so the menu waits for the island.
var _loaded: bool = false
## The wreck and the old vardes that still wait for the fog over them to clear, and their cells.
var _fogged: Array[Node3D] = []
var _fogged_cells := PackedInt32Array()
## The run's stats, recorded when the player ends the run at the summit varde, or null before.
var stats: RunStats
var _fade := ColorRect.new()


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
	_reading.player = _player
	add_child(_reading)
	_god.player = _player
	_god.camera = _camera
	_god.survey = _survey
	_god.terrain = _terrain
	add_child(_god)
	_map.player = _player
	_map.camera = _camera
	_map.survey = _survey
	_map.reading = _reading
	add_child(_map)
	add_child(_menu)
	_survey.summit_reached.connect(_on_summit_reached)
	_survey.ended.connect(_on_ended)
	var fade_layer := CanvasLayer.new()
	# Above the HUD and the map, so the fade covers everything.
	fade_layer.layer = 20
	_fade.color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)
	add_child(fade_layer)
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


func _process(_delta: float) -> void:
	var knowledge: Knowledge = _terrain.knowledge
	for i: int in range(_fogged.size() - 1, -1, -1):
		if knowledge.now >= knowledge.revealed_at(_fogged_cells[i]) + SHOW_SECONDS:
			_fogged[i].show()
			_fogged.remove_at(i)
			_fogged_cells.remove_at(i)
		else:
			# God mode hides the fog, so what stands under it shows too, until god mode ends.
			_fogged[i].visible = _player.god


# Adds thing, standing on cell, hidden until the player has seen cell. Drawn over the fog, it would
# give away land the player hasn't seen.
func _hide_in_fog(thing: Node3D, cell: int) -> void:
	thing.hide()
	_fogged.append(thing)
	_fogged_cells.append(cell)
	add_child(thing)


func _on_loaded(loaded_island: IslandData, loaded_meshes: Array[ArrayMesh], _msec: int) -> void:
	# Kept for the run's stats, since a scene run on its own gets its island from the loader.
	island = loaded_island
	_terrain.show_island(loaded_meshes, loaded_island)
	_player.place(loaded_island, loaded_island.start)
	if loaded_island.wreck >= 0:
		var wreck := Wreck.new()
		# Bow first up the beach, toward the start.
		wreck.place(loaded_island, loaded_island.wreck, loaded_island.start)
		_hide_in_fog(wreck, loaded_island.wreck)
	for i: int in loaded_island.vardes.size():
		var varde := OldVarde.new(loaded_island.varde_kinds[i], loaded_island.island_seed + i)
		varde.place(loaded_island, loaded_island.vardes[i])
		_hide_in_fog(varde, loaded_island.vardes[i])
	var summit := OldVarde.new(Trail.Kind.STANDING, loaded_island.island_seed - 1)
	summit.place(loaded_island, loaded_island.peaks[Survey.SUMMIT].cell)
	summit.scale = Vector3.ONE * OldVarde.SUMMIT_SCALE
	_hide_in_fog(summit, loaded_island.peaks[Survey.SUMMIT].cell)
	_reading.start(loaded_island)
	_menu.show_seed(loaded_island.island_seed)
	_survey.start(loaded_island)
	_god.start(loaded_island)
	_map.start(_terrain)
	_loaded = true


func _on_summit_reached() -> void:
	stats = RunStats.record(island, _terrain.knowledge, _survey.varde_cells().size(), _reading.found_vardes.size())


# Fades to black and leaves the run. The end screen (#123) takes over from the title screen here.
func _on_ended() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(TITLE_SCREEN))
