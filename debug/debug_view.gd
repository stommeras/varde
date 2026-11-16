extends Node2D
## Shows a generated island's layers as images, with a seed field and a free camera.
## Arrow keys pan, the scroll wheel zooms, and 1x zoom matches the game's scale.

const PIXELS_PER_CELL: int = 4
const PAN_SPEED: float = 400.0
const ZOOM_MIN: float = 0.08
const ZOOM_MAX: float = 4.0
## Height is drawn from a table of this many colors per side of sea level, instead of one lookup per cell.
const SHADES: int = 256

var _island: IslandData
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

	row.add_child(_info)
	for control: Control in [seed_label, _seed_field, random, _info]:
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
	_sprite.texture = ImageTexture.create_from_image(_height_image(_island.height))
	# Fit the whole island on screen.
	var world: float = IslandData.SIZE * PIXELS_PER_CELL
	_camera.position = Vector2.ONE * world / 2.0
	_set_zoom(get_viewport_rect().size.y / world)


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
		var shade: int = int(clampf(h if h >= 0.0 else h + 1.0, 0.0, 1.0) * (SHADES - 1)) * 3
		var table: PackedByteArray = land if h >= 0.0 else sea
		pixels[i * 3] = table[shade]
		pixels[i * 3 + 1] = table[shade + 1]
		pixels[i * 3 + 2] = table[shade + 2]
	return Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_RGB8, pixels)


func _rgb(color: Color) -> PackedByteArray:
	return PackedByteArray([color.r8, color.g8, color.b8])
