class_name PauseMenu
extends CanvasLayer
## Pauses the run behind "Fortsett" and "Avslutt" in the middle of the screen, with the controls listed
## on both sides of them as drawn keys. Escape or "Fortsett" resumes the run, and "Avslutt" ends it
## and goes back to the title screen. The game scene opens it, since there is no saving and a stray
## Escape shouldn't throw a run away.

## How much of the run shows through the dimmed background. Raising it dims the run more.
const DIM: float = 0.6
## The first LEFT_HAND rows of CONTROLS go left of the buttons and the rest go right, so the keys for
## the left hand sit on the left as on a keyboard.
const LEFT_HAND: int = 2
## Pixels between the buttons and the controls on each side. Raising it spreads the menu wider.
const SIDE_GAP: int = 32
## Pixels between neighbouring keys, as on a keyboard. Raising it spreads the keys apart.
const KEY_GAP: int = 2

## The controls list, one row per thing to do: the translation key of what it does, the actions it
## covers, and its keys. The keys come in groups with "eller" between them, and each group lists its
## keys row by row as they sit on a keyboard, so WASD and the arrows keep their shape. A row with
## "wheel" shows the mouse wheel before its keys.
const CONTROLS: Array[Dictionary] = [
	{
		"text": "CONTROL_WALK",
		"actions": [&"move_up", &"move_left", &"move_down", &"move_right"],
		"keys": [[[KEY_W], [KEY_A, KEY_S, KEY_D]], [[KEY_UP], [KEY_LEFT, KEY_DOWN, KEY_RIGHT]]],
	},
	{"text": "CONTROL_TURN", "actions": [&"turn_left", &"turn_right"], "keys": [[[KEY_Q, KEY_E]]]},
	{"text": "CONTROL_SURVEY", "actions": [&"survey"], "keys": [[[KEY_F]]]},
	{"text": "CONTROL_MAP", "actions": [&"map"], "keys": [[[KEY_M]]]},
	{"text": "CONTROL_ZOOM", "actions": [&"zoom_in", &"zoom_out"], "keys": [[[KEY_PLUS, KEY_MINUS]]], "wheel": true},
	{"text": "CONTROL_PAUSE", "actions": [&"ui_cancel"], "keys": [[[KEY_ESCAPE]]]},
]

var _resume := Button.new()
## VersionLabel hides itself without a version, so the seed shows it again once it has text.
var _seed := VersionLabel.new()


func _ready() -> void:
	# Runs while the tree is paused, so its buttons and Escape still work.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	hide()
	var dim := ColorRect.new()
	dim.color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	dim.color.a = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	# The two sides expand by the same amount whatever their width, which keeps the buttons centered.
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", SIDE_GAP)
	sides.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sides)
	sides.add_child(_controls(CONTROLS.slice(0, LEFT_HAND), true))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size.x = 200
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sides.add_child(column)
	_resume.text = tr("RESUME")
	_resume.pressed.connect(close)
	column.add_child(_resume)
	var quit := Button.new()
	quit.text = tr("QUIT_RUN")
	quit.pressed.connect(_quit)
	column.add_child(quit)
	sides.add_child(_controls(CONTROLS.slice(LEFT_HAND), false))
	add_child(VersionLabel.new())
	# Styled like the version, in the other corner, so a bug report can name the island too.
	_seed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, VersionLabel.MARGIN)
	_seed.grow_horizontal = Control.GROW_DIRECTION_END
	_seed.hide()
	add_child(_seed)


## Shows island_seed in the bottom-left corner, as the number the seed field takes to load the island again.
func show_seed(island_seed: int) -> void:
	_seed.text = tr("PAUSE_SEED") % island_seed
	_seed.show()


func _controls(rows: Array[Dictionary], mirrored: bool) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	var toward_buttons := Control.SIZE_SHRINK_END if mirrored else Control.SIZE_SHRINK_BEGIN
	grid.size_flags_horizontal = Control.SIZE_EXPAND | toward_buttons
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for row: Dictionary in rows:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 8)
		# The wheel isn't an input action, since game.gd reads it straight from the mouse events.
		if row.get("wheel", false):
			keys.add_child(MouseWheel.new())
			keys.add_child(_label("CONTROL_OR"))
		var groups: Array = row["keys"]
		for i: int in groups.size():
			if i > 0:
				keys.add_child(_label("CONTROL_OR"))
			keys.add_child(_key_group(groups[i]))
		var text := _label(row["text"])
		if mirrored:
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(text)
			grid.add_child(keys)
		else:
			grid.add_child(keys)
			grid.add_child(text)
	return grid


func _key_group(rows: Array) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", KEY_GAP)
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for keys: Array in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", KEY_GAP)
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for key: Key in keys:
			line.add_child(KeyCap.new(key))
		group.add_child(line)
	return group


func _label(text_key: String) -> Label:
	var label := Label.new()
	label.text = tr(text_key)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	return label


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Pauses the run and shows the menu.
func open() -> void:
	get_tree().paused = true
	show()
	# Hidden until the player tabs or uses the arrow keys, as on the title screen.
	_resume.grab_focus(true)


## Hides the menu and resumes the run.
func close() -> void:
	hide()
	get_tree().paused = false


func _quit() -> void:
	# Unpaused first, or the title screen would load paused and ignore its buttons.
	get_tree().paused = false
	get_tree().change_scene_to_file(Game.TITLE_SCREEN)
