class_name Rivers
extends RefCounted
## Generator step 4: rivers and lakes. Springs on the high ground of the main island each send a
## river downhill to the sea. A river that runs into a pit fills it up to the lowest point on its rim
## and runs on from the other side, so water always flows out, and the filled pit is a lake. A river
## that meets an earlier one joins it and ends there.
## Pits are filled only where a river finds one, instead of over the whole grid first. A full fill
## needs a priority queue over every land cell, which takes seconds in GDScript, and the rivers only
## ever touch a few thousand cells.

## How many springs to place. Raising it gives more rivers and more forks. Each spring past the
## first few mostly adds a short tributary, because the rivers soon meet in the same valleys.
const SPRINGS: int = 30
## Lowest height a spring can start at, where the summit is 1.0. Lowering it adds short rivers on
## the lowland hills, raising it keeps them to the big mountains.
const SPRING_HEIGHT: float = 0.2
## Fewest cells between two springs. Lowering it lets springs bunch up on one mountain, so their
## rivers run side by side before they join.
const SPRING_SPACING: float = 60.0
## Random cells to try before giving up on placing all SPRINGS. Islands with little high ground get
## fewer springs.
const SPRING_TRIES: int = 20000
## River cells upstream of a cell that widen it by one cell on each side. The width grows with the
## square root, so radius 1 at this flow, 2 at 4 times it. Lowering it widens the rivers sooner.
const WIDEN_FLOW: float = 600.0
## Widest a river gets, in cells on each side of its middle.
const MAX_RADIUS: int = 2

## The eight neighbors as column and row offsets, with the distance to each, so diagonal slopes
## aren't overstated.
const NEIGHBOR_X: Array[int] = [-1, 0, 1, -1, 1, -1, 0, 1]
const NEIGHBOR_Y: Array[int] = [-1, -1, -1, 0, 0, 1, 1, 1]
const NEIGHBOR_DISTANCE: Array[float] = [1.4142135, 1.0, 1.4142135, 1.0, 1.0, 1.4142135, 1.0, 1.4142135]

## The island's height, with every pit a river ran into filled flat up to its rim.
var _height: PackedFloat32Array
var _rng: RandomNumberGenerator
## The river each cell belongs to, plus 1, so 0 is no river.
var _owner := PackedInt32Array()
## Which pit fill last looked at each cell, so each fill can tell its cells apart without clearing.
## Fill n marks the rim cells it looked at with 2n and the lake's cells with 2n + 1.
var _flood_mark := PackedInt32Array()
var _floods: int = 0
## Every lake cell, once for each fill that covered it.
var _lake_cells := PackedInt32Array()


