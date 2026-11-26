class_name WaysUp
## Part of generator step 5, after the start: makes sure the player can walk from the start up to
## every peak. Erosion leaves a walkable side on most massifs by itself, down the soft ridge Massifs
## gives each one, but a band of cliff cells can still cut a peak off. This finds the path from a
## peak's top to the land the start reaches that crosses the fewest cliff cells, and raises
## each of them and its lower neighbors until no step around it is too steep. It only raises cells,
## and never to the height of the cell above, so no top moves and none appears.
## Carving a whole way up made straight pathways, so this mends single steps and leaves the rest of
## the way to the terrain.

## Share of the steepest walkable slope a mended step gets, so rounding never leaves it too steep
## and the mended cell off the cliffs.
const FILL: float = 0.95
## Times a peak's path is searched and mended. Each mend can turn the next cell on the path into
## cliff, so a peak may take several. On seeds 0 to 9 WaysUp raised 3 to 725 cells per island.
const ROUNDS: int = 100
## Passes over all the peaks at most. On seed 4 the second pass opened a peak that a mend for a later
## peak had cut off in the first. Raising it only matters if a warning shows up.
const PASSES: int = 4
## Cells from a peak's top that the way must reach. A way into the edge of the 3-cell survey zone
## left the top of seed 3638347899's summit walled in by cliff cells, with one open cell 3 cells
## east of it, so the player could survey but never climb the peak. Raising it lets the way stop
## further from the top.
const TOP_REACH: int = 1
## What _cliffs_on_path returns, as its only element, when no path reaches the start's land.
const NO_PATH: int = -1


## Mends the ways from data.start up to every peak of data, in place. Returns how many cells it
## raised. Warns when a peak has no way at all, or still has a steep step after ROUNDS.
static func open(data: IslandData) -> int:
	if data.start < 0:
		return 0
	var reached: PackedByteArray = _flood(data, data.start)
	var cost := PackedInt32Array()
	cost.resize(data.height.size())
	cost.fill(-1)
	var came := PackedInt32Array()
	came.resize(data.height.size())
	var raised: int = 0
	# A mend for one peak can turn a cell on an earlier peak's way into cliff, or cut off land the
	# start reached, so the peaks are checked again from a new flood until a pass raises nothing.
	for pass_number: int in PASSES:
		var before_pass: int = raised
		for peak: Peak in data.peaks:
			var mended: bool = false
			for attempt: int in ROUNDS:
				var steep: PackedInt32Array = _cliffs_on_path(data, peak.cell, reached, cost, came)
				if steep.is_empty():
					mended = true
					break
				if steep[0] == NO_PATH:
					break
				var before: int = raised
				for cell: int in steep:
					raised += _mend(data, cell, reached)
				if raised == before:
					break
			if not mended:
				push_warning("WaysUp: no way up to the peak at cell %d on island %d" % [peak.cell, data.island_seed])
		if raised == before_pass:
			return raised
		reached = _flood(data, data.start)
	push_warning("WaysUp: the mends still changed after %d passes on island %d" % [PASSES, data.island_seed])
	return raised


## Raises cell and its lower neighbors until no step from cell is steeper than the walk limit, and
## marks the cliffs around them again. Returns how many cells it raised. cell rises to just under
## its highest neighbor's reach, and each neighbor still too far below it rises to just under cell,
## so neither ever reaches the height of the cell above it. It leaves river and lake cells as they
## are, so water doesn't run uphill, and the start and its neighbors, so the start never turns into
## a cliff.
static func _mend(data: IslandData, cell: int, reached: PackedByteArray) -> int:
	var size: int = IslandData.SIZE
	var raised: int = 0
	var around := PackedInt32Array()
	var limits := PackedFloat32Array()
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				around.append(cell + dy * size + dx)
				limits.append(Walkability.MAX_SLOPE * FILL * (1.0 if dx == 0 or dy == 0 else sqrt(2.0)))
	if data.fresh_water[cell] == 0 and not _near_start(data, cell):
		var floor_height: float = data.height[cell]
		for k: int in around.size():
			floor_height = maxf(floor_height, data.height[around[k]] - limits[k])
		if floor_height > data.height[cell]:
			data.height[cell] = floor_height
			raised += 1
	for k: int in around.size():
		var next: int = around[k]
		var low: float = data.height[cell] - limits[k]
		if data.height[next] > 0.0 and data.fresh_water[next] == 0 and data.height[next] < low \
				and not _near_start(data, next):
			data.height[next] = low
			raised += 1
	# A raised cell changes the steps of its neighbors too, two cells out from cell.
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var near: int = cell + dy * size + dx
			data.cliff[near] = 1 if Walkability.is_cliff(data, near) else 0
			if data.cliff[near] == 1:
				reached[near] = 0
	return raised


