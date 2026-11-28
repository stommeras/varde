class_name Contenders
## Generator step 6, first half: picks the contender peaks and rescales them into a narrow band under
## the summit, so from below the player can't tell which one is highest. The other peaks go under the
## band, and the land between the peaks and the hills keeps its height.
##
## Each peak's massif is the land above its key saddle around its top. Its heights map as
## saddle + (h - saddle) * k, so every cell in it keeps its order against its neighbors: rivers still
## run downhill, lakes stay flat, and the edge of the massif still meets the saddle. Massifs nest: a
## lower peak's massif lies inside a higher one's or apart from it, never across its edge. So each
## cell takes the map of the innermost massif it lies in, composed with the maps of the massifs
## around that one.

## Fewest and most contenders, the summit included. More contenders mean more tops to climb and
## compare before the player knows which one is highest.
const MIN_COUNT: int = 3
const MAX_COUNT: int = 5
## The band's depth under the summit, as a share of the summit's height, drawn per island. Raising
## it spreads the contenders out so a careful player can rank them by eye, and lowering it makes them
## look the same height.
const MIN_BAND: float = 0.10
const MAX_BAND: float = 0.15
## How far under the summit the highest contender may stand at most, so the summit stays the highest
## peak by a clear step and survives the WaysUp mends. 0.02 is 2 world units, about 2 pixels at zoom
## 40, too little to read from below.
const SUMMIT_MARGIN: float = 0.02
## How far under the band the other peaks stand at most, as a share of the summit's height. Raising
## it sets the contenders further apart from the rest.
const BAND_GAP: float = 0.03
## Prominence a peak keeps over Peaks.MIN_PROMINENCE, as a share of the summit's height, so the
## WaysUp mends, which raise cells near the saddle, don't drop it out of the peaks. Raising it skips
## more of the peaks with high saddles as contenders and keeps more of the others in the band.
const PROMINENCE_MARGIN: float = 0.03


## Picks the contenders, the summit first, rescales the peaks in data.height and returns the
## contenders' top cells. Needs data.peaks, highest first. The caller redoes everything that reads the
## heights.
static func rescale(data: IslandData, rng: RandomNumberGenerator) -> PackedInt32Array:
	var contenders := PackedInt32Array()
	if data.peaks.is_empty():
		return contenders
	var peaks: Array[Peak] = data.peaks
	var summit: float = peaks[0].height
	contenders.append(peaks[0].cell)
	var count: int = rng.randi_range(MIN_COUNT, MAX_COUNT)
	var floor_height: float = summit * (1.0 - rng.randf_range(MIN_BAND, MAX_BAND))
	var ceiling: float = summit * (1.0 - SUMMIT_MARGIN)
	var min_prominence: float = (Peaks.MIN_PROMINENCE + PROMINENCE_MARGIN) * summit
	# The other peaks squeeze linearly from the lowest a peak may stand up to under the band, so they
	# keep their order and none falls under Peaks.MIN_HEIGHT.
	var low: float = Peaks.MIN_HEIGHT * summit
	var cap: float = floor_height - BAND_GAP * summit
	var squash: float = -1.0

	# The index in peaks of the innermost massif each cell lies in, or -1 outside them all. The
	# summit has no massif of its own. Filled highest first, so a lower massif inside a higher one
	# takes its cells over.
	var owner := PackedInt32Array()
	owner.resize(data.height.size())
	owner.fill(-1)
	# The innermost massif around each peak's top, or -1.
	var parent := PackedInt32Array([-1])
	for p: int in range(1, peaks.size()):
		parent.append(owner[peaks[p].cell])
		for cell: int in _massif(data, peaks[p].cell, peaks[p].height - peaks[p].prominence):
			owner[cell] = p

	# A peak whose saddle stands so high that it can't go under the band and stay a peak is stuck.
	# Stuck peaks become contenders first, or they would stand in the band beside the contenders.
	var order: Array[int] = []
	var stuck: int = 0
	for p: int in range(1, peaks.size()):
		if peaks[p].height - peaks[p].prominence + min_prominence > cap:
			order.insert(stuck, p)
			stuck += 1
		else:
			order.append(p)
	count = mini(MAX_COUNT, maxi(count, stuck + 1))
	# 1 on a contender and on every peak around or inside its massif. A peak that shares a massif
	# with a contender is its shoulder, or the massif it stands on, so two contenders never share one.
	var near := PackedByteArray()
	near.resize(peaks.size())
	var contender := PackedByteArray()
	contender.resize(peaks.size())
	for p: int in order:
		if contenders.size() == count:
			break
		if near[p] == 1:
			continue
		contender[p] = 1
		contenders.append(peaks[p].cell)
		var up: int = p
		while up != -1:
			near[up] = 1
			up = parent[up]
		# Peaks inside p's massif are lower, so they come after it.
		for q: int in range(p + 1, peaks.size()):
			up = parent[q]
			while up != -1 and up != p:
				up = parent[up]
			if up == p:
				near[q] = 1

	# Per peak, the map from the first heights to the final ones on the cells it owns, as
	# h * scales[p] + offsets[p]. Highest first, so the massifs around a peak have their maps before
	# it.
	var scales := PackedFloat32Array([1.0])
	var offsets := PackedFloat32Array([0.0])
	for p: int in range(1, peaks.size()):
		var peak: Peak = peaks[p]
		var a: float = 1.0 if parent[p] == -1 else scales[parent[p]]
		var b: float = 0.0 if parent[p] == -1 else offsets[parent[p]]
		var saddle: float = peak.height - peak.prominence
		# Lowered too far, a top loses the prominence that makes it a peak.
		var lowest: float = a * saddle + b + min_prominence
		var target: float
		if contender[p] == 1:
			target = rng.randf_range(maxf(floor_height, lowest), maxf(ceiling, lowest))
		else:
			if squash < 0.0:
				squash = minf(1.0, (cap - low) / (peak.height - low))
			target = clampf(maxf(low + (peak.height - low) * squash, lowest), low, ceiling)
		# Undo the surrounding maps to find the top's height before them, then pick k to reach it.
		var k: float = ((target - b) / a - saddle) / (peak.height - saddle)
		scales.append(a * k)
		offsets.append(a * saddle * (1.0 - k) + b)

	for i: int in owner.size():
		if owner[i] != -1:
			data.height[i] = data.height[i] * scales[owner[i]] + offsets[owner[i]]
	return contenders


## Every main island cell above saddle that connects to top through such cells, edges and corners
## alike, as the player's steps do.
static func _massif(data: IslandData, top: int, saddle: float) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var seen := PackedByteArray()
	seen.resize(data.height.size())
	seen[top] = 1
	var cells := PackedInt32Array([top])
	var head: int = 0
	while head < cells.size():
		var i: int = cells[head]
		head += 1
		# Land never reaches the grid's edge, so a land cell's neighbors are always on the grid.
		for n: int in [i - size - 1, i - size, i - size + 1, i - 1, i + 1, i + size - 1, i + size, i + size + 1]:
			if seen[n] == 0 and data.main_island[n] == 1 and data.height[n] > saddle:
				seen[n] = 1
				cells.append(n)
	return cells
