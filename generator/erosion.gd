class_name Erosion
## Generator step 1, middle: river erosion. Rain on each cell runs downhill, so the water from all
## the cells above adds up on the way down, and the more water a cell carries the gentler the slope
## it keeps. A valley starts steep and shallow near a ridge, deepens and flattens downhill and joins
## bigger valleys, and sharp ridges stand between them.
## It runs on a grid GRID cells wide and adds the change in height back to the full grid, because
## the full grid is too slow in GDScript. Only high ground erodes, so the lowland stays smooth.

## Width of the grid the erosion runs on. Each of its cells covers SIZE / GRID cells of the island,
## so the narrowest valley is about 2 * SIZE / GRID cells wide. At 128 the valleys showed the grid
## as blocks. At 256 the massifs of #94 came out as smooth, rounded slopes. On seeds 0 to 4, 512
## takes 1.5 to 1.7 s against 1.2 s at 256, since the routing skips the ground erosion leaves alone.
const GRID: int = 512
## Passes over the grid. Each pass routes water over the terrain the last one left, so big valleys
## capture the water of the small ones beside them. 4 passes leave more short parallel valleys,
## and 15 look the same as 8 and take twice as long.
const PASSES: int = 8
## Slope of a valley side that drains only itself, per grid cell and per unit of height before
## erosion. Raising it gives steeper valley sides and raises the ridges, lowering it carves deeper.
## It and CHANNEL_AREA are 0.6 and 8 tuned on a grid of 256, carried over to cells half as wide.
const SLOPE: float = 1.2
## A cell that drains n cells keeps a slope of SLOPE / n ** AREA_POWER. Raising it flattens the big
## valleys against the small ones, so fewer, wider main valleys cut into the mountain. At 0.5 and
## 0.8 the mountains were ribbed with narrow valleys side by side.
const AREA_POWER: float = 1.0
## Cells that drain fewer cells than this keep the same slope as one that drains this many. Raising
## it widens the space between valleys, and at 120 the slopes between them turned into flat facets.
const CHANNEL_AREA: float = 32.0
## Erosion fades in as the height before erosion rises from ERODE_FROM to ERODE_TO, in the units of
## Height.smooth, where the tallest mountain reaches about 1. Lowering them erodes smaller hills too.
const ERODE_FROM: float = 0.3
## Height where erosion reaches full strength. See ERODE_FROM.
const ERODE_TO: float = 0.55
## Share of SLOPE that fully soft rock keeps. Massifs makes one ridge of each massif soft, so it
## wears down to slopes the player can walk. Of 0.2, 0.3 and 0.5, 0.3 cut off the fewest peaks.
const SOFT_SLOPE: float = 0.3

## The eight neighbors, with the distance to each, so diagonal slopes aren't overstated.
const NEIGHBOR_OFFSET: Array[int] = [-GRID - 1, -GRID, -GRID + 1, -1, 1, GRID - 1, GRID, GRID + 1]
const NEIGHBOR_DISTANCE: Array[float] = [1.4142135, 1.0, 1.4142135, 1.0, 1.0, 1.4142135, 1.0, 1.4142135]
## The 3x3 blur kernel's weight for each neighbor, with 4 for the cell itself, out of 16.
const NEIGHBOR_BLUR: Array[float] = [1.0, 2.0, 1.0, 2.0, 2.0, 1.0, 2.0, 1.0]


## Erodes a height from Height.smooth in place. Routing the water takes random choices from rng.
## softness, if given, holds 0 for hard rock and 1 for soft rock per cell, see SOFT_SLOPE.
static func apply(height: PackedFloat32Array, rng: RandomNumberGenerator, softness: PackedFloat32Array = PackedFloat32Array()) -> void:
	var size: int = IslandData.SIZE
	var factor: int = size / GRID
	var grid := PackedFloat32Array()
	grid.resize(GRID * GRID)
	for y: int in size:
		for x: int in size:
			grid[(y / factor) * GRID + x / factor] += height[IslandData.index(x, y)]
	for i: int in grid.size():
		grid[i] /= factor * factor
	var soft := PackedFloat32Array()
	soft.resize(GRID * GRID)
	if not softness.is_empty():
		for y: int in size:
			for x: int in size:
				soft[(y / factor) * GRID + x / factor] += softness[IslandData.index(x, y)] / (factor * factor)
	var change: PackedFloat32Array = _erode(grid, rng, soft)

	for y: int in size:
		# Grid cell centers sit at (g + 0.5) * factor, so the bilinear lookup shifts by half a cell.
		var gy: float = clampf((y + 0.5) / factor - 0.5, 0.0, GRID - 1.001)
		var y0: int = int(gy)
		var fy: float = gy - y0
		for x: int in size:
			var i: int = IslandData.index(x, y)
			if height[i] <= 0.0:
				continue
			var gx: float = clampf((x + 0.5) / factor - 0.5, 0.0, GRID - 1.001)
			var x0: int = int(gx)
			var fx: float = gx - x0
			var g: int = y0 * GRID + x0
			var top: float = lerpf(change[g], change[g + 1], fx)
			var bottom: float = lerpf(change[g + GRID], change[g + GRID + 1], fx)
			# Erosion never takes land below sea level, so the coast stays where it was. The floor is
			# capped at the height before, so land just above the sea isn't raised.
			height[i] = maxf(height[i] + lerpf(top, bottom, fy), minf(height[i], 0.001))


