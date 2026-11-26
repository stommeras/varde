class_name PauseMenu
extends CanvasLayer
## Pauses the run behind "Fortsett" and "Avslutt". Escape or "Fortsett" resumes it, and "Avslutt" ends
## the run and goes back to the title screen. The game scene opens it, since there is no saving and a
## stray Escape shouldn't throw a run away.

## How much of the run shows through the dimmed background. Raising it dims the run more.
const DIM: float = 0.6

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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size.x = 200
	center.add_child(column)
	_resume.text = tr("RESUME")
	_resume.pressed.connect(close)
	column.add_child(_resume)
	var quit := Button.new()
	quit.text = tr("QUIT_RUN")
	quit.pressed.connect(_quit)
	column.add_child(quit)
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


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Pauses the run and shows the menu.
func open() -> void:
	get_tree().paused = true
	show()
	_resume.grab_focus()


## Hides the menu and resumes the run.
func close() -> void:
	hide()
	get_tree().paused = false


func _quit() -> void:
	# Unpaused first, or the title screen would load paused and ignore its buttons.
	get_tree().paused = false
	get_tree().change_scene_to_file(Game.TITLE_SCREEN)
