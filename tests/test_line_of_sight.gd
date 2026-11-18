extends "res://tests/test_case.gd"

const CENTER: int = 512


## A flat island of land at height, with every array the line of sight reads.
static func _flat(height: float) -> IslandData:
	var island := IslandData.new()
	island.height.resize(IslandData.SIZE * IslandData.SIZE)
	island.height.fill(height)
	return island


func test_flat_ground_shows_the_full_radius() -> void:
	var island := _flat(0.0)
	var cell: int = IslandData.index(CENTER, CENTER)
	var seen := {}
	for index: int in LineOfSight.visible_cells(island, cell):
		seen[index] = true
	var reach: int = int(LineOfSight.SEA_RADIUS) - 1
	var missing: int = 0
	for y: int in range(-reach, reach + 1):
		for x: int in range(-reach, reach + 1):
			if x * x + y * y <= reach * reach and not seen.has(IslandData.index(CENTER + x, CENTER + y)):
				missing += 1
	expect(missing == 0, "%d cells inside the radius are unseen on flat ground" % missing)
	expect(not seen.has(IslandData.index(CENTER + int(LineOfSight.SEA_RADIUS) + 2, CENTER)), "a cell past the radius is seen")


func test_a_wall_hides_what_lies_behind_it() -> void:
	var island := _flat(0.0)
	# A wall 0.3 high, 30 world units, running north to south 5 cells east of the player.
	for y: int in IslandData.SIZE:
		island.height[IslandData.index(CENTER + 5, y)] = 0.3
	var seen := {}
	for index: int in LineOfSight.visible_cells(island, IslandData.index(CENTER, CENTER)):
		seen[index] = true
	expect(seen.has(IslandData.index(CENTER + 5, CENTER)), "the wall itself is unseen")
	expect(not seen.has(IslandData.index(CENTER + 10, CENTER)), "a cell behind the wall is seen")
	expect(seen.has(IslandData.index(CENTER - 10, CENTER)), "a cell on the open side is unseen")


func test_the_radius_grows_with_height() -> void:
	expect(LineOfSight.radius(0.0) == LineOfSight.SEA_RADIUS, "the radius at sea level is %f" % LineOfSight.radius(0.0))
	expect(LineOfSight.radius(1.0) == LineOfSight.SUMMIT_RADIUS, "the radius at the summit is %f" % LineOfSight.radius(1.0))


func test_the_same_position_sees_the_same_cells() -> void:
	var island := island(0)
	var first: PackedInt32Array = LineOfSight.visible_cells(island, island.start)
	var second: PackedInt32Array = LineOfSight.visible_cells(island, island.start)
	expect(first == second, "two casts from the start saw different cells")


func test_mark_marks_sea_cells_seen() -> void:
	var island := _flat(-0.1)
	var knowledge := Knowledge.new()
	LineOfSight.mark(island, knowledge, IslandData.index(CENTER, CENTER))
	expect(knowledge.levels[IslandData.index(CENTER + 20, CENTER)] == Knowledge.Level.SEEN, "a sea cell in reach is not seen")
