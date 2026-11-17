class_name DebugView3D
extends Node3D
## Shows the island as a 3D terrain mesh through the game's orthographic camera, which faces north.
## Arrow keys or dragging with the left mouse button pan, the scroll wheel zooms, and sliders set the base resolution, zoom, tilt and
## summit height. Milestone 2 chose their starting values by eye. One more slider moves the sun, so its shadows can be
## checked from morning to evening.

## The base resolutions to choose from. Each one scales to 1920×1080 by a whole number.
const RESOLUTIONS: Array[Vector2i] = [Vector2i(480, 270), Vector2i(640, 360), Vector2i(960, 540)]
## Screen heights the camera pans per second, so panning feels the same at any zoom.
const PAN_SCREENS_PER_SECOND: float = 1.0
## How much one wheel step zooms. Raising it zooms in bigger jumps, lowering it in finer ones.
const WHEEL_FACTOR: float = 1.25

var _terrain := IslandTerrain.new()
var _camera := GameCamera.new()
var _sun := Sun.new()
var _resolution := HSlider.new()
## Cells of flat ground at sea level from the top to the bottom of the screen.
var _zoom := HSlider.new()
## Degrees from looking straight down.
var _tilt := HSlider.new()
## World units from sea level to the highest cell.
var _summit_height := HSlider.new()
## Degrees along the sun's path, from the eastern horizon at 0 through south at 90 to the western
## horizon at 180.
var _sun_angle := HSlider.new()


func _ready() -> void:
	add_child(_terrain)
	add_child(_camera)
	add_child(_sun)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		var step: Vector2 = direction * _zoom.value * PAN_SCREENS_PER_SECOND * delta
		_camera.focus += Vector3(step.x, 0.0, step.y)
		_camera.place()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		# Moves the ground at sea level with the cursor. The screen is _zoom cells of that ground tall.
		var cells: Vector2 = motion.relative * _zoom.value / get_viewport().get_visible_rect().size.y
		_camera.focus -= Vector3(cells.x, 0.0, cells.y)
		_camera.place()
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom.value /= WHEEL_FACTOR
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom.value *= WHEEL_FACTOR


## Replaces the terrain with a new island's chunk meshes, drawn by the terrain shader.
func show_island(meshes: Array[ArrayMesh], island: IslandData) -> void:
	_terrain.show_island(meshes, island)


## The sliders, for the debug view to place in its UI.
func build_controls() -> Control:
	var box := VBoxContainer.new()
	_add_slider(box, _resolution, 0, RESOLUTIONS.size() - 1, 1, 2)
	_add_slider(box, _zoom, 20, IslandData.SIZE, 1, GameCamera.ZOOM)
	_zoom.exp_edit = true
	_add_slider(box, _tilt, 0, 80, 1, GameCamera.TILT_DEGREES)
	_add_slider(box, _summit_height, 5, 300, 1, IslandTerrain.SUMMIT_HEIGHT)
	_add_slider(box, _sun_angle, 5, 175, 1, Sun.START_ANGLE)
	for slider: HSlider in [_resolution, _zoom, _tilt, _summit_height, _sun_angle]:
		slider.value_changed.connect(_apply.unbind(1))
	_apply()
	return box


func _add_slider(box: VBoxContainer, slider: HSlider, low: float, high: float, step: float, start: float) -> void:
	var label := Label.new()
	box.add_child(label)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = start
	slider.custom_minimum_size.x = 120
	# Arrow keys pan the camera, so the sliders mustn't take focus and eat them.
	slider.focus_mode = Control.FOCUS_NONE
	box.add_child(slider)


func _apply() -> void:
	var resolution: Vector2i = RESOLUTIONS[int(_resolution.value)]
	get_window().content_scale_size = resolution
	_terrain.set_summit_height(_summit_height.value)
	_label(_resolution).text = tr("BASE_RESOLUTION") % [resolution.x, resolution.y]
	_label(_zoom).text = tr("ZOOM_CELLS") % _zoom.value
	_label(_tilt).text = tr("TILT_DEGREES") % _tilt.value
	_label(_summit_height).text = tr("SUMMIT_HEIGHT") % _summit_height.value
	_label(_sun_angle).text = tr("SUN_ANGLE") % _sun_angle.value
	_sun.set_angle(_sun_angle.value)
	_camera.zoom = _zoom.value
	_camera.tilt_degrees = _tilt.value
	_camera.summit_height = _summit_height.value
	_camera.place()


## Each slider's label sits just before it.
func _label(slider: HSlider) -> Label:
	return slider.get_parent().get_child(slider.get_index() - 1)
