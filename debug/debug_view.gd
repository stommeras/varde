extends Node2D
## Shows a generated island's layers as images, with a seed field, layer buttons and a free camera,
## and a 3D view of the terrain beside them. The island and its terrain mesh build on a background
## thread behind a "charting the island" screen. Arrow keys or dragging with the left mouse button pan, the scroll wheel zooms, and 1x zoom
## matches the game's scale.

const PIXELS_PER_CELL: int = 4
const PAN_SPEED: float = 400.0
const ZOOM_MIN: float = 0.08
const ZOOM_MAX: float = 4.0
## Height and moisture are drawn from a table of this many colors, instead of one ramp lookup per cell.
const SHADES: int = 256

enum Layer { HEIGHT, MOISTURE, MATERIAL }

## The translation key for each layer's button.
const LAYER_NAMES: Dictionary[Layer, String] = {
	Layer.HEIGHT: "LAYER_HEIGHT",
	Layer.MOISTURE: "LAYER_MOISTURE",
	Layer.MATERIAL: "LAYER_MATERIAL",
}

var _island: IslandData
var _layer: Layer = Layer.HEIGHT
var _sprite := Sprite2D.new()
var _camera := Camera2D.new()
var _seed_field := LineEdit.new()
var _info := Label.new()
## The material layer as a texture, built once per island.
var _material_texture: ImageTexture
var _view_3d := DebugView3D.new()
## The 3D view's sliders, shown only with it.
var _controls_3d: Control
## Covers the view while the generator runs.
var _charting := ColorRect.new()
## Null means no generation is running.
var _thread: Thread


func _ready() -> void:
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	_sprite.centered = false
	_sprite.scale = Vector2.ONE * PIXELS_PER_CELL
	add_child(_sprite)
	add_child(_camera)
	_view_3d.hide()
	add_child(_view_3d)
	_build_ui()
	_generate(0)


func _process(delta: float) -> void:
	if _thread != null and not _thread.is_alive():
		_finish_generating()
	if _view_3d.visible:
		return
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += direction * PAN_SPEED * delta / _camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if _view_3d.visible:
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		# Moves the view with the cursor, as if dragging the map.
		_camera.position -= motion.relative / _camera.zoom
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_zoom(_camera.zoom.x * 1.25)
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_zoom(_camera.zoom.x / 1.25)


func _set_zoom(zoom: float) -> void:
	_camera.zoom = Vector2.ONE * clampf(zoom, ZOOM_MIN, ZOOM_MAX)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var row := HBoxContainer.new()
	row.position = Vector2(4, 4)
	row.add_theme_constant_override("separation", 4)
	layer.add_child(row)

	var seed_label := Label.new()
	seed_label.text = tr("SEED")
	row.add_child(seed_label)

	_seed_field.custom_minimum_size.x = 96
	_seed_field.text_submitted.connect(_on_seed_submitted)
	row.add_child(_seed_field)

	var random := Button.new()
	random.text = tr("RANDOM_SEED")
	random.focus_mode = Control.FOCUS_NONE
	random.pressed.connect(func() -> void: _generate(randi()))
	row.add_child(random)

	var group := ButtonGroup.new()
	for shown: Layer in LAYER_NAMES:
		var button := Button.new()
		button.text = tr(LAYER_NAMES[shown])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = shown == _layer
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_show.bind(shown))
		row.add_child(button)

	var button_3d := Button.new()
	button_3d.text = tr("VIEW_3D")
	button_3d.toggle_mode = true
	button_3d.button_group = group
	button_3d.focus_mode = Control.FOCUS_NONE
	button_3d.pressed.connect(_show_3d)
	row.add_child(button_3d)

	row.add_child(_info)
	_controls_3d = _view_3d.build_controls()
	_controls_3d.position = Vector2(4, 24)
	_controls_3d.hide()
	layer.add_child(_controls_3d)
	for control: Control in row.get_children() + _controls_3d.get_children():
		control.add_theme_font_size_override("font_size", 10)

	_charting.color = Ramps.RAMPS[Ramps.Terrain.WATER][0]
	_charting.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_charting)
	var charting_label := Label.new()
	charting_label.text = tr("CHARTING_ISLAND")
	charting_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	charting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	charting_label.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	_charting.add_child(charting_label)


func _on_seed_submitted(text: String) -> void:
	_seed_field.release_focus()
	if text.is_valid_int():
		_generate(text.to_int())


## Starts the generator on a thread. A request while one is running is dropped.
func _generate(island_seed: int) -> void:
	if _thread != null:
		return
	_charting.show()
	_thread = Thread.new()
	_thread.start(_build.bind(island_seed))


## Runs on the generator thread. Returns the island, its terrain chunk meshes and their build time.
static func _build(island_seed: int) -> Array:
	var island: IslandData = IslandGenerator.generate(island_seed)
	var started: int = Time.get_ticks_msec()
	var meshes: Array[ArrayMesh] = TerrainMesh.build(island)
	return [island, meshes, Time.get_ticks_msec() - started]