## The cells the start reaches through edge steps, as 1 in a mask. The player takes corner steps
## too, so this is a part of what Walkability.reachable() finds, and each cell in it can really be
## reached. It skips the corner rules, so it takes about half as long.
static func _flood(data: IslandData, start: int) -> PackedByteArray:
	var size: int = IslandData.SIZE
	var reached := PackedByteArray()
	reached.resize(data.height.size())
	reached[start] = 1
	var queue := PackedInt32Array([start])
	var head: int = 0
	while head < queue.size():
		var cell: int = queue[head]
		head += 1
		for next: int in [cell - 1, cell + 1, cell - size, cell + size]:
			if reached[next] == 0 and not Walkability.blocked(data, next):
				reached[next] = 1
				queue.append(next)
	return reached


## The cliff cells on the edge-step path from within TOP_REACH of peak's top to a reached cell that crosses the
## fewest of them. Empty when the path is open, and [NO_PATH] when no path reaches the start's land.
## The path never crosses the sea, a lake, or a cliff on or next to a river, since mending it would
## raise the river and make the water run uphill. It searches by the number of cliff cells,
## spreading through open cells first, so it stops at the first reached cell it finds with the least
## of them. cost and came are scratch arrays the size of the grid, and cost is left all -1 again.
static func _cliffs_on_path(data: IslandData, peak: int, reached: PackedByteArray, cost: PackedInt32Array, came: PackedInt32Array) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var reach: int = TOP_REACH
	var touched := PackedInt32Array()
	# The cells at the level being searched, and those one cliff cell more.
	var front := PackedInt32Array()
	var later := PackedInt32Array()
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: int = peak + dy * size + dx
			if dx * dx + dy * dy <= reach * reach and _passable(data, cell):
				cost[cell] = data.cliff[cell]
				came[cell] = cell
				(later if data.cliff[cell] == 1 else front).append(cell)
				touched.append(cell)
	var found: int = -1
	var level: int = 0
	while found < 0 and not (front.is_empty() and later.is_empty()):
		var head: int = 0
		while head < front.size():
			var cell: int = front[head]
			head += 1
			if cost[cell] != level:
				continue
			if reached[cell] == 1:
				found = cell
				break
			for next: int in [cell - 1, cell + 1, cell - size, cell + size]:
				if not _passable(data, next):
					continue
				var through: int = level + data.cliff[next]
				if cost[next] >= 0 and cost[next] <= through:
					continue
				if cost[next] < 0:
					touched.append(next)
				cost[next] = through
				came[next] = cell
				(later if data.cliff[next] == 1 else front).append(next)
		front = later
		later = PackedInt32Array()
		level += 1
	var steep := PackedInt32Array()
	var cell: int = found
	while cell >= 0:
		if data.cliff[cell] == 1:
			steep.append(cell)
		if came[cell] == cell:
			break
		cell = came[cell]
	for t: int in touched:
		cost[t] = -1
	return steep if found >= 0 else PackedInt32Array([NO_PATH])


## True when the way up may cross cell: on land, off lakes, and off a cliff that _mend() can't open
## because it is a river or stands next to a river or the sea, or is one of the start's neighbors.
## None of those can be raised, so the step to it may stay too steep.
static func _passable(data: IslandData, cell: int) -> bool:
	if data.height[cell] <= 0.0 or data.lake[cell] == 1:
		return false
	if data.cliff[cell] == 0:
		return true
	if _near_start(data, cell):
		return false
	var size: int = IslandData.SIZE
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var near: int = cell + dy * size + dx
			if data.fresh_water[near] == 1 or data.height[near] <= 0.0:
				return false
	return true


## True when cell is the start or one of its eight neighbors. Raising one of them could make a step
## from the start too steep and turn it into a cliff the player can't stand on.
static func _near_start(data: IslandData, cell: int) -> bool:
	var size: int = IslandData.SIZE
	return absi(cell % size - data.start % size) <= 1 and absi(cell / size - data.start / size) <= 1
