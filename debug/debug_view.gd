extends Node2D
## Shows a generated island's layers as images, with a seed field, layer buttons and a free camera.
## Arrow keys pan, the scroll wheel zooms, and 1x zoom matches the game's scale.

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


func _ready() -> void:
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	_sprite.centered = false
	_sprite.scale = Vector2.ONE * PIXELS_PER_CELL
	add_child(_sprite)
	add_child(_camera)
	_build_ui()
	_generate(0)


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += direction * PAN_SPEED * delta / _camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
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

	row.add_child(_info)
	for control: Control in row.get_children():
		control.add_theme_font_size_override("font_size", 10)


func _on_seed_submitted(text: String) -> void:
	_seed_field.release_focus()
	if text.is_valid_int():
		_generate(text.to_int())


func _generate(island_seed: int) -> void:
	var started: int = Time.get_ticks_msec()
	_island = IslandGenerator.generate(island_seed)
	_info.text = "%d ms" % (Time.get_ticks_msec() - started)
	_seed_field.text = str(island_seed)
	_show(_layer)
	# Fit the whole island on screen.
	var world: float = IslandData.SIZE * PIXELS_PER_CELL
	_camera.position = Vector2.ONE * world / 2.0
	_set_zoom(get_viewport_rect().size.y / world)


func _show(layer: Layer) -> void:
	_layer = layer
	var image: Image
	match layer:
		Layer.HEIGHT:
			image = _height_image(_island.height)
		Layer.MOISTURE:
			image = _moisture_image(_island.moisture)
		Layer.MATERIAL:
			image = _material_image(_island.material, _island.main_island)
	_sprite.texture = ImageTexture.create_from_image(image)


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
