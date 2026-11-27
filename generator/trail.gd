class_name Trail
## Generator step 7, after the route: the old vardes. They mark the way up some of the mountains, a
## line of them from the foot of each to just below its top, each about in sight of the next. They
## don't lead across the island, so the player still picks which mountain to climb. The top varde of
## each line holds a note that names the direction of the nearest higher peak.

## How an old varde has weathered. Hidden ones stand only on forest cells.
enum Kind { STANDING, FALLEN, HIDDEN }

## Share of the peaks that get a line of vardes, rounded up. Raising it marks more mountains, and at
## 1 a marked way up says nothing about a mountain.
const MARKED_SHARE: float = 0.5
## Share of a top's height at which its line starts, where the walk to the top climbs past it for
## good. Lowering it starts the line further out in the lowland. At 0.35, with vardes 30 to 50
## cells apart, a third of the lines on seeds 7 and 624862 held a single varde.
const FOOT_SHARE: float = 0.3
## Straight-line cells from each varde in a line to the next. Sight at sea level is 40 cells, so the
## next varde stands in view, as on a real marked way. Raising them gives fewer vardes per line.
const GAP_MIN: float = 25.0
const GAP_MAX: float = 40.0
## Cells from an old varde within which "[F] Les" shows, the couple of cells SPEC.md asks for.
## Raising it shows the prompt from further off.
const READ_REACH: float = 2.5
## Cells an old varde keeps from every peak's top, the survey zone and READ_REACH beyond it, so F
## never both surveys and reads. The top varde of a line stands just outside it.
const PEAK_GAP: float = Peak.ZONE_RADIUS + READ_REACH
## Chance that a varde on a forest cell stands hidden in the forest. Raising it hides more of the
## feet of the lines, where the forest grows.
const HIDDEN_CHANCE: float = 0.5
## Chance that any other varde below the top has fallen over. Raising it leaves fewer standing.
const FALLEN_CHANCE: float = 0.25


## Fills data.vardes, data.varde_kinds and data.varde_peaks with a line of vardes up each marked
## peak, foot first. The summit and one other contender are always marked, so a marked way up
## doesn't give the summit away. grid is a search grid from Walkability.path_grid().
static func place(data: IslandData, rng: RandomNumberGenerator, grid: AStarGrid2D) -> void:
	data.vardes = PackedInt32Array()
	data.varde_kinds = PackedByteArray()
	data.varde_peaks = PackedInt32Array()
	for top: int in _marked(data, rng):
		var path: PackedInt32Array = data.route if top == data.peaks[0].cell else Walkability.route(data, data.start, top, grid)
		if not path.is_empty():
			_line(data, path, top, rng)


## The top of the nearest peak higher than the peak whose top is cell, or -1 for the summit.
static func higher_peak(data: IslandData, cell: int) -> int:
	var height: float = data.height[cell]
	var at: Vector2 = IslandData.center(cell)
	var nearest: int = -1
	for peak: Peak in data.peaks:
		if data.height[peak.cell] > height and (nearest < 0 or at.distance_to(IslandData.center(peak.cell)) < at.distance_to(IslandData.center(nearest))):
			nearest = peak.cell
	return nearest


## The tops of the peaks that get a line: the summit, one other contender, and random peaks after.
static func _marked(data: IslandData, rng: RandomNumberGenerator) -> PackedInt32Array:
	var marked := PackedInt32Array([data.peaks[0].cell])
	var rest := PackedInt32Array()
	var contenders := PackedInt32Array()
	for peak: Peak in data.peaks.slice(1):
		rest.append(peak.cell)
		if data.contenders.has(peak.cell):
			contenders.append(peak.cell)
	if not contenders.is_empty():
		var contender: int = contenders[rng.randi_range(0, contenders.size() - 1)]
		marked.append(contender)
		rest.remove_at(rest.find(contender))
	var count: int = ceili(data.peaks.size() * MARKED_SHARE)
	while marked.size() < count and not rest.is_empty():
		var i: int = rng.randi_range(0, rest.size() - 1)
		marked.append(rest[i])
		rest.remove_at(i)
	return marked


## Places the line up to top along path, a walk that ends beside top. It starts where path last
## climbs past FOOT_SHARE of the top's height and ends with a varde just outside PEAK_GAP. Cells near
## another line's vardes are skipped, so two lines that share the lower path share its vardes.
static func _line(data: IslandData, path: PackedInt32Array, top: int, rng: RandomNumberGenerator) -> void:
	var foot: int = 0
	for i: int in path.size():
		if data.height[path[i]] < data.height[top] * FOOT_SHARE:
			foot = i + 1
	var line := PackedInt32Array()
	var last := Vector2.INF
	var reach: float = 0.0
	var highest: int = -1
	for i: int in range(foot, path.size()):
		var at: Vector2 = IslandData.center(path[i])
		if _near_peak(data, at):
			continue
		highest = path[i]
		if at.distance_to(last) >= reach and not _near_varde(data, at):
			line.append(path[i])
			last = at
			reach = rng.randf_range(GAP_MIN, GAP_MAX)
	if highest < 0:
		return
	# The top varde stands on the highest cell outside the zone. It takes the place of the vardes
	# that stand too close to it, more than one where the walk winds back.
	while not line.is_empty() and IslandData.center(line[-1]).distance_to(IslandData.center(highest)) < GAP_MIN:
		line.remove_at(line.size() - 1)
	line.append(highest)
	for i: int in line.size():
		data.vardes.append(line[i])
		data.varde_peaks.append(top)
		data.varde_kinds.append(Kind.STANDING if i == line.size() - 1 else _kind(data, line[i], rng))


static func _near_peak(data: IslandData, at: Vector2) -> bool:
	for peak: Peak in data.peaks:
		if at.distance_to(IslandData.center(peak.cell)) <= PEAK_GAP:
			return true
	return false


static func _near_varde(data: IslandData, at: Vector2) -> bool:
	for varde: int in data.vardes:
		if at.distance_to(IslandData.center(varde)) < GAP_MIN:
			return true
	return false


static func _kind(data: IslandData, cell: int, rng: RandomNumberGenerator) -> Kind:
	if data.material[cell] == Ramps.Terrain.FOREST and rng.randf() < HIDDEN_CHANCE:
		return Kind.HIDDEN
	return Kind.FALLEN if rng.randf() < FALLEN_CHANCE else Kind.STANDING
