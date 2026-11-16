class_name MainIsland
## Finds the largest connected land area. Islets off its coast are scenery the player can see but
## not reach, so later steps place peaks, vardes and points of interest only on the main island.


## Returns a mask with 1 on the main island's cells and 0 everywhere else. Land is height above 0.0.
## Cells connect through their four edge neighbors, so islets touching only at a corner stay apart.
static func generate(height: PackedFloat32Array) -> PackedByteArray:
	var size: int = IslandData.SIZE
	var cells: int = height.size()
	# 0 is unvisited, and each land area gets the next number from 1.
	var area := PackedInt32Array()
	area.resize(cells)
	# Each cell joins the queue once at most, so one buffer of the grid's size holds every fill.
	var queue := PackedInt32Array()
	queue.resize(cells)
	var areas: int = 0
	# -1 matches no cell, so a map with no land gives an empty mask instead of marking the sea.
	var largest: int = -1
	var largest_size: int = 0
	for start: int in cells:
		if area[start] != 0 or height[start] <= 0.0:
			continue
		areas += 1
		area[start] = areas
		queue[0] = start
		var head: int = 0
		var tail: int = 1
		while head < tail:
			var i: int = queue[head]
			head += 1
			var x: int = i % size
			for next: int in [i - 1 if x > 0 else -1, i + 1 if x < size - 1 else -1, i - size, i + size]:
				if next >= 0 and next < cells and area[next] == 0 and height[next] > 0.0:
					area[next] = areas
					queue[tail] = next
					tail += 1
		if tail > largest_size:
			largest = areas
			largest_size = tail

	var mask := PackedByteArray()
	mask.resize(cells)
	for i: int in cells:
		mask[i] = 1 if area[i] == largest else 0
	return mask
