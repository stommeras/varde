class_name Clouds
## Generator step 6, last part: puts a still cloud cap on about half the contenders, the summit
## included, so a cloud never gives the summit away. A cap covers the land around the top that stands
## less than DEPTH under it.

## The chance that a contender has a cloud. Raising it hides more tops. The summit has the same
## chance, so no value gives it away.
const CHANCE: float = 0.5
## How far the cloud's base lies under its top, as a share of the summit's height. Raising it spreads
## the cap further down the mountain. Keep it under the 0.23 contenders keep over their saddle, so a
## cap never spills onto a neighbor.
const DEPTH: float = 0.2


## Fills data.cloud_tops and data.cloud from the final heights. It reads data.contenders, so it runs
## after Contenders.
static func place(data: IslandData, rng: RandomNumberGenerator) -> void:
	data.cloud.resize(data.height.size())
	for top: int in data.contenders:
		if rng.randf() >= CHANCE:
			continue
		data.cloud_tops.append(top)
		for cell: int in Contenders.massif(data, top, data.height[top] - DEPTH):
			data.cloud[cell] = data.cloud_tops.size()


## The height of the base of the cloud at index in island.cloud_tops, in the units of the height array.
static func base(island: IslandData, index: int) -> float:
	return island.height[island.cloud_tops[index]] - DEPTH
