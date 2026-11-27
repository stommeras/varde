class_name Clouds
## Generator step 6, last part: puts a still cloud cap on about half the contenders, the summit
## included, so a cloud never gives the summit away. A cap covers the land around the top that stands
## less than DEPTH under it.

## The chance that a contender has a cloud.
const CHANCE: float = 0.5
## How far the cloud's base lies under its top, as a share of the summit's height. Raising it spreads
## the cap further down the mountain. At 0.08, 80 m, caps covered 41 to 263 cells on seeds 0 to 9,
## little more than the survey zone, so the short view inside hardly mattered. At 0.2, 200 m, they
## cover 181 to 1,739 cells, 8 to 23 cells from the top. Contenders keep 0.23 over their saddle, so
## a cap never spills onto a neighbor.
const DEPTH: float = 0.2


## Fills data.clouds and data.cloud from the final heights. Needs data.contenders.
static func place(data: IslandData, rng: RandomNumberGenerator) -> void:
	data.cloud.resize(data.height.size())
	for top: int in data.contenders:
		if rng.randf() >= CHANCE:
			continue
		data.clouds.append(top)
		for cell: int in Contenders.massif(data, top, data.height[top] - DEPTH):
			data.cloud[cell] = data.clouds.size()