## Returns the change in height that erosion makes to each cell of the grid.
##
## Each pass finds where water flows, then rebuilds every high cell from the lowland up as the
## height of the cell it drains to plus the slope its water allows. That is the shape rivers cut a
## mountain into once they have worked on it long enough. It lowers the valleys and raises some
## ridges, and keeps the mountain's height in proportion to the height before erosion.
static func _erode(grid: PackedFloat32Array, rng: RandomNumberGenerator, soft: PackedFloat32Array) -> PackedFloat32Array:
	var cells: int = grid.size()
	var before: PackedFloat32Array = grid.duplicate()
	var weight := PackedFloat32Array()
	weight.resize(cells)
	for i: int in cells:
		weight[i] = smoothstep(ERODE_FROM, ERODE_TO, before[i])
	# Cells whose water is routed: those erosion reshapes and the ones beside them, since a valley
	# can cut below the untouched ground at its edge and should still get that ground's water.
	var routed := PackedByteArray()
	routed.resize(cells)
	for y: int in range(1, GRID - 1):
		for x: int in range(1, GRID - 1):
			var i: int = y * GRID + x
			if weight[i] > 0.0:
				routed[i] = 1
				for k: int in 8:
					routed[i + NEIGHBOR_OFFSET[k]] = 1
	# The cell each cell drains to, or itself in a pit or on the grid's edge.
	var receiver := PackedInt32Array()
	receiver.resize(cells)
	var distance := PackedFloat32Array()
	distance.resize(cells)
	var water := PackedFloat32Array()
	water.resize(cells)
	# Cells sorted by height, as the height in the high bits and the index in the low 18.
	var order := PackedInt64Array()
	order.resize(cells)
	var drops := PackedFloat32Array()
	drops.resize(8)

	for pass_number: int in PASSES:
		for y: int in GRID:
			for x: int in GRID:
				var i: int = y * GRID + x
				receiver[i] = i
				distance[i] = 1.0
				# The sea floor reaches about -4.3 in the corners, so the offset of 8 keeps the key positive.
				# The scale of 1e9 gives any two float32 heights above 0.01 different keys, so a cell
				# always sorts above the lower cell it drains to.
				order[i] = (int((grid[i] + 8.0) * 1e9) << 18) | i
				# Ground erosion leaves alone keeps its height whatever drains through it, so its water
				# isn't routed unless it borders eroding ground. That skips most of the grid and cut the
				# step's time to about a third.
				if routed[i] == 0 or x == 0 or y == 0 or x == GRID - 1 or y == GRID - 1:
					continue
				# A random downhill neighbor, weighted by slope. Always taking the steepest one lined
				# the valleys up along the grid's 8 directions in parallel stripes.
				var h: float = grid[i]
				var total: float = 0.0
				for k: int in 8:
					drops[k] = maxf((h - grid[i + NEIGHBOR_OFFSET[k]]) / NEIGHBOR_DISTANCE[k], 0.0)
					total += drops[k]
				if total == 0.0:
					continue
				var pick: float = rng.randf() * total
				for k: int in 8:
					pick -= drops[k]
					if drops[k] > 0.0 and pick <= 0.0:
						receiver[i] = i + NEIGHBOR_OFFSET[k]
						distance[i] = NEIGHBOR_DISTANCE[k]
						break
		order.sort()
		water.fill(1.0)
		# From the top down, each cell passes all its water to its receiver.
		for k: int in range(cells - 1, -1, -1):
			var i: int = order[k] & 0x3FFFF
			if receiver[i] != i:
				water[receiver[i]] += water[i]
		# From the bottom up, so each receiver already has its new height. The lowland, pits and the
		# grid's edge keep their height and are where the rebuilt mountain starts from.
		for k: int in cells:
			var i: int = order[k] & 0x3FFFF
			var r: int = receiver[i]
			if r == i or weight[i] == 0.0:
				grid[i] = before[i]
				continue
			var slope: float = SLOPE * lerpf(1.0, SOFT_SLOPE, soft[i]) * before[i] / pow(maxf(water[i], CHANNEL_AREA), AREA_POWER)
			grid[i] = lerpf(before[i], grid[r] + distance[i] * slope, weight[i])

	# One blur of the change. Without it the random routing left a row of small tops along each
	# ridge, 126 to 302 per island on seeds 0 to 9 against 46 to 90 with it.
	var change := PackedFloat32Array()
	change.resize(cells)
	for i: int in cells:
		change[i] = grid[i] - before[i]
	var blurred: PackedFloat32Array = change.duplicate()
	for y: int in range(1, GRID - 1):
		for x: int in range(1, GRID - 1):
			var i: int = y * GRID + x
			if weight[i] == 0.0:
				continue
			var sum: float = change[i] * 4.0
			for k: int in 8:
				sum += change[i + NEIGHBOR_OFFSET[k]] * NEIGHBOR_BLUR[k]
			blurred[i] = sum / 16.0
	return blurred
