extends Control
## The title screen, and the game's main scene. The backdrop island pans behind the menu. "Ny øy"
## generates an island from the seed in the seed field, or from a random seed when the field is empty,
## with the backdrop dimmed behind the loading bar, and then starts the run.

const GAME: PackedScene = preload("res://game/game.tscn")
## Seconds the backdrop takes to dim when a run starts.
const FADE_SECONDS: float = 1.0
## How much the sea color hides the backdrop while the run's island generates. Raising it dims more.
const LOADING_DIM: float = 0.6
## Pixels of dark outline around the title's letters, so it reads over bright ground.
const TITLE_OUTLINE: int = 8
## Pixels the button sits below its hover height when the mouse is elsewhere, so hovering lifts it.
const KEY_REST_SINK: int = 2

var _backdrop := Backdrop.new()
## The sea color over the backdrop, clear until a run starts.
var _veil := ColorRect.new()
var _menu := CenterContainer.new()
var _new_island := Button.new()
var _seed_field := LineEdit.new()
var _loader := IslandLoader.new()
var _fade: Tween


func _ready() -> void:
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_veil.color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	_veil.color.a = 0.0
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

	var new_island := _new_island
	new_island.text = tr("NEW_ISLAND")
	new_island.custom_minimum_size.x = 200
	new_island.add_theme_font_size_override("font_size", 24)
	new_island.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_key(new_island)
	new_island.pressed.connect(_start)
	column.add_child(new_island)

	# Small and below the button, since most runs start on a random seed.
	_seed_field.placeholder_text = tr("SEED_OPTIONAL")
	_seed_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_field.custom_minimum_size.x = 120
	_seed_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_seed_field.add_theme_font_size_override("font_size", 12)
	_seed_field.text_submitted.connect(_start.unbind(1))
	column.add_child(_seed_field)
	# Hidden until the player tabs or uses the arrow keys, like focus-visible on the web.
	new_island.grab_focus(true)

	add_child(VersionLabel.new())

	# Clear, so the veil does the dimming and can fade.
	_loader.cover_alpha = 0.0
	_loader.loaded.connect(_on_loaded)
	add_child(_loader)


# A raised key, so it reads as the one thing to press. Hover lifts it, pressing sinks it.
static func _style_key(button: Button) -> void:
	var sea: Color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	button.add_theme_stylebox_override("normal", KeyStyle.new(KEY_REST_SINK, 3))
	button.add_theme_stylebox_override("hover", KeyStyle.new(0, 3))
	button.add_theme_stylebox_override("pressed", KeyStyle.new(KeyStyle.LIP - 1, 2))
	button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
	# A ring outside the outline, shown only after keyboard navigation.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Ramps.RAMPS[Ramps.Terrain.SNOW][3]
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(5)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color, sea)


# A click outside the seed field ends editing, and Enter starts the run again.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and _seed_field.has_focus():
		_new_island.grab_focus(true)


func _start() -> void:
	# Hidden at once, so a second press can't start a second island.
	_menu.hide()
	_fade_veil(LOADING_DIM)
	_loader.start(IslandLoader.seed_from(_seed_field.text))


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


## A key drawn as a dark outline around a light face standing on a darker lip. sink moves the whole
## key down and shortens the lip by as much, so the key keeps its height and seems to go down.
class KeyStyle:
	extends StyleBox

	## Pixels of lip under the face at hover height. Raising it makes the key stand taller.
	const LIP: int = 6
	## Pixels of dark outline, so the key stays clear over any ground.
	const OUTLINE: int = 2
	## Pixels between the face's edge and the text.
	const PADDING := Vector2(16, 6)

	var _sink: int
	var _outline := StyleBoxFlat.new()
	var _lip := StyleBoxFlat.new()
	var _face := StyleBoxFlat.new()

	## sink is pixels below hover height, from 0 to LIP - 1. face is a step on the snow ramp.
	func _init(sink: int, face: int) -> void:
		_sink = sink
		var snow: PackedColorArray = Ramps.RAMPS[Ramps.Terrain.SNOW]
		_outline.bg_color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
		_outline.set_corner_radius_all(2 + OUTLINE)
		_lip.bg_color = snow[0]
		_face.bg_color = snow[face]
		for box: StyleBoxFlat in [_lip, _face]:
			box.set_corner_radius_all(2)
		content_margin_left = OUTLINE + PADDING.x
		content_margin_right = OUTLINE + PADDING.x
		content_margin_top = OUTLINE + PADDING.y + sink
		content_margin_bottom = OUTLINE + PADDING.y + LIP - sink

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var key := Rect2(rect.position + Vector2(0, _sink), rect.size - Vector2(0, _sink))
		_outline.draw(to_canvas_item, key)
		var inside: Rect2 = key.grow(-OUTLINE)
		_lip.draw(to_canvas_item, inside)
		inside.size.y -= LIP - _sink
		_face.draw(to_canvas_item, inside)
