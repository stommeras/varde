extends "res://tests/test_case.gd"


## The feet must meet the terrain mesh, which runs straight between the cell centers.
func test_height_follows_the_mesh_triangles() -> void:
	var data: IslandData = island(0)
	var start: int = data.start
	var x: int = start % IslandData.SIZE
	var y: int = start / IslandData.SIZE
	var center := Vector2(x + 0.5, y + 0.5)
	var h: float = data.height[start] * IslandTerrain.SUMMIT_HEIGHT
	expect(is_equal_approx(Player.height_at(data, center), h), "the height at a cell's center is not the cell's")
	# Halfway along the north-west to south-east diagonal lies on both triangles.
	var se: float = maxf(data.height[start + IslandData.SIZE + 1], 0.0) * IslandTerrain.SUMMIT_HEIGHT
	var middle: float = Player.height_at(data, center + Vector2(0.5, 0.5))
	expect(is_equal_approx(middle, (h + se) / 2.0), "the middle of a square is off its diagonal")


func test_moves_slide_along_walls() -> void:
	var data: IslandData = island(0)
	var size: int = IslandData.SIZE
	var a: int = data.start
	var east: int = a + 1
	var south: int = a + size
	var corner: int = a + size + 1
	var saved: Dictionary[int, Array] = {}
	for i: int in [a, east, south, corner]:
		saved[i] = [data.height[i], data.lake[i], data.cliff[i]]
		data.height[i] = 0.1
		data.lake[i] = 0
		data.cliff[i] = 0
	var from := Vector2(a % size + 0.9, a / size + 0.9)
	var motion := Vector2(0.2, 0.2)
	expect(Player.move(data, from, motion) == from + motion, "an open diagonal move is refused")
	data.lake[east] = 1
	expect(Player.move(data, from, motion) == from + Vector2(0.0, 0.2), "a move into a wall to the east doesn't slide south")
	data.lake[east] = 0
	data.lake[south] = 1
	expect(Player.move(data, from, motion) == from + Vector2(0.2, 0.0), "a move into a wall to the south doesn't slide east")
	data.lake[east] = 1
	expect(Player.move(data, from, motion) == from, "a move into a corner of walls goes through")
	expect(Player.move(data, from, Vector2(-0.2, -0.2)) == from + Vector2(-0.2, -0.2), "a move inside the cell is refused")
	for i: int in saved:
		data.height[i] = saved[i][0]
		data.lake[i] = saved[i][1]
		data.cliff[i] = saved[i][2]


func test_input_actions_have_wasd_and_arrows() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		expect(InputMap.has_action(action) and InputMap.action_get_events(action).size() == 2,
			"%s lacks its two keys" % action)


func test_faces_the_nearest_of_eight_directions() -> void:
	var compass: Array[Vector2] = [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT,
		Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]
	for i: int in compass.size():
		expect(Player.facing(compass[i].normalized()) == i, "direction %s faces %d, not %d" % [compass[i], Player.facing(compass[i]), i])


## The fade opens only while terrain stands between the camera and the figure.
func test_hidden_finds_terrain_toward_the_camera() -> void:
	var data: IslandData = island(0)
	var size: int = IslandData.SIZE
	var x: int = data.start % size
	var y: int = data.start / size
	var h: float = data.height[data.start]
	# Flattens a strip south of the start, the way a camera tilted 45° looks back.
	var saved: Dictionary[int, float] = {}
	for row: int in range(y - 1, y + 120):
		for column: int in range(x - 1, x + 2):
			var i: int = IslandData.index(column, row)
			saved[i] = data.height[i]
			data.height[i] = h
	var feet := Vector3(x + 0.5, Player.height_at(data, Vector2(x + 0.5, y + 0.5)), y + 0.5)
	var toward := Vector3(0.0, 1.0, 1.0).normalized()
	var head: Vector3 = feet + Vector3.UP
	expect(not Player.hidden(data, head, toward), "flat ground hides the figure")
	# The line from the head rises a unit per cell south, so a wall 3 cells south must stand more
	# than 4 units above the feet to hide it.
	data.height[IslandData.index(x, y + 3)] = h + 8.0 / IslandTerrain.SUMMIT_HEIGHT
	expect(Player.hidden(data, head, toward), "a wall south of the figure doesn't hide it")
	var knowledge := Knowledge.new()
	expect(not Player.hidden(data, head, toward, knowledge), "an unknown wall hides the figure, though the fog draws behind it")
	knowledge.mark(IslandData.index(x, y + 3), Knowledge.Level.SEEN)
	expect(Player.hidden(data, head, toward, knowledge), "a seen wall south of the figure doesn't hide it")
	for i: int in saved:
		data.height[i] = saved[i]


## Up walks away from the camera and right walks to the screen's right at all four headings.
func test_walking_follows_the_camera() -> void:
	var camera := GameCamera.new()
	for quarters: int in 4:
		camera.heading = quarters * PI / 2.0
		# The rotation place() gives it. place() itself snaps to the window's pixels, which tests lack.
		camera.rotation = Vector3(deg_to_rad(GameCamera.TILT_DEGREES) - PI / 2.0, camera.heading, 0.0)
		var away := Vector2(-camera.basis.z.x, -camera.basis.z.z).normalized()
		var right := Vector2(camera.basis.x.x, camera.basis.x.z).normalized()
		expect(Player.walk_direction(Vector2.UP, camera.heading).is_equal_approx(away), "up doesn't walk away from the camera at %d quarters" % quarters)
		expect(Player.walk_direction(Vector2.RIGHT, camera.heading).is_equal_approx(right), "right doesn't walk to the screen's right at %d quarters" % quarters)
	camera.free()


## A turn eases to its quarter and stops there exactly, so the camera rests on the same pixel grid.
func test_camera_turns_to_whole_quarters() -> void:
	var camera := GameCamera.new()
	camera.turn(1)
	camera._process(GameCamera.TURN_SECONDS / 2.0)
	expect(camera.heading > 0.0 and camera.heading < PI / 2.0, "the turn doesn't pass between the quarters")
	camera.turn(-2)
	for i: int in 10:
		camera._process(GameCamera.TURN_SECONDS / 4.0)
	expect(camera.heading == -PI / 2.0, "the turn stops at %f, not on its quarter" % camera.heading)
	camera.free()


## Q and E turn the camera, so surveying moved from E to F.
func test_turning_and_surveying_have_their_own_keys() -> void:
	var keys: Dictionary[String, Key] = {"turn_left": KEY_Q, "turn_right": KEY_E, "survey": KEY_F}
	for action: String in keys:
		var events: Array[InputEvent] = InputMap.action_get_events(action) if InputMap.has_action(action) else []
		expect(events.size() == 1 and (events[0] as InputEventKey).physical_keycode == keys[action], "%s isn't on its key" % action)
