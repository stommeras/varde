extends SceneTree
## Renders the game icon into ICON_PATH: the varde on the true summit of the Backdrop.SEED_TEXT
## island, seen from the west over the snowy ridge, with grass, beach and sea behind it. Godot uses
## it as the window icon, in the editor's project list and as the web build's favicon. Render it again
## after a change to the generator, the varde or the look. It needs a window, since headless Godot
## draws nothing:
##     godot -s game/render_icon.gd

const ICON_PATH: String = "res://icon.png"
## Pixels across the render. The game draws at 960×540 and scales up by whole steps, so the icon is
## drawn small and scaled up by nearest neighbor to keep its pixels as hard as the game's. Raising it
## gives a finer varde with more dither, lowering it a blockier one.
const RENDER_SIZE: int = 64
const ICON_SIZE: int = 256
## Quarter turns counterclockwise from north, as GameCamera counts them. 3 faces east, where the
## slopes below the summit of seed "varde" run down through grass to a beach and the sea. The other
## headings showed only rock, snow or open sea behind the varde.
const QUARTERS: int = 3
## Degrees from looking straight down. Near the horizon, rays past the varde reach far down the slope,
## so the top of the icon shows the sea while the bottom still shows the ridge. At 82° the ridge
## filled the frame, and at 70° the background was all rock.
const TILT: float = 76.0
## World units of the view from top to bottom. The varde stands about 1.3 units tall. Raising it shows
## more of the ridge and sea and a smaller varde. At 2.5 the deep sea dropped out of the top, and at 4
## the varde got lost on the sand at 16×16.
const VIEW_HEIGHT: float = 3.0
## World units above the varde's foot that the frame centers on. Raising it moves the varde down and
## shows more sea, lowering it shows more of the snowy ridge.
const FOCUS_HEIGHT: float = 0.6
## Degrees along the sun's path, as Sun.set_angle() takes them. Late afternoon, low in the west, so
## the side of the varde facing the camera is lit. At the game's 120° that side fell half in shade.
const SUN_ANGLE: float = 150.0
## Frames to wait before reading the view, so the knowledge texture and the shadows are in place.
const SETTLE_FRAMES: int = 10

var _view := SubViewport.new()
var _camera := GameCamera.new()
var _frames: int = 0


func _initialize() -> void:
	RenderingServer.set_default_clear_color(Ramps.RAMPS[Ramps.Terrain.WATER][0])
	var island: IslandData = IslandGenerator.generate(IslandLoader.seed_from(Backdrop.SEED_TEXT))
	var cell: int = island.peaks[0].cell
	var top := Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
	var foot := Vector3(top.x, Player.height_at(island, top), top.y)

	_view.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var terrain := IslandTerrain.new()
	_view.add_child(terrain)
	terrain.show_island(TerrainMesh.build(island), island)
	terrain.knowledge.mark_all(Knowledge.Level.SURVEYED, Knowledge.LONG_AGO)
	var sun := Sun.new()
	sun.set_angle(SUN_ANGLE)
	_view.add_child(sun)
	# The same stones the player stacks on this summit, since Survey seeds the varde with its cell.
	var varde := Varde.new(cell)
	varde.position = foot
	varde.build(1.0)
	_view.add_child(varde)
	_camera.tilt_degrees = TILT
	_camera.heading = QUARTERS * PI / 2.0
	# GameCamera's zoom counts flat ground, which shows cos(tilt) as tall on screen.
	_camera.zoom = VIEW_HEIGHT / cos(deg_to_rad(TILT))
	_camera.focus = foot + Vector3(0.0, FOCUS_HEIGHT, 0.0)
	_view.add_child(_camera)


func _process(_delta: float) -> bool:
	_frames += 1
	# Placed here, since a camera added in _initialize has no window to read its pixel size from yet.
	if _frames == 1:
		_camera.place()
	if _frames < SETTLE_FRAMES:
		return false
	var image: Image = _view.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_NEAREST)
	var error: Error = image.save_png(ProjectSettings.globalize_path(ICON_PATH))
	if error != OK:
		push_error("Couldn't save %s: %s" % [ICON_PATH, error_string(error)])
		return true
	print("Saved %s, %d×%d" % [ICON_PATH, image.get_width(), image.get_height()])
	return true
