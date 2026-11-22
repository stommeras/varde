class_name Massifs
## Part of generator step 1: raises the massifs the surveyable peaks stand on. Each massif is 2 to 4
## ridges of uplift branching from one point, and the erosion step cuts them into a range with
## spurs, valleys and one clear top. Shapes stamped on as final heights looked like cones and stars,
## so the massifs only give erosion something to cut, and the land takes its look from erosion.

## Massifs the placement aims for. An island with little room gets fewer, since each massif needs
## land around it. Peaks.MIN_PROMINENCE decides how many of their tops count as peaks.
const MIN_COUNT: int = 6
const MAX_COUNT: int = 9
## Random spots tried before placement gives up on more massifs. Raising it fits more massifs on a
## crowded island at the cost of time, and lowering it leaves fewer than MIN_COUNT more often.
const TRIES: int = 8000
## Radius of a massif's core, in cells. Its ridges reach out up to RIDGE_LENGTH times as far.
## Raising it makes fewer and bigger massifs, lowering it more and steeper ones.
const MIN_RADIUS: float = 40.0
const MAX_RADIUS: float = 70.0
## Cells the middle of a massif keeps from the grid's edge. Raising it pulls massifs in toward the
## middle of the map, and lowering it lets their ridges run out to the coast.
const EDGE: float = 80.0
## Share of the radius around a massif's middle that must be land. Lower values let massifs stand
## on the coast and on narrow necks of land, where all their sides came out too steep to walk.
const SEA_MARGIN: float = 0.8
## Two massifs keep this share of their radii added together apart. Lower values merge them into
## ranges with high saddles, so fewer of their tops count as peaks.
const SPACING: float = 0.9
## Uplift of the first massif's middle over the land under it, before erosion. The others get a
## random share of it from MIN_SHARE to MAX_SHARE, so the first is the summit. Raising LIFT makes
## every massif taller and steeper. Raising the shares brings the other tops closer to the summit's
## height, and lowering them makes the summit stand out more.
const LIFT: float = 1.0
const MIN_SHARE: float = 0.7
const MAX_SHARE: float = 0.95
## Uplift every massif adds on top of its share of LIFT, so even the smallest stands above the hills.
const FOOT: float = 0.35
## Ridges per massif. More ridges give a massif more spurs and more sides to walk up, fewer give a
## long single range.
const MIN_RIDGES: int = 2
const MAX_RIDGES: int = 4
## Length of a ridge, as a share of the massif's radius. Longer ridges reach out and join the
## neighboring massifs, and shorter ones keep each massif a compact knot.
const MIN_RIDGE_LENGTH: float = 0.675
const MAX_RIDGE_LENGTH: float = 1.275
## Half the width of a ridge's uplift, as a share of the radius. At 0.55 the uplift rose so fast at
## a massif's foot that erosion left a ring of steep ground around it.
const RIDGE_WIDTH: float = 0.9
## Share of the uplift a ridge loses from the middle to its end. Lower values keep the ends high, so
## neighboring massifs join at high saddles.
const RIDGE_FALL: float = 0.85
## Soft ridges per massif, the ones that point most toward the island's middle. Their rock wears
## down to gentler slopes, Erosion.SOFT_SLOPE, so most massifs get a side the player can walk up
## without anything carved. With 2, seed 2 kept only 2 peaks.
const SOFT_RIDGES: int = 1
## Half the width of a soft ridge's band, as a share of the ridge's uplift width. At 0.7 the soft
## band took in much of the massif, more peaks were cut off, and seed 3 kept only 4 peaks.
const SOFT_ACROSS: float = 0.5
## How much noise moves a massif's width up and down by direction, as a share of the radius.
## Raising it gives ragged, lopsided massifs, and at 0 every ridge is the same width all round.
const OUTLINE_WARP: float = 0.45


