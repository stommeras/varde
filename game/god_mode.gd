class_name GodMode
extends CanvasLayer
## Tools for checking an island while tuning, in debug builds only. G turns god mode on and off. In
## god mode the player walks through anything, the whole map shows, every unsurveyed peak shows its
## zone ring, and a panel in the top left corner shows what lies under the player. Keys 1 to 5 set
## the speed, the mouse wheel zooms, and T jumps to the nearest peak not yet surveyed.

## Speed multipliers for keys 1 to 5. ×1 walks at Player.SPEED, which shows how a walk feels. At
## ×16 the player crosses the 1024-cell grid in about 18 s.
const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
## The index in SPEEDS god mode starts at, ×8.
const START_SPEED: int = 3
## Zoom factor per notch of the mouse wheel.
const ZOOM_STEP: float = 1.25
## Closest and furthest zoom, in cells from the top to the bottom of the screen. At 400 most of the
## island fits on screen.
const ZOOM_MIN: float = 10.0
const ZOOM_MAX: float = 400.0
## Compass points for the nearest peak's direction, clockwise from north.
const COMPASS: Array[String] = ["N", "NØ", "Ø", "SØ", "S", "SV", "V", "NV"]

## Set these before adding the node.
var player: Player
var camera: GameCamera
var survey: Survey
var terrain: IslandTerrain
var _island: IslandData
var _speed: int = START_SPEED
var _panel := Label.new()
## A zone ring per peak, so every unsurveyed peak shows however far away it is. Made the first time
## god mode is on for an island.
var _rings: Array[ZoneRing] = []


func _ready() -> void:
	layer = 10
	_panel.position = Vector2(8, 8)
	_panel.add_theme_font_size_override("font_size", 12)
	_panel.add_theme_color_override("font_color", Ramps.RAMPS[Ramps.Terrain.SNOW][3])
	_panel.add_theme_color_override("font_outline_color", Ramps.RAMPS[Ramps.Terrain.ROCK][0])
	_panel.add_theme_constant_override("outline_size", 4)
	_panel.visible = false
	add_child(_panel)


## Starts a new island.
func start(island: IslandData) -> void:
	_island = island
	for ring: ZoneRing in _rings:
		ring.queue_free()
	_rings.clear()
	terrain.show_all(player.god)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or _island == null:
		return
	var wheel := event as InputEventMouseButton
	if player.god and wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = clampf(camera.zoom / ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = clampf(camera.zoom * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		return
	# Raw keys, not input actions, because the editor rewrites project.godot while it's open.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_G:
		_toggle()
	elif not player.god:
		return
	elif key.physical_keycode >= KEY_1 and key.physical_keycode < KEY_1 + SPEEDS.size():
		_speed = key.physical_keycode - KEY_1
		player.god_speed = SPEEDS[_speed]
	elif key.physical_keycode == KEY_T and not player.frozen:
		var peak: int = Survey.peak_in_reach(_island, player.grid_position, survey.surveyed, INF)
		if peak >= 0:
			var cell: int = _island.peaks[peak].cell
			player.grid_position = Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
	else:
		return
	get_viewport().set_input_as_handled()


func _toggle() -> void:
	player.god = not player.god
	player.god_speed = SPEEDS[_speed]
	_panel.visible = player.god
	terrain.show_all(player.god)
	if not player.god:
		camera.zoom = GameCamera.STEPS[camera.step]


func _process(_delta: float) -> void:
	if _island != null:
		_update_rings()
	if _panel.visible:
		_panel.text = info()


func _update_rings() -> void:
	if player.god and _rings.is_empty():
		for peak: Peak in _island.peaks:
			var ring := ZoneRing.new()
			add_child(ring)
			ring.place(_island, peak.cell, Survey.ZONE_RADIUS)
			_rings.append(ring)
	# Scaled with the zoom, so a ring keeps its size on screen and still shows on a peak when the
	# camera zooms far out.
	var size := Vector3.ONE * maxf(camera.zoom / GameCamera.ZOOM, 1.0)
	for i: int in _rings.size():
		_rings[i].scale = size
		_rings[i].fade(1.0 if player.god and survey.surveyed[i] == 0 else 0.0)


## The panel's text for the player's cell.
func info() -> String:
	var at: Vector2 = player.grid_position
	var cell: int = IslandData.index(int(at.x), int(at.y))
	var lines: PackedStringArray = [
		# Cells per second times meters per cell, times 3.6 for km/h.
		tr("GOD_MODE") % [SPEEDS[_speed], Player.SPEED * SPEEDS[_speed] * IslandData.METERS_PER_CELL * 3.6],
		tr("GOD_FPS") % Engine.get_frames_per_second(),
		"%s: %d" % [tr("SEED"), _island.island_seed],
		tr("GOD_CELL") % [int(at.x), int(at.y)],
		tr("GOD_HEIGHT") % IslandData.meters(_island.height[cell]),
		tr("GOD_SLOPE") % [slope(_island, cell), rad_to_deg(atan(Walkability.MAX_SLOPE * Walkability.SUMMIT_UNITS))],
		"%s: %.2f" % [tr("LAYER_MOISTURE"), _island.moisture[cell]],
		"%s: %s" % [tr("LAYER_MATERIAL"), tr("MATERIAL_" + Ramps.Terrain.keys()[_island.material[cell]])],
		tr("GOD_GROUND") % [
			tr("GOD_MAIN_ISLAND") if _island.main_island[cell] == 1 else tr("GOD_ISLET"),
			tr("GOD_BLOCKED") if Walkability.blocked(_island, cell) else tr("GOD_OPEN"),
		],
		tr("ZOOM_CELLS") % camera.zoom,
	]
	var left: int = survey.surveyed.count(0)
	lines.append(tr("GOD_PEAKS") % [survey.surveyed.size() - left, survey.surveyed.size()])
	var peak: int = Survey.peak_in_reach(_island, at, survey.surveyed, INF)
	if peak >= 0:
		var top: Peak = _island.peaks[peak]
		var away := Vector2(top.cell % IslandData.SIZE + 0.5, top.cell / IslandData.SIZE + 0.5) - at
		# angle() counts from east with y south, so a quarter turn more counts from north.
		var point: String = COMPASS[posmod(roundi((away.angle() + PI / 2.0) / (PI / 4.0)), 8)]
		lines.append(tr("GOD_NEAREST") % [peak, distance(away.length()), point,
				IslandData.meters(top.height), IslandData.meters(top.prominence)])
	lines.append(tr("GOD_HELP"))
	return "\n".join(lines)


## The steepest slope at cell in degrees, from the height differences to its four neighbors.
static func slope(island: IslandData, cell: int) -> float:
	var x: int = cell % IslandData.SIZE
	var y: int = cell / IslandData.SIZE
	var h: PackedFloat32Array = island.height
	var last: int = IslandData.SIZE - 1
	# Central differences, half the rise over two cells, in world units per cell.
	var dx: float = h[IslandData.index(mini(x + 1, last), y)] - h[IslandData.index(maxi(x - 1, 0), y)]
	var dy: float = h[IslandData.index(x, mini(y + 1, last))] - h[IslandData.index(x, maxi(y - 1, 0))]
	return rad_to_deg(atan(Vector2(dx, dy).length() / 2.0 * Walkability.SUMMIT_UNITS))


## cells as a distance on the map, in meters under 1 km and in km with a decimal comma above.
static func distance(cells: float) -> String:
	var meters: float = cells * IslandData.METERS_PER_CELL
	if meters < 1000.0:
		return "%d m" % meters
	return ("%.1f km" % (meters / 1000.0)).replace(".", ",")
