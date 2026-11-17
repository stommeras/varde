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
		saved[i] = [data.height[i], data.lake[i]]
		data.height[i] = 0.1
		data.lake[i] = 0
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


func test_input_actions_have_wasd_and_arrows() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down"]:
		expect(InputMap.has_action(action) and InputMap.action_get_events(action).size() == 2,
			"%s lacks its two keys" % action)
