class_name LineOfSight
## Which cells the player sees from where they stand. It casts rays from the eye across the height
## map, and terrain that rises above the line to it hides what lies behind.

## Cells the player sees on flat ground at sea level. Raising it shows more of the island from the
## shore, and every cast costs more.
const SEA_RADIUS: float = 40.0
## Cells the player sees standing on the summit. The radius grows in a straight line from SEA_RADIUS
## with the ground's height, so every metre climbed widens the view by the same amount and a low hill
## already pays off. Raising it makes climbing a peak reveal more of the island.
const SUMMIT_RADIUS: float = 120.0
## World units from the ground to the eye. Raising it lets the player see over low bumps close by
## and down past an edge from further back. At the figure's height, 1.5, the player had to stand at
## the very edge of a cliff to clear the fog below it, which felt wrong from a camera that looks
## down. At 8 the player sees about twice as many cells on a massif's slopes, and a cast costs the same.
const EYE_HEIGHT: float = 8.0
## Cells between the samples along a ray. At 1 the samples at whole distances skipped cells whose
## corner the ray clipped between two of them, 168 of the 4,800 inside the sea-level radius. Halving
## it doubles the cost of a cast.
const STEP: float = 0.5
## Cells around the player that always count as seen, even where the ground drops away out of the
## view. From a rounded top the rays pass over the slope just below it, and on the summit of seed 0
## only 49 of the 121 cells within 5 were seen, so the player stood in fog. At 4 the fog's softened
## edge still covered the ground underfoot. Raising it reveals more ground close by, around corners
## and behind ridges too.
const NEAR_RADIUS: float = 10.0
## Cells the player sees inside a cloud cap. Raising it lets the player see further up the slope
## from inside.
const CLOUD_RADIUS: float = 8.0


## The view radius in cells for an eye over ground of height, the generator's 0 to 1.
static func radius(height: float) -> float:
	return lerpf(SEA_RADIUS, SUMMIT_RADIUS, clampf(height, 0.0, 1.0))


## The cells seen from the center of cell, each once, sea included, so the fog can cover the
## unknown sea too. It only reads island, so it can run on a worker thread, and on the summit it
## takes about 35 ms natively. Each ray walks out STEP cells at a time and keeps the steepest slope
## from the eye so far, and a cell shows when its ground rises to that slope, or lies within
## NEAR_RADIUS of the player. reach_scale multiplies the view radius, 2 for a survey from a peak, and
## max_reach caps it, CLOUD_RADIUS inside a cloud.
static func visible_cells(island: IslandData, cell: int, reach_scale: float = 1.0, max_reach: float = INF) -> PackedInt32Array:
	var size: int = IslandData.SIZE
	var heights: PackedFloat32Array = island.height
	var ground: float = maxf(heights[cell], 0.0)
	var reach: float = minf(radius(ground) * reach_scale, max_reach)
	var eye: float = ground * IslandTerrain.SUMMIT_HEIGHT + EYE_HEIGHT
	var origin := Vector2(cell % size + 0.5, cell / size + 0.5)
	# One ray per cell on the rim, so neighboring rays end at most a cell apart and leave no gaps.
	var rays: int = ceili(TAU * reach)
	var steps: int = floori(reach / STEP)
	# The rays start at the center of the cell, so a ray of length reach can end in a cell
	# round(reach) away, one past floor(reach) when reach has a fraction of a half or more.
	var cells: int = ceili(reach)
	var marked := PackedByteArray()
	var side: int = 2 * cells + 1
	marked.resize(side * side)
	var corner_x: int = int(origin.x) - cells
	var corner_y: int = int(origin.y) - cells
	var seen := PackedInt32Array([cell])
	marked[cells * side + cells] = 1
	var scale: float = IslandTerrain.SUMMIT_HEIGHT
	for ray: int in rays:
		var angle: float = TAU * ray / rays
		var dx: float = cos(angle) * STEP
		var dy: float = sin(angle) * STEP
		var px: float = origin.x
		var py: float = origin.y
		var horizon: float = -INF
		for step: int in range(1, steps + 1):
			px += dx
			py += dy
			if px < 0.0 or py < 0.0 or px >= size or py >= size:
				break
			var x: int = int(px)
			var y: int = int(py)
			var index: int = y * size + x
			# The sea draws flat at 0, so it hides nothing below that.
			var slope: float = (maxf(heights[index], 0.0) * scale - eye) / (step * STEP)
			if slope >= horizon:
				horizon = slope
			elif step * STEP > NEAR_RADIUS:
				continue
			var local: int = (y - corner_y) * side + (x - corner_x)
			if marked[local] == 0:
				marked[local] = 1
				seen.append(index)
	return seen