func _finish_generating() -> void:
	var result: Array = _thread.wait_to_finish()
	_thread = null
	_island = result[0]
	# Set here, not in _generate, so a request dropped mid-run can't leave the wrong seed showing.
	_seed_field.text = str(_island.island_seed)
	# The total sums the steps instead of timing from _generate, because a hidden window runs at
	# about 1 frame per second and the poll in _process would add up to a second.
	var total: int = 0
	var steps := PackedStringArray()
	for step: String in _island.step_msec:
		total += _island.step_msec[step]
		steps.append("%s %d ms" % [step, _island.step_msec[step]])
	print("Seed %d: %s, total %d ms, then the mesh %d ms" % [_island.island_seed, ", ".join(steps), total, result[2]])
	_info.text = "%d ms" % total
	_material_texture = ImageTexture.create_from_image(_material_image(_island.material, _island.main_island))
	_view_3d.show_island(result[1], _island)
	_charting.hide()
	if not _view_3d.visible:
		_show(_layer)
	# Fit the whole island on screen.
	var world: float = IslandData.SIZE * PIXELS_PER_CELL
	_camera.position = Vector2.ONE * world / 2.0
	_set_zoom(get_viewport_rect().size.y / world)


# A thread still running when the node leaves must be joined, or Godot reports a leaked thread.
func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


func _show(layer: Layer) -> void:
	_layer = layer
	_view_3d.hide()
	_controls_3d.hide()
	_sprite.show()
	match layer:
		Layer.HEIGHT:
			_sprite.texture = ImageTexture.create_from_image(_height_image(_island.height))
		Layer.MOISTURE:
			_sprite.texture = ImageTexture.create_from_image(_moisture_image(_island.moisture))
		Layer.MATERIAL:
			_sprite.texture = _material_texture


func _show_3d() -> void:
	_sprite.hide()
	_view_3d.show()
	_controls_3d.show()


## Sea runs along the water ramp by depth, land along the rock ramp by height.
func _height_image(height: PackedFloat32Array) -> Image:
	var sea := PackedByteArray()
	var land := PackedByteArray()
	for i: int in SHADES:
		var t: float = float(i) / (SHADES - 1)
		sea.append_array(_rgb(Ramps.sample(Ramps.Terrain.WATER, t)))
		land.append_array(_rgb(Ramps.sample(Ramps.Terrain.ROCK, t)))

	var pixels := PackedByteArray()
	pixels.resize(height.size() * 3)
	for i: int in height.size():
		var h: float = height[i]
		# The sea floor rarely drops below -1, so depth is clamped there.
		var shade: int = int(clampf(h if h > 0.0 else h + 1.0, 0.0, 1.0) * (SHADES - 1)) * 3
		var table: PackedByteArray = land if h > 0.0 else sea
		pixels[i * 3] = table[shade]
		pixels[i * 3 + 1] = table[shade + 1]
		pixels[i * 3 + 2] = table[shade + 2]
	return Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_RGB8, pixels)


## Moisture runs along the water ramp, from dark when dry to light when wet.
func _moisture_image(moisture: PackedFloat32Array) -> Image:
	var table := PackedByteArray()
	for i: int in SHADES:
		table.append_array(_rgb(Ramps.sample(Ramps.Terrain.WATER, float(i) / (SHADES - 1))))
	var pixels := PackedByteArray()
	pixels.resize(moisture.size() * 3)
	for i: int in moisture.size():
		var shade: int = int(moisture[i] * (SHADES - 1)) * 3
		pixels[i * 3] = table[shade]
		pixels[i * 3 + 1] = table[shade + 1]
		pixels[i * 3 + 2] = table[shade + 2]
	return Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_RGB8, pixels)


## Each material in its ramp's middle step. Islets use the darkest step, so the main island stands out.
func _material_image(terrain: PackedByteArray, main_island: PackedByteArray) -> Image:
	var main := PackedByteArray()
	var islet := PackedByteArray()
	for kind: Ramps.Terrain in Ramps.Terrain.values():
		main.append_array(_rgb(Ramps.base(kind)))
		islet.append_array(_rgb(Ramps.RAMPS[kind][0]))
	var pixels := PackedByteArray()
	pixels.resize(terrain.size() * 3)
	for i: int in terrain.size():
		var table: PackedByteArray = main if main_island[i] == 1 or terrain[i] == Ramps.Terrain.WATER else islet
		var color: int = terrain[i] * 3
		pixels[i * 3] = table[color]
		pixels[i * 3 + 1] = table[color + 1]
		pixels[i * 3 + 2] = table[color + 2]
	return Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_RGB8, pixels)


func _rgb(color: Color) -> PackedByteArray:
	return PackedByteArray([color.r8, color.g8, color.b8])
