class_name Peaks
extends RefCounted
## Part of generator step 5: the peaks of the main island, with their prominence.
## The cells are visited from the highest down, and each joins the land above it. Two separate
## groups meeting at a cell means that cell is the saddle between them, and the lower group's
## peak rises from it by the difference in height. This is the standard union-find way to get
## prominence, and it needs one sort and one pass over the main island.

## The least prominence a peak needs, as a share of the summit's height. Lowering it adds small
## knolls, raising it keeps only the big mountains. SPEC.md aims for 5 to 10 peaks per island. The
## massifs stand in ranges with saddles about half the summit's height, so 0.35 kept only 2 to 4
## of their tops.
const MIN_PROMINENCE: float = 0.25
## Heights are packed into the sort key as whole numbers of this many steps per height unit. Two
## cells less than 2^-30 apart tie in the key and sort by cell index, which shifts a saddle by far
## less than MIN_PROMINENCE.
const HEIGHT_STEPS: float = 1073741824.0
## Bits the cell index takes in the sort key, enough for IslandData.SIZE squared cells. The height
## goes above them, so the sort puts the highest cell last.
const INDEX_BITS: int = 20

## The eight neighbors as column and row offsets. Land never reaches the grid's edge, so a land
## cell's neighbors are always on the grid.
const NEIGHBOR_X: Array[int] = [-1, 0, 1, -1, 1, -1, 0, 1]
const NEIGHBOR_Y: Array[int] = [-1, -1, -1, 0, 0, 1, 1, 1]


## Every peak of the main island with at least MIN_PROMINENCE times the summit's height of
## prominence, highest first. Neighbors connect through edges and corners, as the player's steps do.
static func generate(height: PackedFloat32Array, main_island: PackedByteArray) -> Array[Peak]:
	var size: int = IslandData.SIZE
	var keys := PackedInt64Array()
	for i: int in height.size():
		if main_island[i] == 1:
			keys.append((int(height[i] * HEIGHT_STEPS) << INDEX_BITS) | i)
	var peaks: Array[Peak] = []
	if keys.is_empty():
		return peaks
	# Packed keys sort natively, which is far faster than a Callable sort over the cells.
	keys.sort()
	var cell_mask: int = (1 << INDEX_BITS) - 1
	var min_prominence: float = MIN_PROMINENCE * height[keys[-1] & cell_mask]

	# -1 is a cell not visited yet. A visited cell points at another cell of its group, and a
	# group's root points at itself.
	var parent := PackedInt32Array()
	parent.resize(height.size())
	parent.fill(-1)
	# The highest cell of each group, stored at the group's root.
	var top := PackedInt32Array()
	top.resize(height.size())

	for k: int in range(keys.size() - 1, -1, -1):
		var cell: int = keys[k] & cell_mask
		parent[cell] = cell
		top[cell] = cell
		var x: int = cell % size
		var y: int = cell / size
		for n: int in 8:
			var next: int = (y + NEIGHBOR_Y[n]) * size + x + NEIGHBOR_X[n]
			if parent[next] == -1:
				continue
			var a: int = _find(parent, cell)
			var b: int = _find(parent, next)
			if a == b:
				continue
			# The group with the higher peak survives. On a tie the lower cell index does, so the
			# result doesn't depend on the order of the neighbors.
			var peak_a: int = top[a]
			var peak_b: int = top[b]
			var a_wins: bool = height[peak_a] > height[peak_b] or (height[peak_a] == height[peak_b] and peak_a < peak_b)
			var winner: int = a if a_wins else b
			var loser: int = b if a_wins else a
			var prominence: float = height[top[loser]] - height[cell]
			if prominence >= min_prominence:
				peaks.append(Peak.new(top[loser], height[top[loser]], prominence))
			parent[loser] = winner
	# One group is left, topped by the summit, which rises from the sea.
	var summit: int = keys[-1] & cell_mask
	peaks.append(Peak.new(summit, height[summit], height[summit]))
	peaks.sort_custom(func(a: Peak, b: Peak) -> bool: return a.height > b.height or (a.height == b.height and a.cell < b.cell))
	return peaks


## The root of cell's group. Halves the path as it climbs, so later lookups are short.
static func _find(parent: PackedInt32Array, cell: int) -> int:
	while parent[cell] != cell:
		parent[cell] = parent[parent[cell]]
		cell = parent[cell]
	return cell
