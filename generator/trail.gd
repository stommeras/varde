class_name Trail
## Generator step 7, after the route: the old vardes that mark the way from the wreck to the summit.
## Each one stands on a route cell, so the player can always walk to it, and the trail reads in
## order along the route.

## How an old varde has weathered. Hidden ones stand only on forest cells.
enum Kind { STANDING, FALLEN, HIDDEN }

## Straight-line cells from the wreck to the first old varde. Under 60 put it in sight of the wreck
## on open beach. Raising them sends the player further before the first find.
const FIRST_MIN: float = 60.0
const FIRST_MAX: float = 120.0
## Straight-line cells from each later varde to the one before. Sight at sea level is 40 cells, so
## at 40 the next varde is just out of view. At SPEC.md's first 60 to 120, only 3 to 5 vardes fit
## on the 329 to 474 cell routes of seeds 0 to 9. Raising them gives fewer, further vardes.
const GAP_MIN: float = 40.0
const GAP_MAX: float = 60.0
## Most old vardes on one island. A long route stops placing them here.
const MOST_VARDES: int = 10
## Straight-line cells the last old varde keeps from the summit's top, so it doesn't stand beside
## the summit varde.
const SUMMIT_GAP: float = 40.0
## Cells from an old varde within which "[F] Les" shows, the couple of cells SPEC.md asks for.
## Raising it shows the prompt from further off.
const READ_REACH: float = 2.5
## Cells an old varde keeps from every peak's survey zone beyond READ_REACH, so F never both
## surveys and reads.
const PEAK_GAP: float = Peak.ZONE_RADIUS + READ_REACH
## Chance that a varde on a forest cell stands hidden in the forest. Route cells are forest on 20 to
## 70% of each route, so at 1 most of the trail would hide.
const HIDDEN_CHANCE: float = 0.5
## Chance that any other varde after the first has fallen over. Raising it leaves fewer standing.
const FALLEN_CHANCE: float = 0.25


## Fills data.vardes and data.varde_kinds from data.route. The first varde always stands, since
## the wreck's note says the crew saw it from the deck.
static func place(data: IslandData, rng: RandomNumberGenerator) -> void:
	data.vardes = PackedInt32Array()
	data.varde_kinds = PackedByteArray()
	var summit: Vector2 = IslandData.center(data.peaks[0].cell)
	var last: Vector2 = IslandData.center(data.wreck)
	var reach: float = rng.randf_range(FIRST_MIN, FIRST_MAX)
	for cell: int in data.route:
		var at: Vector2 = IslandData.center(cell)
		if at.distance_to(last) < reach or at.distance_to(summit) < SUMMIT_GAP or _near_peak(data, at):
			continue
		data.vardes.append(cell)
		data.varde_kinds.append(_kind(data, cell, data.vardes.size() == 1, rng))
		if data.vardes.size() == MOST_VARDES:
			return
		last = at
		reach = rng.randf_range(GAP_MIN, GAP_MAX)


static func _near_peak(data: IslandData, at: Vector2) -> bool:
	for peak: Peak in data.peaks:
		if at.distance_to(IslandData.center(peak.cell)) <= PEAK_GAP:
			return true
	return false


static func _kind(data: IslandData, cell: int, first: bool, rng: RandomNumberGenerator) -> Kind:
	if first:
		return Kind.STANDING
	if data.material[cell] == Ramps.Terrain.FOREST and rng.randf() < HIDDEN_CHANCE:
		return Kind.HIDDEN
	return Kind.FALLEN if rng.randf() < FALLEN_CHANCE else Kind.STANDING
