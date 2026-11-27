class_name MapScreen
extends CanvasLayer
## The map screen, a square sheet about 90% of the screen's height with the run still going on both
## sides. M opens and closes it, and Escape closes it too. The map is ink on paper at one pixel per
## cell, drawn by map.gdshader into a 1024×1024 SubViewport, which redraws whenever the player learns
## new cells. The sheet follows the player until the player drags it, and the mouse wheel or + and -
## zoom it, and it keeps its zoom between closing and reopening it. North is always up. A red dot
## shows the player, with a pointer on its edge the way the figure faces and a faint wedge the way the
## camera looks, and a small cairn shows each varde the player has built. A hollow cairn shows each
## old varde the player has found, and only those, so a survey doesn't give away a marked way up. A
## list beside the sheet names the notes the player has read, and a click on one shows it again under
## the list, with a red ring around its cell on the map.

const SHADER: Shader = preload("res://map/map.gdshader")
## The sheet's side as a share of the screen's height. Raising it covers more of the run.
const HEIGHT_SHARE: float = 0.9
## Screen pixels per map pixel the player can zoom between, in the 960×540 base resolution, after
## the zoom that fits the whole island on the sheet. Below 1 the map draws with linear filtering, so
## thin lines blend instead of dropping out, and at 1 and up with nearest filtering, so every cell
## stays a crisp pixel.
const ZOOMS: Array[float] = [1.0, 2.0, 4.0]
## The index in _zooms the map first opens at in a run, 1, the first of ZOOMS. Each run makes its
## own map screen, so a new run starts here again.
const OPEN_ZOOM: int = 1
## How far known land takes the color of its ground over the paper, from 0, plain paper, to 1, the
## ground's own color. With plain paper, known land was hard to tell from the unknown paper around
## it, and at 0.45 it reads as a watercolor wash under the ink.
const LAND_TINT: float = 0.45
## Screen pixels of ink around the sheet.
const BORDER: float = 2.0
## Radius of the player's dot in screen pixels.
const MARKER_RADIUS: float = 4.0
## Screen pixels the pointer on the dot's edge reaches past the dot, and half its width where it
## meets the dot. Raising them draws a bigger pointer.
const POINTER_LENGTH: float = 6.0
const POINTER_HALF_WIDTH: float = 3.0
## The wedge that shows where the camera looks: its reach in sheet pixels, half its angle, its
## opacity over the paper, and the points along its arc. A longer or wider wedge reads more easily
## and covers more of the map under it.
const BEAM_LENGTH: float = 22.0
const BEAM_HALF_ANGLE: float = PI / 4.0
const BEAM_ALPHA: float = 0.3
const BEAM_POINTS: int = 8
## Half the width of a varde's cairn in screen pixels. Its height is twice this.
const VARDE_SIZE: float = 4.0
## Half the width of a found old varde's hollow cairn in screen pixels. Smaller than VARDE_SIZE, so
## the player's own vardes stand out among a line of old ones.
const OLD_VARDE_SIZE: float = 3.0
## Radius in screen pixels of the ring around the cell of the note shown under the list.
const NOTE_RING: float = 8.0
## Pixels between the sheet and the list of notes, and between the list and the screen's edge.
const LIST_GAP: float = 8.0

## Set these before adding the node.
var player: Player
var camera: GameCamera
var survey: Survey
var reading: Reading
var _knowledge: Knowledge
## The Knowledge.version the map last drew, or -1 to draw on the next frame.
var _drawn: int = -1
var _viewport := SubViewport.new()
var _sheet := ColorRect.new()
var _view := Control.new()
## The map point in the middle of the sheet.
var _center: Vector2
## The zoom that fits the island on the sheet, then ZOOMS.
var _zooms: Array[float] = []
var _zoom: int = OPEN_ZOOM
## True while the sheet keeps the player in its middle. Dragging the sheet stops it until it reopens.
var _follow: bool = true
## Whether the sheet last drew the whole island for god mode.
var _shown_all: bool = false
var _list := PanelContainer.new()
var _notes := VBoxContainer.new()
var _note_text := Label.new()
## The cell of the note shown under the list, or -1.
var _shown_note: int = -1


func _ready() -> void:
	layer = 4
	hide()
	_viewport.size = Vector2i(IslandData.SIZE, IslandData.SIZE)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sheet.size = Vector2(IslandData.SIZE, IslandData.SIZE)
	_viewport.add_child(_sheet)
	add_child(_viewport)
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var side: float = roundf(screen.y * HEIGHT_SHARE)
	_zooms.append(side / IslandData.SIZE)
	_zooms.append_array(ZOOMS)
	var frame := ColorRect.new()
	frame.color = Ramps.MAP[Ramps.MapPart.INK][0]
	frame.position = ((screen - Vector2(side, side)) / 2.0).round() - Vector2(BORDER, BORDER)
	frame.size = Vector2(side, side) + Vector2(BORDER, BORDER) * 2.0
	add_child(frame)
	_view.position = Vector2(BORDER, BORDER)
	_view.size = Vector2(side, side)
	_view.clip_contents = true
	_view.draw.connect(_draw_map)
	_view.gui_input.connect(_on_view_input)
	frame.add_child(_view)
	_build_list(Vector2(frame.position.x + frame.size.x + LIST_GAP, frame.position.y), screen)


