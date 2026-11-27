extends "res://tests/test_case.gd"


## On a steep slope, a fallen varde's strewn stones rest on the ground where each one lies, not at
## the height of the stump's foot, which left the downhill ones floating.
func test_strewn_stones_lie_on_a_slope() -> void:
	var island := IslandData.new()
	island.height.resize(IslandData.SIZE * IslandData.SIZE)
	for y: int in range(490, 530):
		for x: int in range(490, 530):
			island.height[IslandData.index(x, y)] = 0.5 + (x - 500) * 0.02
	var varde := OldVarde.new(Trail.Kind.FALLEN, 3)
	varde.place(island, IslandData.index(510, 510))
	var stones: int = 0
	for child: Node in varde.get_children():
		var stone := child as MeshInstance3D
		if stone == null:
			continue
		stones += 1
		var ground: float = Player.height_at(island, Vector2(varde.position.x + stone.position.x, varde.position.z + stone.position.z))
		expect(is_equal_approx(varde.position.y + stone.position.y, ground), "a strewn stone lies %.2f above the ground" % (varde.position.y + stone.position.y - ground))
	expect(stones > 0, "the fallen varde strewed no stones")
	varde.free()
