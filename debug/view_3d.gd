class_name DebugView3D
extends Node3D
## Shows the island as a 3D terrain mesh through the game's orthographic camera, which faces north.
## Arrow keys pan, the scroll wheel zooms, and sliders set the base resolution, zoom, tilt and
## summit height that milestone 2 chooses by eye.

## The base resolutions to choose from. Each one scales to 1920×1080 by a whole number.
const RESOLUTIONS: Array[Vector2i] = [Vector2i(480, 270), Vector2i(640, 360), Vector2i(960, 540)]
## How far the camera sits behind the point it looks at. An orthographic view doesn't change with
## distance, so this only has to keep the tallest terrain between the near and far planes.
const DISTANCE: float = 2000.0
## Screen heights the camera pans per second, so panning feels the same at any zoom.
const PAN_SCREENS_PER_SECOND: float = 1.0
const WHEEL_FACTOR: float = 1.25

var _mesh := MeshInstance3D.new()
var _camera := Camera3D.new()
## The ground point at sea level in the middle of the screen. Panning moves it.
var _focus := Vector3(IslandData.SIZE / 2.0, 0.0, IslandData.SIZE / 2.0)
var _resolution := HSlider.new()
## Cells of flat ground at sea level from the top to the bottom of the screen.
var _zoom := HSlider.new()
## Degrees from looking straight down.
var _tilt := HSlider.new()
## World units from sea level to the highest cell.
var _summit_height := HSlider.new()


func _ready() -> void:
	add_child(_mesh)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.far = DISTANCE * 2.0
	add_child(_camera)
	var sun := DirectionalLight3D.new()
	# From the south-west and 45° up, so the slopes that face the camera are lit.
	sun.rotation_degrees = Vector3(-45.0, -40.0, 0.0)
	add_child(sun)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		var step: Vector2 = direction * _zoom.value * PAN_SCREENS_PER_SECOND * delta
		_focus += Vector3(step.x, 0.0, step.y)
		_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if not is_visible_in_tree() or button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom.value /= WHEEL_FACTOR
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom.value *= WHEEL_FACTOR


## Replaces the terrain with a new island's mesh, colored from a grid-sized material texture.
func show_island(arrays: Array, material_texture: Texture2D) -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_texture = material_texture
	# Nearest filtering gives each cell one flat color with a hard edge to the next material.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	_mesh.mesh = mesh


## The sliders, for the debug view to place in its UI.
func build_controls() -> Control:
	var box := VBoxContainer.new()
	_add_slider(box, _resolution, 0, RESOLUTIONS.size() - 1, 1, 1)
	_add_slider(box, _zoom, 20, IslandData.SIZE, 1, 90)
	_zoom.exp_edit = true
	_add_slider(box, _tilt, 0, 80, 1, 40)
	_add_slider(box, _summit_height, 5, 300, 1, 60)
	for slider: HSlider in [_resolution, _zoom, _tilt, _summit_height]:
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
	_mesh.scale.y = _summit_height.value
	_label(_resolution).text = tr("BASE_RESOLUTION") % [resolution.x, resolution.y]
	_label(_zoom).text = tr("ZOOM_CELLS") % _zoom.value
	_label(_tilt).text = tr("TILT_DEGREES") % _tilt.value
	_label(_summit_height).text = tr("SUMMIT_HEIGHT") % _summit_height.value
	_place_camera()


## Each slider's label sits just before it.
func _label(slider: HSlider) -> Label:
	return slider.get_parent().get_child(slider.get_index() - 1)


func _place_camera() -> void:
	var tilt: float = deg_to_rad(_tilt.value)
	_camera.rotation = Vector3(tilt - PI / 2.0, 0.0, 0.0)
	_camera.position = _focus + _camera.basis.z * DISTANCE
	# Flat ground along north-south shrinks by cos(tilt) on screen, so the view is that much
	# shorter than the ground it covers.
	_camera.size = _zoom.value * cos(tilt)
