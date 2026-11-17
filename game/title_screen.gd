extends Control
## The title screen, and the game's main scene. "Ny øy" starts a run on the seed in the seed field,
## or on a random seed when the field is empty.

const GAME: PackedScene = preload("res://game/game.tscn")

var _seed_field := LineEdit.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	var title := Label.new()
	title.text = tr("GAME_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	column.add_child(title)

	_seed_field.placeholder_text = tr("SEED_OPTIONAL")
	_seed_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_field.custom_minimum_size.x = 200
	_seed_field.text_submitted.connect(_start.unbind(1))
	column.add_child(_seed_field)

	var new_island := Button.new()
	new_island.text = tr("NEW_ISLAND")
	new_island.pressed.connect(_start)
	column.add_child(new_island)
	new_island.grab_focus()


func _start() -> void:
	var game: Game = GAME.instantiate()
	game.island_seed = IslandLoader.seed_from(_seed_field.text)
	# Takes the title screen out of the tree at once, so a second press in the same frame can't start a
	# second run.
	get_tree().change_scene_to_node(game)
