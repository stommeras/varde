class_name Reading
extends CanvasLayer
## Reading the notes the island holds. Within Landing.READ_REACH of the shipwreck it shows "[F] Les",
## and F opens the wreck's note in a panel of map paper over the game. The world keeps running.
## F or Escape closes it, and so does walking CLOSE_MARGIN past the reach, so the note doesn't follow
## the player. A note that opened by itself would stop the player each time they walked
## past. The note points toward the first old varde. A later issue writes the notes from the
## island's features, and until then the text is a placeholder that names a compass direction.

## Width of the note panel in base-resolution pixels. Raising it gives longer lines and a lower panel.
const WIDTH: int = 360
## Pixels between the panel's edge and its text.
const PADDING: int = 16
## Pixels from the top of the screen to the panel. It sits high, so it leaves the figure in the
## middle of the screen in view while the player walks with the note open.
const TOP: int = 32
## Cells past Landing.READ_REACH the player walks before an open note closes. The start lies about
## 3.2 cells from the wreck, so at 0 the first step away closed the note in under a quarter of a
## second. Raising it lets the player walk further while reading.
const CLOSE_MARGIN: float = 3.0

## Set it before adding the node.
var player: Player
var _island: IslandData
var _prompt := Prompt.new("READ")
var _panel := PanelContainer.new()
var _text := Label.new()


func _ready() -> void:
	# Above the prompts, below the pause menu.
	layer = 2
	add_child(_prompt)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Ramps.MAP[Ramps.MapPart.PAPER][2]
	paper.border_color = Ramps.MAP[Ramps.MapPart.INK][1]
	paper.set_border_width_all(2)
	paper.set_content_margin_all(PADDING)
	_panel.add_theme_stylebox_override("panel", paper)
	_panel.custom_minimum_size.x = WIDTH
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", Ramps.MAP[Ramps.MapPart.INK][0])
	_panel.add_child(_text)
	_panel.hide()
	add_child(_panel)


## Starts a new island with the note closed.
func start(island: IslandData) -> void:
	_island = island
	_panel.hide()
	if island.wreck >= 0 and not island.vardes.is_empty():
		_text.text = tr("NOTE_WRECK") % tr("COMPASS_%d" % compass(island.wreck, island.vardes[0]))


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and (event.is_action_pressed("survey") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_panel.hide()
	# F reads as it surveys, since a wreck never lies in a peak's zone.
	elif _in_reach() and event.is_action_pressed("survey"):
		get_viewport().set_input_as_handled()
		_panel.show()


func _process(delta: float) -> void:
	if _panel.visible and not _in_reach(Landing.READ_REACH + CLOSE_MARGIN):
		_panel.hide()
	_prompt.fade(_in_reach() and not _panel.visible, delta)


func _in_reach(reach: float = Landing.READ_REACH) -> bool:
	if _island == null or _island.wreck < 0 or _island.vardes.is_empty() or player.frozen:
		return false
	return player.grid_position.distance_to(IslandData.center(_island.wreck)) <= reach


## The nearest of the 8 compass directions from cell from to cell to, 0 for north and counting
## clockwise, so 2 is east. North is up on the map, whichever way the camera faces.
static func compass(from: int, to: int) -> int:
	var size: int = IslandData.SIZE
	var east: int = to % size - from % size
	var north: int = from / size - to / size
	return posmod(roundi(atan2(east, north) / (PI / 4.0)), 8)
