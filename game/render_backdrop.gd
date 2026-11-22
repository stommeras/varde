extends SceneTree
## Renders the title screen's backdrop into game/backdrop.png: the island from seed "varde" as the
## game camera shows it at zoom 256, so the title screen loads without generating anything. The image
## goes stale when the generator or the look changes, so run this again then. It needs a window,
## since headless Godot draws nothing:
##     godot -s game/render_backdrop.gd

## Text the seed comes from, as if typed into the seed field. Chosen by eye from frames of a few
## candidates.
const SEED_TEXT: String = "varde"
## Cells of ground from the top to the bottom of the screen. Far above the game's zoom, so the island
## reads as a whole and the pan crosses it in a few minutes. Raising it shows more island, smaller.
const ZOOM: float = 256.0
const OUTPUT: String = "res://game/backdrop.png"
## Frames to wait before reading the views, so the knowledge texture and the shadows are in place.
const SETTLE_FRAMES: int = 10

var _views: Array[SubViewport] = []
var _cols: int = 0
## The part of the grid of screens that the image keeps, in pixels.
var _crop: Rect2i
var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	var island: IslandData = IslandGenerator.generate(IslandLoader.seed_from(SEED_TEXT))
	var terrain := IslandTerrain.new()
	root.add_child(terrain)
	terrain.show_island(TerrainMesh.build(island), island)
	terrain.knowledge.mark_all(Knowledge.Level.SURVEYED, Knowledge.LONG_AGO)
	root.add_child(Sun.new())

	# The land's bounding box in cells, islets too.
	var low := Vector2i(IslandData.SIZE, IslandData.SIZE)
	var high := Vector2i.ZERO
	for i: int in island.height.size():
		if island.height[i] > 0.0:
			var cell := Vector2i(i % IslandData.SIZE, i / IslandData.SIZE)
			low = low.min(cell)
			high = high.max(cell)

	# The image is a grid of screens, each from its own camera. All of them render in the same frame,
	# so the moving foam and ripples meet at the seams. The middle of the corner screens sits on the
	# box's corners, so the image reaches half a screen past the land on every side. The top reaches
	# a summit's height further, since high ground shows that much north of its cell.
	var screen: Vector2i = root.content_scale_size
	var tilt: float = deg_to_rad(GameCamera.TILT_DEGREES)
	var pixel: float = ZOOM * cos(tilt) / screen.y
	# One screen is ZOOM cells of flat ground tall, and that across.
	var step := Vector2(pixel * screen.x, ZOOM)
	# Snapped to the camera's pixel grid, so every camera's own snap keeps the same offset and the
	# screens join without a gap or an overlap. Ground along z shows cos(tilt) as long on screen.
	var origin := Vector2(snappedf(low.x, pixel), snappedf(low.y - IslandTerrain.SUMMIT_HEIGHT, pixel / cos(tilt)))
	_cols = ceili((high.x - origin.x) / step.x) + 1
	var rows: int = ceili((high.y - origin.y) / step.y) + 1
	# The screens reach up to a whole screen past the land, and past the grid's edge there is no sea,
	# only the clear color with a hard edge against the shallows. The image keeps half a screen around
	# the land, inside the grid.
	var corner_low := Vector2(maxf(low.x - step.x / 2.0, 0.0), maxf(origin.y - step.y / 2.0, 0.0))
	var corner_high := Vector2(minf(high.x + step.x / 2.0, IslandData.SIZE), minf(high.y + step.y / 2.0, IslandData.SIZE))
	# Cells from the first screen's middle to pixels from the image's top left corner.
	var to_pixels := func(cell: Vector2) -> Vector2i:
		return Vector2i(((cell - origin) * Vector2(1.0, cos(tilt)) / pixel + Vector2(screen) / 2.0).round())
	_crop = Rect2i(to_pixels.call(corner_low), Vector2i.ZERO).expand(to_pixels.call(corner_high))
	for row: int in rows:
		for col: int in _cols:
			var view := SubViewport.new()
			view.size = screen
			view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var camera := GameCamera.new()
			camera.zoom = ZOOM
			camera.focus = Vector3(origin.x + col * step.x, 0.0, origin.y + row * step.y)
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
	image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("Saved %s, %d×%d" % [OUTPUT, image.get_width(), image.get_height()])
	return true