func _init(height: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	_height = height
	_rng = rng
	_owner.resize(height.size())
	_flood_mark.resize(height.size())


## Traces the rivers of data from its height and main island, fills data.height flat where they made
## lakes, and stores data.rivers and data.fresh_water. Spring places and river bends come from rng.
static func generate(data: IslandData, rng: RandomNumberGenerator) -> void:
	var tracer := Rivers.new(data.height, rng)
	var rivers: Array[PackedInt32Array] = []
	for spring: int in _springs(data, rng):
		if tracer._owner[spring] != 0:
			continue
		var path: PackedInt32Array = tracer._trace(spring)
		for i: int in path:
			if tracer._owner[i] == 0:
				tracer._owner[i] = rivers.size() + 1
		rivers.append(path)
	data.height = tracer._height
	data.rivers = rivers
	data.fresh_water = tracer._paint(rivers)


## Picks spring cells on the main island's high ground, at least SPRING_SPACING apart.
static func _springs(data: IslandData, rng: RandomNumberGenerator) -> PackedInt32Array:
	var springs := PackedInt32Array()
	var places: Array[Vector2] = []
	for attempt: int in SPRING_TRIES:
		if springs.size() == SPRINGS:
			break
		var place := Vector2(rng.randi_range(0, IslandData.SIZE - 1), rng.randi_range(0, IslandData.SIZE - 1))
		var i: int = IslandData.index(int(place.x), int(place.y))
		if data.main_island[i] == 0 or data.height[i] < SPRING_HEIGHT:
			continue
		var crowded: bool = false
		for other: Vector2 in places:
			if other.distance_to(place) < SPRING_SPACING:
				crowded = true
				break
		if not crowded:
			springs.append(i)
			places.append(place)
	return springs


## The cells of one river from spring down to the first sea cell, or to the first cell of an
## earlier river. Fills each pit it runs into.
func _trace(spring: int) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var path := PackedInt32Array([spring])
	var cell: int = spring
	var drops := PackedFloat32Array()
	drops.resize(8)
	# Each step either goes strictly downhill or fills a pit and leaves it lower than its new level,
	# so the trace always ends. The cap only turns a bug into an error instead of a hang.
	for step: int in _height.size():
		if _height[cell] <= 0.0 or _owner[cell] != 0:
			return path
		# A random downhill neighbor, weighted by slope. Always taking the steepest one ran the rivers
		# in straight lines along the grid's 8 directions, tens of cells long on the lowland. Weighting
		# by slope still follows the fall line on average, so the river wanders around it.
		var x: int = cell % size
		var y: int = cell / size
		var total: float = 0.0
		for k: int in 8:
			var n: int = IslandData.index(x + NEIGHBOR_X[k], y + NEIGHBOR_Y[k])
			drops[k] = maxf((_height[cell] - _height[n]) / NEIGHBOR_DISTANCE[k], 0.0)
			total += drops[k]
		if total > 0.0:
			var pick: float = _rng.randf() * total
			for k: int in 8:
				pick -= drops[k]
				if drops[k] > 0.0 and pick <= 0.0:
					cell = IslandData.index(x + NEIGHBOR_X[k], y + NEIGHBOR_Y[k])
					break
			path.append(cell)
			continue
		var outlet: int = _fill_pit(cell)
		var lake: int = _floods * 2 + 1
		# The river enters the lake at its first cell in the lake. Every cell after that is lower, so
		# it lies in the lake too, and gives way to the shortest crossing to the outlet.
		var entry: int = 0
		while _flood_mark[path[entry]] != lake:
			entry += 1
		path.resize(entry + 1)
		for i: int in _cross(path[entry], outlet, lake):
			path.append(i)
			if _owner[i] != 0:
				return path
		cell = outlet
	push_error("Rivers: the river from cell %d never reached the sea" % spring)
	return path


## Fills the pit at cell up to the lowest point on its rim, and returns the cell just outside the
## rim that the water spills into. Land never reaches the grid's edge, so the fill never checks it.
func _fill_pit(pit: int) -> int:
	var size: int = IslandData.SIZE
	_floods += 1
	var seen: int = _floods * 2
	var lake: int = seen + 1
	var level: float = _height[pit]
	var region := PackedInt32Array([pit])
	_flood_mark[pit] = lake
	# A min-heap of the cells on the lake's rim, keyed by height in the high bits and the index in the
	# low 20. Heights stay above -8, and the scale of 1e9 keeps any two float32 heights apart.
	var rim := PackedInt64Array()
	var cell: int = pit
	while true:
		var x: int = cell % size
		var y: int = cell / size
		for k: int in 8:
			var n: int = IslandData.index(x + NEIGHBOR_X[k], y + NEIGHBOR_Y[k])
			if _flood_mark[n] < seen:
				_flood_mark[n] = seen
				_push(rim, (int((_height[n] + 8.0) * 1e9) << 20) | n)
		cell = _pop(rim) & 0xFFFFF
		# The rim pops lowest first, so the first cell below the water spills it.
		if _height[cell] < level:
			break
		level = _height[cell]
		_flood_mark[cell] = lake
		region.append(cell)
	for i: int in region:
		_height[i] = level
	_lake_cells.append_array(region)
	return cell


## The shortest way from entry to outlet through the cells of lake, without entry. Breadth first.
## The lake hides the river, so its way across only has to connect.
func _cross(entry: int, outlet: int, lake: int) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var came_from: Dictionary[int, int] = {entry: -1}
	var queue := PackedInt32Array([entry])
	var head: int = 0
	while not came_from.has(outlet):
		var cell: int = queue[head]
		head += 1
		var x: int = cell % size
		var y: int = cell / size
		for k: int in 8:
			var n: int = IslandData.index(x + NEIGHBOR_X[k], y + NEIGHBOR_Y[k])
			if not came_from.has(n) and (_flood_mark[n] == lake or n == outlet):
				came_from[n] = cell
				queue.append(n)
	var crossing := PackedInt32Array()
	var cell: int = outlet
	while cell != entry:
		crossing.append(cell)
		cell = came_from[cell]
	crossing.reverse()
	return crossing


## 1 on every lake cell and every cell a river's water covers. Each river cell counts the river
## cells upstream of it, its own river's and every tributary's, and widens with the square root of
## that count.
func _paint(rivers: Array[PackedInt32Array]) -> PackedByteArray:
	var size: int = IslandData.SIZE
	var mask := PackedByteArray()
	mask.resize(_height.size())
	for i: int in _lake_cells:
		mask[i] = 1
	# Flow that tributaries bring into each cell. A river only joins an earlier one, so going from
	# the last river to the first adds every tributary before its river is painted.
	var inflow: Dictionary[int, int] = {}
	for r: int in range(rivers.size() - 1, -1, -1):
		var flow: int = 0
		for i: int in rivers[r]:
			if _owner[i] != r + 1:
				# The cell where this river joins an earlier one.
				inflow[i] = inflow.get(i, 0) + flow
				break
			flow += 1 + inflow.get(i, 0)
			var radius: int = mini(int(sqrt(flow / WIDEN_FLOW)), MAX_RADIUS)
			var x: int = i % size
			var y: int = i / size
			for dy: int in range(-radius, radius + 1):
				for dx: int in range(-radius, radius + 1):
					# The extra radius rounds the disc, so radius 1 is a plus instead of a lone cell.
					if dx * dx + dy * dy <= radius * radius + radius:
						mask[IslandData.index(x + dx, y + dy)] = 1
	return mask


## Adds key to the min-heap.
static func _push(heap: PackedInt64Array, key: int) -> void:
	var i: int = heap.size()
	heap.append(key)
	while i > 0:
		var parent: int = (i - 1) / 2
		if heap[parent] <= key:
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = key


## Removes and returns the smallest key of the min-heap.
static func _pop(heap: PackedInt64Array) -> int:
	var top: int = heap[0]
	var last: int = heap[heap.size() - 1]
	heap.resize(heap.size() - 1)
	var count: int = heap.size()
	if count == 0:
		return top
	var i: int = 0
	while true:
		var child: int = i * 2 + 1
		if child >= count:
			break
		if child + 1 < count and heap[child + 1] < heap[child]:
			child += 1
		if heap[child] >= last:
			break
		heap[i] = heap[child]
		i = child
	heap[i] = last
	return top
