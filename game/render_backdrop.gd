extends SceneTree
## Renders the title screen's still backdrop into Backdrop.IMAGE_PATH: the island from
## Backdrop.SEED_TEXT as the game camera shows it at Backdrop.ZOOM, over the whole grid from
## Backdrop.top_left(). The title screen shows it while the live island generates, so render it again
## after a change to the generator or the look. It needs a window, since headless Godot draws nothing:
##     godot -s game/render_backdrop.gd

## Frames to wait before reading the views, so the knowledge texture and the shadows are in place.
const SETTLE_FRAMES: int = 10

var _views: Array[SubViewport] = []
var _cols: int = 0
## The part of the grid of screens that the image keeps, in pixels.
var _crop: Rect2i
var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	var island: IslandData = IslandGenerator.generate(IslandLoader.seed_from(Backdrop.SEED_TEXT))
	var terrain := IslandTerrain.new()
	root.add_child(terrain)
	terrain.show_island(TerrainMesh.build(island), island)
	terrain.knowledge.mark_all(Knowledge.Level.SURVEYED, Knowledge.LONG_AGO)
	root.add_child(Sun.new())

	# The image is a grid of screens, each from its own camera. All of them render in the same frame,
	# so the moving foam and ripples meet at the seams. Past the grid's edge there is no sea, only the
	# clear color with a hard edge against the shallows, so the image stops at the grid.
	var screen: Vector2i = root.content_scale_size
	var cells: Vector2 = Backdrop.pixel_cells(screen.y)
	var corner: Vector2 = Backdrop.top_left(screen.y)
	var size := Vector2i((Vector2(IslandData.SIZE, IslandData.SIZE) - corner) / cells)
	_crop = Rect2i(Vector2i.ZERO, size)
	_cols = ceili(float(size.x) / screen.x)
	var rows: int = ceili(float(size.y) / screen.y)
	for row: int in rows:
		for col: int in _cols:
			var view := SubViewport.new()
			view.size = screen
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var camera := GameCamera.new()
			camera.zoom = Backdrop.ZOOM
			var middle: Vector2 = corner + (Vector2(col, row) + Vector2(0.5, 0.5)) * Vector2(screen) * cells
			camera.focus = Vector3(middle.x, 0.0, middle.y)
			view.add_child(camera)
			root.add_child(view)
			_views.append(view)


func _process(_delta: float) -> bool:
	_frames += 1
	# Placed here, since a camera added in _initialize has no window to read its pixel size from yet.
	if _frames == 1:
		for view: SubViewport in _views:
			(view.get_child(0) as GameCamera).place()
	if _frames < SETTLE_FRAMES:
		return false
	var screen: Vector2i = _views[0].size
	var rows: int = _views.size() / _cols
	var image := Image.create(_cols * screen.x, rows * screen.y, false, Image.FORMAT_RGB8)
	for i: int in _views.size():
		var shot: Image = _views[i].get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		image.blit_rect(shot, Rect2i(Vector2i.ZERO, screen), Vector2i(i % _cols, i / _cols) * screen)
	image = image.get_region(_crop)
	var error: Error = image.save_png(ProjectSettings.globalize_path(Backdrop.IMAGE_PATH))
	if error != OK:
		push_error("Couldn't save %s: %s" % [Backdrop.IMAGE_PATH, error_string(error)])
		return true
	print("Saved %s, %d×%d" % [Backdrop.IMAGE_PATH, image.get_width(), image.get_height()])
	return true
