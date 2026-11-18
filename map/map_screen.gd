class_name MapScreen
extends CanvasLayer
## The map screen. M opens it over the paused run and M or Escape closes it. The map is ink on paper
## at one pixel per cell, drawn by map.gdshader into a 1024×1024 SubViewport each time the screen
## opens, so it shows what the player knows at that moment. The player pans it with the walking keys
## or by dragging, and zooms with the mouse wheel or + and -. North is always up. A red marker shows
## the player, and a small cairn shows each varde the player has built.

const SHADER: Shader = preload("res://map/map.gdshader")
## Screen pixels per map pixel the player can zoom between, in the 960×540 base resolution. Below 1
## the map draws with linear filtering, so thin lines blend instead of dropping out, and at 1 and up
## it draws with nearest filtering, so every cell stays a crisp pixel. At 0.5 the whole sheet fits
## the screen's height.
const ZOOMS: Array[float] = [0.5, 1.0, 2.0, 4.0]
## The index in ZOOMS the map opens at.
const OPEN_ZOOM: int = 1
## Screen pixels per second the walking keys pan the map. Raising it pans faster.
const PAN_SPEED: float = 400.0
## Radius of the player's marker in screen pixels.
const MARKER_RADIUS: float = 4.0
## Half the width of a varde's cairn in screen pixels. Its height is twice this.
const VARDE_SIZE: float = 3.0

## Set these before adding the node.
var player: Player
var survey: Survey
var _knowledge: Knowledge
var _viewport := SubViewport.new()
var _sheet := ColorRect.new()
var _view := Control.new()
## The map point in the middle of the screen.
var _center: Vector2
var _zoom: int = OPEN_ZOOM


func _ready() -> void:
	# Runs while the tree is paused, so the map pans and closes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	hide()
	_viewport.size = Vector2i(IslandData.SIZE, IslandData.SIZE)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sheet.size = Vector2(IslandData.SIZE, IslandData.SIZE)
	_viewport.add_child(_sheet)
	add_child(_viewport)
	# The table under the sheet, the darkest ink, so the sheet's edge shows when the player pans past it.
	var table := ColorRect.new()
	table.color = Ramps.MAP[Ramps.MapPart.INK][0]
	table.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(table)
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_map)
	_view.gui_input.connect(_on_view_input)
	add_child(_view)


## Draws the map of island from here on, with knowledge as what the player knows.
func start(island: IslandData, knowledge: Knowledge) -> void:
	_knowledge = knowledge
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("height_map", _grid(Image.FORMAT_RF, island.height.to_byte_array()))
	material.set_shader_parameter("material_map", _grid(Image.FORMAT_R8, island.material))
	material.set_shader_parameter("fresh_water_map", _grid(Image.FORMAT_R8, island.fresh_water))
	material.set_shader_parameter("knowledge_map", knowledge.texture)
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
	_sheet.material = material


## Pauses the run, redraws the map from what the player knows now, and shows it around the player.
func open() -> void:
	# The terrain uploads knowledge once a frame, so marks made this frame go up first.
	_knowledge.upload()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_center = player.grid_position
	_set_zoom(OPEN_ZOOM)
	get_tree().paused = true
	show()


## Hides the map and resumes the run.
func close() -> void:
	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("map_zoom_in"):
		_set_zoom(_zoom + 1)
	elif event.is_action_pressed("map_zoom_out"):
		_set_zoom(_zoom - 1)


func _process(delta: float) -> void:
	if not visible:
		return
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		_pan(direction * PAN_SPEED * delta / ZOOMS[_zoom])


func _on_view_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_pan(-motion.relative / ZOOMS[_zoom])
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# Zooms around the point under the cursor, so it stays under the cursor.
		var before: Vector2 = _to_map(button.position)
		_set_zoom(_zoom + (1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1))
		_pan(before - _to_map(button.position))


func _set_zoom(index: int) -> void:
	_zoom = clampi(index, 0, ZOOMS.size() - 1)
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if ZOOMS[_zoom] < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	_pan(Vector2.ZERO)


func _pan(by: Vector2) -> void:
	_center = (_center + by).clamp(Vector2.ZERO, Vector2(IslandData.SIZE, IslandData.SIZE))
	_view.queue_redraw()


# The map point under a point on the screen.
func _to_map(screen: Vector2) -> Vector2:
	return _center + (screen - _view.size / 2.0) / ZOOMS[_zoom]


# The screen point over a map point, in whole pixels, so the sheet doesn't shimmer as it pans.
func _to_screen(point: Vector2) -> Vector2:
	return ((point - _center) * ZOOMS[_zoom] + _view.size / 2.0).round()


func _draw_map() -> void:
	var corner: Vector2 = _to_screen(Vector2.ZERO)
	_view.draw_texture_rect(_viewport.get_texture(), Rect2(corner, Vector2(IslandData.SIZE, IslandData.SIZE) * ZOOMS[_zoom]), false)
	var ink: Color = Ramps.MAP[Ramps.MapPart.INK][0]
	for cell: int in survey.varde_cells():
		var top: Vector2 = _to_screen(Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5))
		_view.draw_colored_polygon(PackedVector2Array([top + Vector2(-VARDE_SIZE, VARDE_SIZE), top + Vector2(VARDE_SIZE, VARDE_SIZE), top + Vector2(0.0, -VARDE_SIZE)]), ink)
	var marker: PackedColorArray = Ramps.MAP[Ramps.MapPart.MARKER]
	var at: Vector2 = _to_screen(player.grid_position)
	_view.draw_circle(at, MARKER_RADIUS + 1.0, marker[0])
	_view.draw_circle(at, MARKER_RADIUS, marker[1])


# A texture over the island's grid from one of its arrays.
static func _grid(format: Image.Format, data: PackedByteArray) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, format, data))