## Raises 6 to 9 massifs on height, in place, on the largest land area, and fills softness with 1
## on their soft ridges and 0 elsewhere. Placement and the ridges take their numbers from a
## generator seeded from rng.
static func raise(height: PackedFloat32Array, rng: RandomNumberGenerator, softness: PackedFloat32Array = PackedFloat32Array()) -> void:
	var size: int = IslandData.SIZE
	softness.resize(size * size)
	var massif_rng := RandomNumberGenerator.new()
	massif_rng.seed = rng.randi()
	var outline := Height.make_noise(massif_rng, 0.004, 3)
	var land: PackedByteArray = MainIsland.generate(height)
	var island_middle := Vector2.ZERO
	var land_cells: int = 0
	for i: int in land.size():
		if land[i] == 1:
			island_middle += Vector2(i % size, i / size)
			land_cells += 1
	island_middle /= maxi(land_cells, 1)

	var points: Array[Vector2] = []
	var radii := PackedFloat32Array()
	var count: int = massif_rng.randi_range(MIN_COUNT, MAX_COUNT)
	for attempt: int in TRIES:
		if points.size() == count:
			break
		var p := Vector2(massif_rng.randf_range(EDGE, size - EDGE), massif_rng.randf_range(EDGE, size - EDGE))
		var radius: float = massif_rng.randf_range(MIN_RADIUS, MAX_RADIUS)
		if land[IslandData.index(int(p.x), int(p.y))] == 0 or _sea_within(height, p, radius * SEA_MARGIN):
			continue
		var apart: bool = true
		for q: int in points.size():
			if p.distance_to(points[q]) < SPACING * (radius + radii[q]):
				apart = false
				break
		if apart:
			points.append(p)
			radii.append(radius)

	for m: int in points.size():
		var middle: Vector2 = points[m]
		var radius: float = radii[m]
		var top: float = FOOT + LIFT * (1.0 if m == 0 else massif_rng.randf_range(MIN_SHARE, MAX_SHARE))
		var ends: Array[Vector2] = []
		var ridge_count: int = massif_rng.randi_range(MIN_RIDGES, MAX_RIDGES)
		var first: float = massif_rng.randf() * TAU
		for k: int in ridge_count:
			# Spread round the middle, with jitter so no massif is a regular star.
			var angle: float = first + TAU * k / ridge_count + massif_rng.randf_range(-0.5, 0.5)
			ends.append(middle + Vector2.from_angle(angle) * radius * massif_rng.randf_range(MIN_RIDGE_LENGTH, MAX_RIDGE_LENGTH))
		# The ridges that point most toward the island's middle are the soft ones.
		var facing := PackedFloat32Array()
		for k: int in ends.size():
			facing.append((ends[k] - middle).normalized().dot((island_middle - middle).normalized()))
		var ranked: Array = range(ends.size())
		ranked.sort_custom(func(a: int, b: int) -> bool: return facing[a] > facing[b])
		var soft := PackedByteArray()
		soft.resize(ends.size())
		for k: int in mini(SOFT_RIDGES, ends.size()):
			soft[ranked[k]] = 1
		# The uplift's width by direction from the middle, one entry per degree. Noise read by
		# direction never pinches a lobe off into a separate top, as noise read by position did.
		# Reading it once per degree instead of once per cell cut the massifs' time from about 0.7 s
		# to 0.4 s.
		var widths := PackedFloat32Array()
		widths.resize(360)
		for a: int in 360:
			var toward: Vector2 = Vector2.from_angle(TAU * a / 360.0) * 60.0
			widths[a] = radius * RIDGE_WIDTH * (1.0 + OUTLINE_WARP * outline.get_noise_2d(middle.x + toward.x, middle.y + toward.y))
		# Only the box around the ridges, out to the widest the uplift gets.
		var widest: float = radius * RIDGE_WIDTH * (1.0 + OUTLINE_WARP)
		var low: Vector2 = middle
		var high: Vector2 = middle
		for end: Vector2 in ends:
			low = low.min(end)
			high = high.max(end)
		for y: int in range(maxi(int(low.y - widest), 0), mini(int(high.y + widest) + 1, size)):
			for x: int in range(maxi(int(low.x - widest), 0), mini(int(high.x + widest) + 1, size)):
				var p := Vector2(x, y)
				var width: float = widths[int(fposmod((p - middle).angle(), TAU) * 360.0 / TAU) % 360]
				var uplift: float = 0.0
				var softer: float = 0.0
				for k: int in ends.size():
					var ridge: Vector2 = ends[k] - middle
					var along: float = clampf((p - middle).dot(ridge) / ridge.length_squared(), 0.0, 1.0)
					var across: float = p.distance_to(middle + ridge * along) / width
					uplift = maxf(uplift, smoothstep(1.0, 0.0, across) * (1.0 - RIDGE_FALL * along))
					if soft[k] == 1:
						softer = maxf(softer, smoothstep(SOFT_ACROSS, SOFT_ACROSS * 0.5, across))
				if uplift == 0.0:
					continue
				var i: int = IslandData.index(x, y)
				softness[i] = maxf(softness[i], softer)
				height[i] = maxf(height[i], lerpf(height[i], top, uplift))


## True when the sea lies within radius cells of q, checked on two rings of 24 directions.
static func _sea_within(height: PackedFloat32Array, q: Vector2, radius: float) -> bool:
	for a: int in 24:
		for r: float in [radius * 0.5, radius]:
			var c: Vector2 = (q + Vector2.from_angle(TAU * a / 24.0) * r).clamp(Vector2.ONE, Vector2.ONE * (IslandData.SIZE - 2))
			if height[IslandData.index(int(c.x), int(c.y))] <= 0.0:
				return true
	return false
