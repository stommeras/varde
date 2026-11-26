class_name Landing
## Generator step 6, after the contenders: the landing beach with its shipwreck, where the run
## starts, and the first old varde along the route to the summit. The beach lies on the far side of
## the island from the summit, so the route is long enough for the trail of 6 to 10 vardes 60 to
## 120 cells apart that SPEC.md asks for.

## Share of the farthest shore cell's distance from the summit that a landing beach must lie at
## least. Raising it lands the player further from the summit and lengthens the route, lowering it
## spreads the landings over more of the coast.
const FAR_SHARE: float = 0.75
## Shore cells place() tries before it gives up. Each try that passes the cheap checks costs a
## search of START_REACH cells, about 0.1 s.
const TRIES: int = 200
## Cells a start cell must reach. It keeps the player out of a cove walled in by cliffs. Raising it
## costs a longer search for each cell tried.
const START_REACH: int = 20000
## Cells the start lies inland from the wreck. The wreck's hull is about 4 cells long, so at 3 the
## figure stands just past its stern.
const START_GAP: float = 3.0
## Cells from the wreck within which "[F] Les" shows. It reaches the start, so the prompt shows as
## the run opens. Raising it shows the prompt from further up the beach.
const READ_REACH: float = 4.0
## Cells from the wreck's shore cell around which the sea's direction is measured. Raising it
## follows the coast's broad line instead of the bends at the wreck.
const SEA_RADIUS: int = 3
## Straight-line cells from the wreck to the first old varde, as SPEC.md sets them.
const FIRST_VARDE_MIN: float = 60.0
const FIRST_VARDE_MAX: float = 120.0


## Sets data.wreck to a beach cell on the shore far from the summit and data.start to a beach cell
## START_GAP inland from it. Leaves both at -1 if no try finds a pair.
static func place(data: IslandData, rng: RandomNumberGenerator) -> void:
	data.wreck = -1
	data.start = -1
	var summit: Vector2 = _point(data.peaks[0].cell)
	var shore := PackedInt32Array()
	var distances := PackedFloat32Array()
	var farthest: float = 0.0
	for cell: int in data.height.size():
		if data.main_island[cell] == 1 and data.material[cell] == Ramps.Terrain.BEACH and data.fresh_water[cell] == 0 \
				and not Walkability.blocked(data, cell) and _touches_sea(data, cell):
			var distance: float = _point(cell).distance_to(summit)
			shore.append(cell)
			distances.append(distance)
			farthest = maxf(farthest, distance)
	var far := PackedInt32Array()
	for i: int in shore.size():
		if distances[i] >= farthest * FAR_SHARE:
			far.append(shore[i])
	for attempt: int in TRIES:
		if far.is_empty():
			break
		var wreck: int = far[rng.randi_range(0, far.size() - 1)]
		var inland: Vector2 = _point(wreck) - _sea_direction(data, wreck) * START_GAP
		var start: int = IslandData.index(int(inland.x), int(inland.y))
		if data.main_island[start] == 1 and data.material[start] == Ramps.Terrain.BEACH and data.fresh_water[start] == 0 \
				and not Walkability.blocked(data, start) and Walkability.reachable(data, start, START_REACH).size() >= START_REACH:
			data.wreck = wreck
			data.start = start
			return
	push_error("Landing: no landing beach on island %d" % data.island_seed)


## The cell on data.route where the first old varde stands: the first one at least a random
## distance from FIRST_VARDE_MIN to FIRST_VARDE_MAX from the wreck, in a straight line. The route
## winds, so a later cell can lie closer again, but the first varde stays the first one that far.
## The last cell of the route if none is that far.
static func first_varde(data: IslandData, rng: RandomNumberGenerator) -> int:
	var reach: float = rng.randf_range(FIRST_VARDE_MIN, FIRST_VARDE_MAX)
	var wreck: Vector2 = _point(data.wreck)
	for cell: int in data.route:
		if _point(cell).distance_to(wreck) >= reach:
			return cell
	return data.route[-1]


## The unit grid direction, x east and y south, from cell toward the sea around it.
static func _sea_direction(data: IslandData, cell: int) -> Vector2:
	var sum := Vector2.ZERO
	for dy: int in range(-SEA_RADIUS, SEA_RADIUS + 1):
		for dx: int in range(-SEA_RADIUS, SEA_RADIUS + 1):
			if data.height[cell + dy * IslandData.SIZE + dx] <= 0.0:
				sum += Vector2(dx, dy)
	return sum.normalized()


static func _touches_sea(data: IslandData, cell: int) -> bool:
	for offset: int in [-1, 1, -IslandData.SIZE, IslandData.SIZE]:
		if data.height[cell + offset] <= 0.0:
			return true
	return false


## The middle of cell in grid units, x east and y south.
static func _point(cell: int) -> Vector2:
	return Vector2(cell % IslandData.SIZE + 0.5, cell / IslandData.SIZE + 0.5)