# The list of read notes on a sheet of paper in the space right of the map, with the text of the note
# shown under it. Hidden until the player has read a note.
func _build_list(at: Vector2, screen: Vector2) -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Ramps.MAP[Ramps.MapPart.PAPER][2]
	paper.border_color = Ramps.MAP[Ramps.MapPart.INK][1]
	paper.set_border_width_all(2)
	paper.set_content_margin_all(LIST_GAP)
	_list.add_theme_stylebox_override("panel", paper)
	_list.position = at
	_list.custom_minimum_size.x = screen.x - at.x - LIST_GAP
	_list.hide()
	add_child(_list)
	var column := VBoxContainer.new()
	_list.add_child(column)
	var heading := Label.new()
	heading.text = tr("NOTES")
	column.add_child(heading)
	column.add_child(_notes)
	_note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_text.hide()
	column.add_child(_note_text)
	var ink: Color = Ramps.MAP[Ramps.MapPart.INK][0]
	for label: Label in [heading, _note_text]:
		label.add_theme_color_override("font_color", ink)


## Draws the map of the island terrain shows from here on. It shares the terrain's grid textures
## and knowledge rather than building its own copies, which would be another 6 MB.
func start(terrain: IslandTerrain) -> void:
	_knowledge = terrain.knowledge
	var ground: ShaderMaterial = terrain.ground_material()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for parameter: String in ["height_map", "material_map", "fresh_water_map", "knowledge_map"]:
		material.set_shader_parameter(parameter, ground.get_shader_parameter(parameter))
	material.set_shader_parameter("forest", Ramps.Terrain.FOREST)
	material.set_shader_parameter("snow", Ramps.Terrain.SNOW)
	var paper: PackedColorArray = Ramps.MAP[Ramps.MapPart.PAPER]
	var ink: PackedColorArray = Ramps.MAP[Ramps.MapPart.INK]
	var water: PackedColorArray = Ramps.MAP[Ramps.MapPart.WATER]
	material.set_shader_parameter("paper_stain", paper[0])
	material.set_shader_parameter("paper", paper[1])
	material.set_shader_parameter("paper_land", paper[2])
	material.set_shader_parameter("ink", ink[0])
	material.set_shader_parameter("ink_faded", ink[1])
	material.set_shader_parameter("water_ink", water[0])
	material.set_shader_parameter("sea_wash", water[1])
	var colors := PackedColorArray()
	for kind: Ramps.Terrain in Ramps.Terrain.values():
		colors.append(Ramps.base(kind))
	material.set_shader_parameter("ground", colors)
	material.set_shader_parameter("land_tint", LAND_TINT)
	_sheet.material = material


## Shows the map around the player.
func open() -> void:
	_follow = true
	_set_zoom(_zoom)
	show()


## Hides the map and the note shown under the list.
func close() -> void:
	hide()
	_show_note(-1)


## The names the list gives the notes read, in the order read: the wreck's log, and the varde notes
## numbered from 1.
static func note_titles(read_notes: PackedInt32Array, wreck: int) -> PackedStringArray:
	var titles := PackedStringArray()
	var count: int = 0
	for cell: int in read_notes:
		if cell == wreck:
			titles.append(TranslationServer.translate("NOTE_TITLE_WRECK"))
		else:
			count += 1
			titles.append(TranslationServer.translate("NOTE_TITLE_VARDE") % count)
	return titles


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("zoom_in"):
		_set_zoom(_zoom + 1)
	elif event.is_action_pressed("zoom_out"):
		_set_zoom(_zoom - 1)


func _process(_delta: float) -> void:
	if not visible:
		return
	# The terrain uploads knowledge once a frame, before this node, which comes later in the tree.
	if player.god != _shown_all:
		_shown_all = player.god
		(_sheet.material as ShaderMaterial).set_shader_parameter("show_all", _shown_all)
		_drawn = -1
	if _knowledge.version != _drawn:
		_drawn = _knowledge.version
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _notes.get_child_count() != reading.read_notes.size():
		_list_notes()
	if _follow:
		_center = player.grid_position
	_pan(Vector2.ZERO)


func _list_notes() -> void:
	var titles: PackedStringArray = note_titles(reading.read_notes, reading.wreck)
	for i: int in range(_notes.get_child_count(), titles.size()):
		var button := Button.new()
		button.text = titles[i]
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Without focus, so the arrow keys keep walking the figure instead of moving through the list.
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_show_note.bind(reading.read_notes[i]))
		button.add_theme_color_override("font_color", Ramps.MAP[Ramps.MapPart.INK][1])
		button.add_theme_color_override("font_hover_color", Ramps.MAP[Ramps.MapPart.MARKER][1])
		button.add_theme_color_override("font_pressed_color", Ramps.MAP[Ramps.MapPart.MARKER][1])
		_notes.add_child(button)
	_list.visible = titles.size() > 0


