class_name Walkability
extends RefCounted
## Which steps between neighboring cells the player can take, and how fast. Movement checks every
## step the player takes against can_step(), and the route guarantee in generator step 6 searches
## with the same function, so the generator can never promise a route that movement refuses.

## World units the summit stands above sea level, as in SPEC.md. The debug view's height slider
## starts here. Raising it makes every slope steeper in world units, so more of them block.
const SUMMIT_UNITS: float = 100.0
## The terrain shader's cliff_normal_y. Faces whose normal's y is below it are drawn as cliff rock.
const CLIFF_NORMAL_Y: float = 0.3
## Steepest walkable slope, in height units per cell. A normal with y = n belongs to a slope of
## sqrt(1 / n² - 1), so 0.3 gives about 3.18 world units per cell, 0.0318 against a summit of 1.0.
## Keep it at the shader's threshold, so every slope that blocks is drawn as rock.
const MAX_SLOPE: float = sqrt(1.0 / (CLIFF_NORMAL_Y * CLIFF_NORMAL_Y) - 1.0) / SUMMIT_UNITS
## Walking speed on a Ramps.Terrain value, as a share of full speed. Terrain not listed walks at
## full speed. Lowering a value makes that ground slower to cross.
const MATERIAL_SPEED: Dictionary[int, float] = {
	Ramps.Terrain.FOREST: 0.75,
	Ramps.Terrain.MARSH: 0.6,
}
## Walking speed while wading a river, whatever ground lies under it.
const WADE_SPEED: float = 0.5
## Random cells start_cell() tries before it gives up.
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
## corner step also needs both cells beside it open, so the player can't slip between two corners.
static func can_step(data: IslandData, from: int, to: int) -> bool:
	if blocked(data, to):
		return false
	var size: int = IslandData.SIZE
	var dx: int = to % size - from % size
	var dy: int = to / size - from / size
	var distance: float = 1.0
	if dx != 0 and dy != 0:
		if blocked(data, from + dx) or blocked(data, from + dy * size):
			return false
		distance = sqrt(2.0)
	return absf(data.height[to] - data.height[from]) <= MAX_SLOPE * distance


## Walking speed on cell, as a share of full speed.
static func speed(data: IslandData, cell: int) -> float:
	if data.fresh_water[cell] == 1:
		return WADE_SPEED
	return MATERIAL_SPEED.get(data.material[cell], 1.0)


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
