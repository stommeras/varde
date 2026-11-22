class_name WaysUp
## Part of generator step 5, after the start: makes sure the player can walk from the start up to
## every peak. Erosion leaves a walkable side on most massifs by itself, down the soft ridge Massifs
## gives each one. On seeds 0 to 9, a single step too steep to walk still cut off 2 of 69 peaks.
## This finds the path from a peak's survey zone to the land the start reaches that crosses the
## fewest such steps, and raises the lower cell of each until the step can be walked. It only
## raises cells, and never to the height of the cell above, so no top moves and none appears.
## Carving a whole way up made straight pathways, so this mends single steps and leaves the rest of
## the way to the terrain.

## Share of the steepest walkable slope a mended step gets, so rounding never leaves it too steep.
const FILL: float = 0.95
## Times a peak's path is searched and mended. Each mend can make the next step too steep, so a
## peak may take several. On seeds 0 to 9 the most any peak needed was 45 rounds, which raised 56
## cells by a few world units each. They don't show in the game at zoom 40 or 120.
const ROUNDS: int = 100


## Mends the ways from data.start up to every peak of data, in place. Returns how many cells it
## raised.
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
	for peak: Peak in data.peaks:
		for attempt: int in ROUNDS:
			var steep: PackedInt32Array = _steep_steps(data, peak.cell, reached, cost, came)
			if steep.is_empty():
				break
			for k: int in range(0, steep.size(), 2):
				var low: int = steep[k]
				var high: int = steep[k + 1]
				data.height[low] = data.height[high] - Walkability.MAX_SLOPE * FILL
				# A raised cell may no longer meet the land around it, so the next round has to reach
				# past it to land the start still reaches.
				reached[low] = 0
				raised += 1
	return raised


## The cells reached from start through open edge steps, as 1 in a mask. The player takes corner
## steps too, so this is a part of what Walkability.reachable() finds, and each cell in it can
## really be reached. It skips the corner rules, so it takes about half as long.
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
			if reached[next] == 0 and not Walkability.blocked(data, next) \
					and absf(data.height[next] - data.height[cell]) <= Walkability.MAX_SLOPE:
				reached[next] = 1
				queue.append(next)
	return reached


## The steps too steep to walk on the path from peak's survey zone to a reached cell that has the
## fewest of them, as pairs of the lower and the higher cell. Empty when the path is open. It
## searches by the number of steep steps, spreading through open steps first, so it stops at the
## first reached cell it finds with the least of them. cost and came are scratch arrays the size of
## the grid, and cost is left all -1 again.
static func _steep_steps(data: IslandData, peak: int, reached: PackedByteArray, cost: PackedInt32Array, came: PackedInt32Array) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var reach: int = int(Peak.ZONE_RADIUS)
	var touched := PackedInt32Array()
	var front := PackedInt32Array()
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var cell: int = peak + dy * size + dx
			if dx * dx + dy * dy <= reach * reach and not Walkability.blocked(data, cell):
				cost[cell] = 0
				came[cell] = cell
				front.append(cell)
				touched.append(cell)
	var found: int = -1
	var level: int = 0
	while found < 0 and not front.is_empty():
		var later := PackedInt32Array()
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
				if Walkability.blocked(data, next) or (cost[next] >= 0 and cost[next] <= level):
					continue
				if cost[next] < 0:
					touched.append(next)
				if absf(data.height[next] - data.height[cell]) <= Walkability.MAX_SLOPE:
					cost[next] = level
					came[next] = cell
					front.append(next)
				elif cost[next] < 0 or cost[next] > level + 1:
					cost[next] = level + 1
					came[next] = cell
					later.append(next)
		front = later
		level += 1
	var steep := PackedInt32Array()
	var cell: int = found
	while cell >= 0 and came[cell] != cell:
		var prev: int = came[cell]
		if absf(data.height[cell] - data.height[prev]) > Walkability.MAX_SLOPE:
			var low: int = cell if data.height[cell] < data.height[prev] else prev
			steep.append(low)
			steep.append(prev if low == cell else cell)
		cell = prev
	for t: int in touched:
		cost[t] = -1
	return steep