# Shows the note on cell under the list, or hides it for -1 or the note already shown.
func _show_note(cell: int) -> void:
	_shown_note = -1 if cell == _shown_note else cell
	_note_text.visible = _shown_note >= 0
	if _shown_note >= 0:
		_note_text.text = reading.note_at(_shown_note)
	_view.queue_redraw()


func _on_view_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_follow = false
		_pan(-motion.relative / _zooms[_zoom])
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var step: int = 1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		if _follow:
			_set_zoom(_zoom + step)
			return
		# Zooms around the point under the cursor, so it stays under the cursor.
		var before: Vector2 = _to_map(button.position)
		_set_zoom(_zoom + step)
		_pan(before - _to_map(button.position))


func _set_zoom(index: int) -> void:
	_zoom = clampi(index, 0, _zooms.size() - 1)
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if _zooms[_zoom] < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	_pan(Vector2.ZERO)


# Moves the sheet by a map distance, as far as keeps the map covering the whole sheet.
func _pan(by: Vector2) -> void:
	var half: float = minf(_view.size.x / 2.0 / _zooms[_zoom], IslandData.SIZE / 2.0)
	_center = (_center + by).clamp(Vector2(half, half), Vector2(IslandData.SIZE - half, IslandData.SIZE - half))
	_view.queue_redraw()


# The map point under a point on the sheet.
func _to_map(local: Vector2) -> Vector2:
	return _center + (local - _view.size / 2.0) / _zooms[_zoom]


# The sheet point over a map point, in whole pixels, so the sheet doesn't shimmer as it pans.
func _to_screen(point: Vector2) -> Vector2:
	return ((point - _center) * _zooms[_zoom] + _view.size / 2.0).round()


func _draw_map() -> void:
	var corner: Vector2 = _to_screen(Vector2.ZERO)
	_view.draw_texture_rect(_viewport.get_texture(), Rect2(corner, Vector2(IslandData.SIZE, IslandData.SIZE) * _zooms[_zoom]), false)
	var ink: Color = Ramps.MAP[Ramps.MapPart.INK][0]
	var paper: Color = Ramps.MAP[Ramps.MapPart.PAPER][2]
	for cell: int in survey.varde_cells():
		var top: Vector2 = _to_screen(Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5))
		var cairn := PackedVector2Array([top + Vector2(-VARDE_SIZE, VARDE_SIZE), top + Vector2(VARDE_SIZE, VARDE_SIZE), top + Vector2(0.0, -VARDE_SIZE)])
		# A rim of light paper, so the cairn stands apart from the dense contours of a peak.
		_view.draw_polyline(cairn + PackedVector2Array([cairn[0]]), paper, 3.0)
		_view.draw_colored_polygon(cairn, ink)
	for cell: int in reading.found_vardes:
		var top: Vector2 = _to_screen(IslandData.center(cell))
		var cairn := PackedVector2Array([top + Vector2(-OLD_VARDE_SIZE, OLD_VARDE_SIZE), top + Vector2(OLD_VARDE_SIZE, OLD_VARDE_SIZE), top + Vector2(0.0, -OLD_VARDE_SIZE), top + Vector2(-OLD_VARDE_SIZE, OLD_VARDE_SIZE)])
		_view.draw_polyline(cairn, paper, 3.0)
		_view.draw_polyline(cairn, ink, 1.0)
	var marker: PackedColorArray = Ramps.MAP[Ramps.MapPart.MARKER]
	if _shown_note >= 0:
		_view.draw_arc(_to_screen(IslandData.center(_shown_note)), NOTE_RING, 0.0, TAU, 24, marker[1], 2.0)
	var at: Vector2 = _to_screen(player.grid_position)
	# The camera's forward on the ground, in map axes with y south. At heading 0 it points north.
	var view := Vector2(-sin(camera.heading), -cos(camera.heading))
	# A faint wedge toward where the camera looks, under the marker, so the arrow is free to show
	# the way the figure faces.
	var beam := PackedVector2Array([at])
	for k: int in BEAM_POINTS + 1:
		beam.append(at + view.rotated(lerpf(-BEAM_HALF_ANGLE, BEAM_HALF_ANGLE, float(k) / BEAM_POINTS)) * BEAM_LENGTH)
	_view.draw_colored_polygon(beam, Color(marker[1], BEAM_ALPHA))
	var ahead: Vector2 = player.facing_direction
	var side: Vector2 = ahead.orthogonal() * POINTER_HALF_WIDTH
	var base: Vector2 = at + ahead * (MARKER_RADIUS - 1.0)
	var tip: Vector2 = at + ahead * (MARKER_RADIUS + POINTER_LENGTH)
	# The dark shapes go first and a pixel larger, so they draw the rim around the red ones.
	_view.draw_circle(at, MARKER_RADIUS + 1.0, marker[0])
	_view.draw_colored_polygon(PackedVector2Array([tip + ahead, base + side * 1.4, base - side * 1.4]), marker[0])
	_view.draw_circle(at, MARKER_RADIUS, marker[1])
	_view.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), marker[1])
