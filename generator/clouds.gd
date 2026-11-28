class_name Clouds
## Generator step 6, last part: on about half the islands, lays one flat cloud layer across the
## contender band. From under it, the land above its base is hidden. From over it, the land below its
## top is hidden, so only the tallest tops show. Inside it, the view shrinks to
## LineOfSight.CLOUD_RADIUS.

## The chance that an island has a layer. Raising it gives more runs with clouds.
const CHANCE: float = 0.5
## Height-map units from the layer's base to its top. Raising it widens the band of slope on which
## the player stands inside the cloud.
const THICKNESS: float = 0.04
## Height-map units the second-highest contender rises above the layer at least. Raising it makes
## the tops that stick through larger and lowers the layer.
const PEEK: float = 0.02


## Sets data.cloud_base from the contenders' final heights, so it runs after Contenders. At least two
## tops stick through, or the one that did would be the summit.
static func place(data: IslandData, rng: RandomNumberGenerator) -> void:
	if rng.randf() >= CHANCE or data.contenders.size() < 2:
		return
	var tops: Array[float] = []
	for top: int in data.contenders:
		tops.append(data.height[top])
	tops.sort()
	data.cloud_base = rng.randf_range(tops[0], tops[-2]) - PEEK - THICKNESS


## The height of the layer's top, above the summit when the island has none.
static func top(island: IslandData) -> float:
	return island.cloud_base + THICKNESS


## True when the eye stands inside the layer, where the view shrinks to LineOfSight.CLOUD_RADIUS.
static func inside(island: IslandData, eye: int) -> bool:
	return island.height[eye] >= island.cloud_base and island.height[eye] < top(island)


## The cells in cells that the layer doesn't hide from eye: from under it, those under its base, and
## from over it, those over its top. Inside, the short view already hides the rest.
static func clear_of(island: IslandData, eye: int, cells: PackedInt32Array) -> PackedInt32Array:
	if inside(island, eye):
		return cells
	var under: bool = island.height[eye] < island.cloud_base
	var clear := PackedInt32Array()
	for cell: int in cells:
		var height: float = island.height[cell]
		if (height <= island.cloud_base) if under else (height >= top(island)):
			clear.append(cell)
	return clear
