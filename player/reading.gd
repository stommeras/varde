class_name Reading
extends CanvasLayer
## Reading the notes the island holds, on the shipwreck and on the top varde of each line of old
## vardes. Within reach of one, Landing.READ_REACH of the wreck or Trail.READ_REACH of a varde, it
## shows "[F] Les", and F opens that note in a panel of map paper over the game. The world keeps
## running. F or Escape closes it, and so does walking CLOSE_MARGIN past the reach, so the note
## doesn't follow the player. A note that opened by itself would stop the player each time they
## walked past. A top varde's note names the direction of the nearest higher peak, or says that none
## stands higher. A later issue writes the notes from the island's features. The node also records the
## vardes found and the notes read, for the map screen and the end screen.

## Width of the note panel in base-resolution pixels. Raising it gives longer lines and a lower panel.
const WIDTH: int = 360
## Pixels between the panel's edge and its text.
const PADDING: int = 16
## Pixels from the top of the screen to the panel. It sits high, so it leaves the figure in the
## middle of the screen in view while the player walks with the note open.
const TOP: int = 32
## Cells past a note's reach the player walks before an open note closes. The start lies about
## 3.2 cells from the wreck, so at 0 the first step away closed the note in under a quarter of a
## second. Raising it lets the player walk further while reading.
const CLOSE_MARGIN: float = 3.0

## Set it before adding the node.
var player: Player
## The cells of the old vardes the player has come within Trail.READ_REACH of, in the order found.
var found_vardes := PackedInt32Array()
## The cells of the wreck and the old vardes whose notes the player has opened, in the order read.
var read_notes := PackedInt32Array()
## The wreck's cell, or -1 if the island has no wreck.
var wreck: int = -1
## The cell, reach and text of each note, the wreck's first.
var _cells := PackedInt32Array()
var _reaches := PackedFloat32Array()
var _texts := PackedStringArray()
## The cells of every old varde, with a note or not.
var vardes := PackedInt32Array()
## The note open in the panel, an index into _cells, or -1.
var _open: int = -1
var _prompt := Prompt.new("READ")
var _panel := PanelContainer.new()
var _text := Label.new()


func _init() -> void:
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


## Starts a new island with the note closed and nothing found or read.
func start(island: IslandData) -> void:
	_close()
	found_vardes.clear()
	read_notes.clear()
	_cells.clear()
	_reaches.clear()
	_texts.clear()
	vardes = island.vardes
	wreck = island.wreck
	if island.wreck >= 0:
		_add(island.wreck, Landing.READ_REACH, tr("NOTE_WRECK"))
	var peaks: PackedInt32Array = island.varde_peaks
	for i: int in vardes.size():
		var top: int = peaks[i]
		if i < vardes.size() - 1 and peaks[i + 1] == top:
			continue
		var higher: int = Trail.higher_peak(island, top)
		_add(vardes[i], Trail.READ_REACH, tr("NOTE_SUMMIT") if higher < 0 else tr("NOTE_HIGHER") % tr("COMPASS_%d" % compass(top, higher)))


func _unhandled_input(event: InputEvent) -> void:
	if _open >= 0 and (event.is_action_pressed("survey") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_close()
		return
	# F reads as it surveys, since no note lies in reach of a peak's zone.
	var note: int = _in_reach()
	if note >= 0 and event.is_action_pressed("survey"):
		get_viewport().set_input_as_handled()
		_open = note
		_text.text = _texts[note]
		_panel.show()
		if not read_notes.has(_cells[note]):
			read_notes.append(_cells[note])


func _process(delta: float) -> void:
	if _open >= 0 and not _within(_open, CLOSE_MARGIN):
		_close()
	for varde: int in vardes:
		if not found_vardes.has(varde) and player.grid_position.distance_to(IslandData.center(varde)) <= Trail.READ_REACH:
			found_vardes.append(varde)
	_prompt.fade(_in_reach() >= 0 and _open < 0, delta)


## The text of the note on cell, or an empty string if no note lies there.
func note_at(cell: int) -> String:
	var note: int = _cells.find(cell)
	return _texts[note] if note >= 0 else ""


func _add(cell: int, reach: float, text: String) -> void:
	_cells.append(cell)
	_reaches.append(reach)
	_texts.append(text)


func _close() -> void:
	_open = -1
	_panel.hide()


## The note whose reach the player stands in, or -1.
func _in_reach() -> int:
	if player.frozen:
		return -1
	for note: int in _cells.size():
		if _within(note, 0.0):
			return note
	return -1


func _within(note: int, margin: float) -> bool:
	return player.grid_position.distance_to(IslandData.center(_cells[note])) <= _reaches[note] + margin


## The nearest of the 8 compass directions from cell from to cell to, 0 for north and counting
## clockwise, so 2 is east. North is up on the map, whichever way the camera faces.
static func compass(from: int, to: int) -> int:
	var size: int = IslandData.SIZE
	var east: int = to % size - from % size
	var north: int = from / size - to / size
	return posmod(roundi(atan2(east, north) / (PI / 4.0)), 8)
