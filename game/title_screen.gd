extends Control
## The title screen, and the game's main scene. The backdrop island circles behind the menu. "Ny øy"
## generates an island from the seed in the seed field, or from a random seed when the field is empty,
## with the backdrop dimmed behind the loading bar, and then starts the run.

const GAME: PackedScene = preload("res://game/game.tscn")
## Seconds the backdrop takes to fade in, and to dim when a run starts.
const FADE_SECONDS: float = 1.0
## How much the sea color hides the backdrop while the run's island generates. Raising it dims more.
const LOADING_DIM: float = 0.6
## Pixels of dark outline around the title's letters, so it reads over bright ground.
const TITLE_OUTLINE: int = 8
## Pixels of dark outline around the button.
const BUTTON_OUTLINE: int = 2
## Pixels of lip under the button's face. Raising it makes the button stand taller.
const BUTTON_LIP: int = 6

var _backdrop := Backdrop.new()
## The sea color over the backdrop. Opaque until the backdrop shows.
var _veil := ColorRect.new()
var _menu := CenterContainer.new()
var _seed_field := LineEdit.new()
var _loader := IslandLoader.new()
var _fade: Tween


func _ready() -> void:
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.shown.connect(_on_backdrop_shown)
	add_child(_backdrop)
	_veil.color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_menu.add_child(column)

	var title := Label.new()
	title.text = tr("GAME_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	title.add_theme_color_override("font_outline_color", Ramps.RAMPS[Ramps.Terrain.WATER][0])
	title.add_theme_constant_override("outline_size", TITLE_OUTLINE)
	column.add_child(title)

	var new_island := Button.new()
	new_island.text = tr("NEW_ISLAND")
	new_island.custom_minimum_size.x = 200
	new_island.add_theme_font_size_override("font_size", 24)
	new_island.pressed.connect(_start)
	column.add_child(_raised(new_island))

	# Small and below the button, since most runs start on a random seed.
	_seed_field.placeholder_text = tr("SEED_OPTIONAL")
	_seed_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_field.custom_minimum_size.x = 120
	_seed_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_seed_field.add_theme_font_size_override("font_size", 12)
	_seed_field.text_submitted.connect(_start.unbind(1))
	column.add_child(_seed_field)
	new_island.grab_focus()

	# Clear, so the veil does the dimming and can fade.
	_loader.cover_alpha = 0.0
	_loader.loaded.connect(_on_loaded)
	add_child(_loader)


# A raised key, a light face over a darker lip, so it reads as the one thing to press. Pressing moves
# the face down onto the lip. The dark outline around it keeps it clear over any ground.
static func _raised(button: Button) -> PanelContainer:
	var snow: PackedColorArray = Ramps.RAMPS[Ramps.Terrain.SNOW]
	var sea: Color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	# Face color, lip color, and the lip's pixels above and below the face.
	var states: Dictionary[String, Array] = {
		"normal": [snow[2], snow[0], 0, BUTTON_LIP],
		"hover": [snow[3], snow[0], 0, BUTTON_LIP],
		"pressed": [snow[2], sea, BUTTON_LIP - 1, 1],
	}
	for state: String in states:
		var look: Array = states[state]
		var box := StyleBoxFlat.new()
		box.bg_color = look[0]
		box.border_color = look[1]
		box.border_width_top = look[2]
		box.border_width_bottom = look[3]
		box.set_corner_radius_all(2)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 6 + look[2]
		box.content_margin_bottom = 6 + look[3]
		button.add_theme_stylebox_override(state, box)
	# A ring outside the outline, so keyboard focus still shows.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = snow[3]
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(5)
	focus.set_expand_margin_all(BUTTON_OUTLINE + 2)
	button.add_theme_stylebox_override("focus", focus)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color, sea)
	var outline := PanelContainer.new()
	var dark := StyleBoxFlat.new()
	dark.bg_color = sea
	dark.set_corner_radius_all(2 + BUTTON_OUTLINE)
	dark.set_content_margin_all(BUTTON_OUTLINE)
	outline.add_theme_stylebox_override("panel", dark)
	outline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outline.add_child(button)
	return outline


func _start() -> void:
	# Hidden at once, so a second press can't start a second island.
	_menu.hide()
	_fade_veil(LOADING_DIM)
	_loader.start(IslandLoader.seed_from(_seed_field.text))


# On first launch the player may start a run before the backdrop shows, and then it stays dimmed.
func _on_backdrop_shown() -> void:
	if _menu.visible:
		_fade_veil(0.0)


func _fade_veil(alpha: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", alpha, FADE_SECONDS)


func _on_loaded(island: IslandData, meshes: Array[ArrayMesh], _msec: int) -> void:
	var game: Game = GAME.instantiate()
	game.island = island
	game.meshes = meshes
	get_tree().change_scene_to_node(game)
