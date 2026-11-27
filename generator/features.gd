class_name Features
## Generator step 5, the nameable things the note writer refers to: lakes, river forks, coves and
## the largest forest of the main island. Runs on the final heights and materials, after WaysUp.

## Fewest cells a lake needs to be named, one hectare at 10 m a cell. Rivers leave a hundred or more
## filled pits of a few cells on each island, which read as puddles, not lakes. Raising it names only
## the big lakes, 3 to 8 per island on seeds 0 to 4 at 100.
const MIN_LAKE_CELLS: int = 100

## Cells per side of the coarse grid that coves are found on. The closing below costs
## (2 * COVE_RADIUS + 1) steps per cell, which on the full grid takes seconds in GDScript.
const COVE_BLOCK: int = 4
## Coarse cells the closing reaches. Sea that land wraps round with a mouth narrower than about
## 2 * COVE_RADIUS + 1 coarse cells, 36 cells at 4, fills in and counts as a cove. Raising it names
## wider bays as coves too.
const COVE_RADIUS: int = 8
## Fewest coarse cells a cove needs. At 1 the closing names every nook of the coast, a few cells of
## sea between two rocks.
const MIN_COVE_BLOCKS: int = 16


## Finds the features of data and stores them in data.lakes, data.river_forks, data.coves and
## data.forest.
static func find(data: IslandData) -> void:
	data.lakes = areas(data.lake, IslandData.SIZE).filter(func(lake: PackedInt32Array) -> bool:
		return lake.size() >= MIN_LAKE_CELLS)
	# A river ends on land only where it runs into an earlier one, so that last cell is the fork.
	data.river_forks = PackedInt32Array()
	for river: PackedInt32Array in data.rivers:
		if data.height[river[-1]] > 0.0:
			data.river_forks.append(river[-1])
	data.coves = _coves(data.main_island)
	var forest := PackedByteArray()
	forest.resize(data.material.size())
	for i: int in forest.size():
		forest[i] = 1 if data.material[i] == Ramps.Terrain.FOREST and data.main_island[i] == 1 else 0
	var forests: Array[PackedInt32Array] = areas(forest, IslandData.SIZE)
	data.forest = forests[0] if not forests.is_empty() else PackedInt32Array()


## The sea cell at the head of each cove of the main island, farthest in from the open sea, largest cove first. A cove is
## sea that a morphological closing of the main island fills: a dilation by COVE_RADIUS then an
## erosion by the same, on a grid of COVE_BLOCK cells to a side.
static func _coves(main_island: PackedByteArray) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var width: int = size / COVE_BLOCK
	var land := PackedByteArray()
	land.resize(width * width)
	for i: int in main_island.size():
		if main_island[i] == 1:
			land[(i / size / COVE_BLOCK) * width + (i % size) / COVE_BLOCK] += 1
	# A block is land when at least half its cells are.
	var half: int = COVE_BLOCK * COVE_BLOCK / 2
	for b: int in land.size():
		land[b] = 1 if land[b] >= half else 0
	var closed: PackedByteArray = _spread(_spread(land, width, 1), width, 0)
	var sea := PackedByteArray()
	sea.resize(land.size())
	for b: int in land.size():
		sea[b] = 1 if closed[b] == 1 and land[b] == 0 else 0
	var coves := PackedInt32Array()
	for blocks: PackedInt32Array in areas(sea, width):
		if blocks.size() < MIN_COVE_BLOCKS:
			continue
		# A breadth-first walk in from the blocks beside the open sea, which the closing left as sea.
		# The block it reaches last is the cove's head. The middle of the blocks lay near the mouth
		# of a wide bay, since the closing fills a square out past the mouth too.
		var reached: Dictionary[int, bool] = {}
		var queue := PackedInt32Array()
		for b: int in blocks:
			for n: int in [b - 1, b + 1, b - width, b + width]:
				if n >= 0 and n < sea.size() and land[n] == 0 and closed[n] == 0:
					reached[b] = true
					queue.append(b)
					break
		if queue.is_empty():
			queue.append(blocks[0])
		var head: int = 0
		while head < queue.size():
			var b: int = queue[head]
			head += 1
			for n: int in [b - 1, b + 1, b - width, b + width]:
				if n >= 0 and n < sea.size() and sea[n] == 1 and not reached.has(n):
					reached[n] = true
					queue.append(n)
		var inner: int = queue[-1]
		var middle: Vector2 = Vector2(inner % width + 0.5, inner / width + 0.5) * COVE_BLOCK
		var nearest: int = -1
		var nearest_distance: float = INF
		for k: int in COVE_BLOCK * COVE_BLOCK:
			var i: int = IslandData.index((inner % width) * COVE_BLOCK + k % COVE_BLOCK, (inner / width) * COVE_BLOCK + k / COVE_BLOCK)
			var distance: float = IslandData.center(i).distance_squared_to(middle)
			if main_island[i] == 0 and distance < nearest_distance:
				nearest = i
				nearest_distance = distance
		coves.append(nearest)
	return coves


## A copy of grid, width columns square, where every cell within radius COVE_RADIUS of a cell
## holding value, in a square, holds value too. With value 1 it dilates the 1s, with 0 it erodes them.
static func _spread(grid: PackedByteArray, width: int, value: int) -> PackedByteArray:
	var result: PackedByteArray = grid.duplicate()
	# A square spreads as a run along each row, then a run along each column of that.
	for step: int in [1, width]:
		var source: PackedByteArray = result.duplicate()
		for i: int in source.size():
			var along: int = i % width if step == 1 else i / width
			for d: int in range(maxi(-COVE_RADIUS, -along), mini(COVE_RADIUS, width - 1 - along) + 1):
				if source[i + d * step] == value:
					result[i] = value
					break
	return result


## The 4-connected areas of the cells where mask is 1, on a square grid of width columns, largest
## first. Two areas of the same size keep the order of their first cell, so the result is the same
## every run.
static func areas(mask: PackedByteArray, width: int) -> Array[PackedInt32Array]:
	var cells: int = mask.size()
	var visited := PackedByteArray()
	visited.resize(cells)
	var found: Array[PackedInt32Array] = []
	for start: int in cells:
		if mask[start] == 0 or visited[start] == 1:
			continue
		visited[start] = 1
		var area := PackedInt32Array([start])
		var head: int = 0
		while head < area.size():
			var i: int = area[head]
			head += 1
			var x: int = i % width
			for next: int in [i - 1 if x > 0 else -1, i + 1 if x < width - 1 else -1, i - width, i + width]:
				if next >= 0 and next < cells and mask[next] == 1 and visited[next] == 0:
					visited[next] = 1
					area.append(next)
		found.append(area)
	# sort_custom isn't stable, so equal sizes fall back to the first cell.
	found.sort_custom(func(a: PackedInt32Array, b: PackedInt32Array) -> bool:
		return a.size() > b.size() if a.size() != b.size() else a[0] < b[0])
	return found
