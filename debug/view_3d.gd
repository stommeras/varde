class_name DebugView3D
extends Node3D
## Shows the island as a 3D terrain mesh through the game's orthographic camera, which faces north.
## Arrow keys or dragging with the left mouse button pan, the scroll wheel zooms, and sliders set the base resolution, zoom, tilt and
## summit height that milestone 2 chooses by eye.

## The base resolutions to choose from. Each one scales to 1920×1080 by a whole number.
const RESOLUTIONS: Array[Vector2i] = [Vector2i(480, 270), Vector2i(640, 360), Vector2i(960, 540)]
## How far the camera sits behind the point it looks at. An orthographic view doesn't change with
## distance, so this only has to keep the tallest terrain between the near and far planes.
const DISTANCE: float = 2000.0
## Screen heights the camera pans per second, so panning feels the same at any zoom.
const PAN_SCREENS_PER_SECOND: float = 1.0
## How much one wheel step zooms. Raising it zooms in bigger jumps, lowering it in finer ones.
const WHEEL_FACTOR: float = 1.25

## Holds one MeshInstance3D per terrain chunk. Its y scale is the summit height.
var _terrain := Node3D.new()
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
	add_child(_terrain)
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
	if not is_visible_in_tree():
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		# Moves the ground at sea level with the cursor. The screen is _zoom cells of that ground tall.
		var cells: Vector2 = motion.relative * _zoom.value / get_viewport().get_visible_rect().size.y
		_focus -= Vector3(cells.x, 0.0, cells.y)
		_place_camera()
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
	for chunk: Node in _terrain.get_children():
		# Removed now, so _apply_lod_bias doesn't also walk the chunks waiting to be freed.
		_terrain.remove_child(chunk)
		chunk.queue_free()
	var material: ShaderMaterial = TerrainMaterial.create(island)
	for mesh: ArrayMesh in meshes:
		var chunk := MeshInstance3D.new()
		chunk.mesh = mesh
		chunk.material_override = material
		_terrain.add_child(chunk)
	_apply_lod_bias()


## The sliders, for the debug view to place in its UI.
func build_controls() -> Control:
	var box := VBoxContainer.new()
	# Starting points from #23, to replace with the values chosen here by eye once the terrain is smooth (#31).
	_add_slider(box, _resolution, 0, RESOLUTIONS.size() - 1, 1, 2)
	_add_slider(box, _zoom, 20, IslandData.SIZE, 1, 80)
	_zoom.exp_edit = true
	_add_slider(box, _tilt, 0, 80, 1, 45)
	_add_slider(box, _summit_height, 5, 300, 1, 100)
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
	_terrain.scale.y = _summit_height.value
	_apply_lod_bias()
	_label(_resolution).text = tr("BASE_RESOLUTION") % [resolution.x, resolution.y]
	_label(_zoom).text = tr("ZOOM_CELLS") % _zoom.value
	_label(_tilt).text = tr("TILT_DEGREES") % _tilt.value
	_label(_summit_height).text = tr("SUMMIT_HEIGHT") % _summit_height.value
	_place_camera()


# Godot scales a mesh's level-of-detail distances by the node's largest scale, which is the summit
# height here. That only stretches heights, so the bias cancels it and the level follows the zoom.
func _apply_lod_bias() -> void:
	for chunk: MeshInstance3D in _terrain.get_children():
		chunk.lod_bias = 1.0 / maxf(_terrain.scale.y, 1.0)


## Each slider's label sits just before it.
func _label(slider: HSlider) -> Label:
	return slider.get_parent().get_child(slider.get_index() - 1)


func _place_camera() -> void:
	var tilt: float = deg_to_rad(_tilt.value)
	_camera.rotation = Vector3(tilt - PI / 2.0, 0.0, 0.0)
	# Flat ground along north-south shrinks by cos(tilt) on screen, so the view is that much
	# shorter than the ground it covers.
	_camera.size = _zoom.value * cos(tilt)
	# A camera that moves by part of a pixel makes every edge and dither pattern crawl. Snapping its
	# position along its right and up axes to whole pixels moves the image in whole pixels instead.
	# _focus keeps the exact position, so slow panning still adds up.
	var pixel: float = _camera.size / get_window().content_scale_size.y
	var local: Vector3 = _camera.basis.inverse() * (_focus + _camera.basis.z * DISTANCE)
	local.x = snappedf(local.x, pixel)
	local.y = snappedf(local.y, pixel)
	_camera.position = _camera.basis * local
