class_name Walkability
extends RefCounted
## Which steps between neighboring cells the player can take. Movement checks every
## step the player takes against can_step(), and the route guarantee in generator step 6 searches
## with the same function, so the generator can never promise a route that movement refuses.

## World units the summit stands above sea level, as in SPEC.md. IslandTerrain.SUMMIT_HEIGHT reads
## it, so the terrain and the debug view's height slider start here. Raising it makes every slope
## steeper in world units, so more of them block.
const SUMMIT_UNITS: float = 100.0
## Steepest slope the player walks up or down, in degrees. At 72° the player climbed spires and
## walked up walls. At 45° the eroded massifs of #94 were too steep to walk up on almost every
## side, with a summit of SUMMIT_UNITS on this grid. Raising it opens more of the mountainsides.
const WALK_DEGREES: float = 60.0
## The terrain shader's cliff_normal_y. Faces whose normal's y is below it are drawn as cliff rock.
## It sits at the walk limit, so rock starts near the angle that blocks. The shader's cliff_wobble
## moves the edge by noise so it doesn't follow one contour, so rock can show from about 45° and
## grass up to about 72°, at ragged edges. With rock from 72° and walking to 45° everywhere, whole
## slopes between blocked while drawn as grass.
const CLIFF_NORMAL_Y: float = cos(deg_to_rad(WALK_DEGREES))
## Steepest walkable slope, in height units per cell: about 1.73 world units per cell at 60°,
## 0.0173 against a summit of 1.0.
const MAX_SLOPE: float = tan(deg_to_rad(WALK_DEGREES)) / SUMMIT_UNITS
## Random cells start_cell() tries before it gives up. Most tries land off the beach and cost little.
## Raising it only matters on an island with very little beach, and lowering it risks no start.
const START_TRIES: int = 100000
## Cells a start cell must reach. It keeps the player out of a cove walled in by cliffs. Raising it
## costs a longer search for each beach cell tried.
const START_REACH: int = 20000


## True when the player can't stand on cell, in the sea or a lake. Rivers can be waded, so they
## don't block. Land never reaches the grid's edge, so a land cell's neighbors are always on the grid.
static func blocked(data: IslandData, cell: int) -> bool:
	return data.height[cell] <= 0.0 or data.lake[cell] == 1


## True when the player can step from cell from to its neighbor to, edge or corner. The step blocks
## where to is blocked or the slope between the two is steeper than MAX_SLOPE, going up or down. A
## corner step also needs the edge steps to both cells beside it open, so the player can't slip
## between two corners of water or cliff.
static func can_step(data: IslandData, from: int, to: int) -> bool:
	var size: int = IslandData.SIZE
	var dx: int = to % size - from % size
	var dy: int = to / size - from / size
	if dx != 0 and dy != 0:
		if not _edge_step(data, from, from + dx) or not _edge_step(data, from, from + dy * size):
			return false
		return not blocked(data, to) and absf(data.height[to] - data.height[from]) <= MAX_SLOPE * sqrt(2.0)
	return _edge_step(data, from, to)


## True when the edge step from from to to is open, with no corner rule.
static func _edge_step(data: IslandData, from: int, to: int) -> bool:
	return not blocked(data, to) and absf(data.height[to] - data.height[from]) <= MAX_SLOPE


## The open neighbors of cell, edge and corner, that the player can step to.
static func steps(data: IslandData, cell: int) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var open := PackedInt32Array()
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var to: int = cell + dy * size + dx
			if (dx != 0 or dy != 0) and can_step(data, cell, to):
				open.append(to)
	return open


## A random beach cell on the main island, off the rivers, that reaches at least START_REACH
## cells. Milestone 5 replaces it with the landing beach. Returns -1 if no try finds one.
static func start_cell(data: IslandData, rng: RandomNumberGenerator) -> int:
	for attempt: int in START_TRIES:
		var cell: int = rng.randi_range(0, data.height.size() - 1)
		if data.main_island[cell] == 1 and data.material[cell] == Ramps.Terrain.BEACH \
				and data.fresh_water[cell] == 0 and reachable(data, cell, START_REACH).size() >= START_REACH:
			return cell
	push_error("Walkability: no start cell on island %d" % data.island_seed)
	return -1


## The cells the player can walk to from start, start first, breadth first. Stops after limit cells.
static func reachable(data: IslandData, start: int, limit: int = 1 << 30) -> PackedInt32Array:
	var seen := PackedByteArray()
	seen.resize(data.height.size())
	seen[start] = 1
	var queue := PackedInt32Array([start])
	var head: int = 0
	while head < queue.size() and queue.size() < limit:
		for to: int in steps(data, queue[head]):
			if seen[to] == 0:
				seen[to] = 1
				queue.append(to)
		head += 1
	return queue
