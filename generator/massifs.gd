class_name Massifs
## Part of generator step 1: the 5 to 10 big mountains the player surveys, each one peak.
## place() adds each massif's body to the smooth height before erosion, so rivers cut gullies into
## it. Height.crags() then calls lift() to raise each crown before its walls and ledges go on,
## sharpen() to put one pointed top on the center cell, and carve_way_up() to give each massif a
## walkable way to that top. The hills stay under Height.HILL_KNEE, so a massif stands out from them
## and only massifs reach the snow line.

## Fewest and most massifs an island gets. Peaks finds one peak per massif on the main island.
const MIN_COUNT: int = 5
const MAX_COUNT: int = 10
## Radius of a massif's foot in cells. Raising it gives broader, gentler massifs, lowering it
## steeper ones with less room for a way up.
const MIN_RADIUS: float = 55.0
const MAX_RADIUS: float = 90.0
## Two massifs keep their centers at least this share of their summed radii apart. Below about 0.8
## the feet overlap far enough that the saddle between them rises over the hills, and the lower one
## loses its prominence.
const SPACING: float = 0.9
## Height of the lowest massif's top against the tallest, in the units of Height.smooth. Above
## about 0.85 every massif nears the summit, and below 0.75 the lowest ones miss the snow line.
const LOWEST_TOP: float = 0.8
## Smooth height a massif's center must stand on, so it rises from inland and not off the coast.
const CENTER_GROUND: float = 0.15
## How far noise moves a massif's outline in and out, as a share of its radius. At 0 each massif
## is a round cone. Raising it gives lobed outlines with spurs.
const OUTLINE_WARP: float = 0.35
## Share of the radius where the body stops rising. Inside it the body is level and the cone of
## sharpen() makes the top. Raising it gives a broader crown on steeper sides. At 0.35 the sides of
## the smaller massifs were too steep to walk up anywhere.
const SHOULDER: float = 0.15
## How far below its top a massif's body stops before erosion. sharpen() builds the rest as the top.
const BODY_GAP: float = 0.1
## Slope of the cone over each top, in Height.smooth units per cell. Raising it makes the tops
## sharper. After the summit scaling it sets the slope at the summit to about 1.8 times this, so
## keep it under Walkability.MAX_SLOPE / 1.8, or the top can't be climbed.
const CONE_SLOPE: float = 0.014
## How far the cone falls before it levels out, in Height.smooth units. The cone cuts nothing more
## than this below a top, so the lower slopes keep their gullies and ledges.
const CONE_DEPTH: float = 0.15
## Height of the outcrops on the cone, as a share of how far the cone has fallen. At 0 the crown is
## a smooth cone. It must stay under 1, or an outcrop could rise above the top.
const CONE_CRAGS: float = 0.5
## Steepest slope of the way up, in Height.smooth units per cell. The summit scaling steepens a
## slope by up to 1.8 times, so 0.012 stays at about two thirds of Walkability.MAX_SLOPE.
const WAY_UP_SLOPE: float = 0.012
## Cells on each side of the way up's middle line that follow it fully, and cells over which it
## blends into the terrain beside it. At a half width under 2 a corner step could cut it.
const WAY_UP_HALF_WIDTH: float = 2.0
const WAY_UP_BLEND: float = 4.0
## Largest turn of the way up away from the island's center, in radians. At 0 every way up faces
## the middle of the island, and near PI some face the sea.
const WAY_UP_TURN: float = 1.0
## Radius of the crown that sharpen() fills up to the top, as a share of the massif's radius.
## Lowering it puts a steeper step under the top where a terrace cut the crown.
const CROWN: float = 0.3
## Radius of the lift that raises the middle of a massif up to its cone, as a share of its radius.
const TOP_RADIUS: float = 0.7
## How far sharpen() reaches from a center, in radii. It covers the warped outline and the cells
## where the cone still cuts. Lowering it below 1 + OUTLINE_WARP leaves a seam at the reach's edge.
const REACH: float = 2.0


## One massif: a center cell, a radius in cells, and the height of its top in Height.smooth units.
class Massif:
	var x: int
	var y: int
	var radius: float
	var top: float
	## Direction carve_way_up() leaves the top in, in radians from east toward south.
	var way_up: float


## Places the massifs on the land of a smooth height and adds their bodies to it. Returns them for
## sharpen(). The first massif placed is the tallest, at a top of 1.0.
static func place(height: PackedFloat32Array, rng: RandomNumberGenerator) -> Array[Massif]:
	var size: int = IslandData.SIZE
	var outline := Height.make_noise(rng, 0.01, 2)
	var count: int = rng.randi_range(MIN_COUNT, MAX_COUNT)
	# Massifs go only on the largest land, so none stands on an islet out of the player's reach.
	var mainland: PackedByteArray = MainIsland.generate(height)
	var massifs: Array[Massif] = []
	# Most random cells land in the sea, so this many tries finds room for every massif that fits.
	for attempt: int in 5000:
		if massifs.size() == count:
			break
		var x: int = rng.randi_range(0, size - 1)
		var y: int = rng.randi_range(0, size - 1)
		var radius: float = rng.randf_range(MIN_RADIUS, MAX_RADIUS)
		if mainland[IslandData.index(x, y)] == 0 or height[IslandData.index(x, y)] < CENTER_GROUND:
			continue
		var room: bool = true
		for other: Massif in massifs:
			if Vector2(x - other.x, y - other.y).length() < (radius + other.radius) * SPACING:
				room = false
				break
		if not room:
			continue
		var massif := Massif.new()
		massif.x = x
		massif.y = y
		massif.radius = radius
		# Below 1.0 for all but the first, so the summit is one massif and not a tie.
		massif.top = 1.0 if massifs.is_empty() else rng.randf_range(LOWEST_TOP, 0.97)
		# Toward the middle of the island, so the way up ends on land and not in the sea.
		massif.way_up = atan2(size / 2.0 - y, size / 2.0 - x) + rng.randf_range(-WAY_UP_TURN, WAY_UP_TURN)
		massifs.append(massif)

	for massif: Massif in massifs:
		var rise: float = maxf(massif.top - BODY_GAP - height[IslandData.index(massif.x, massif.y)], 0.0)
		var reach: int = ceili(massif.radius * (1.0 + OUTLINE_WARP))
		for y: int in range(maxi(massif.y - reach, 0), mini(massif.y + reach + 1, size)):
			for x: int in range(maxi(massif.x - reach, 0), mini(massif.x + reach + 1, size)):
				var t: float = _distance(massif, x, y) / (massif.radius * (1.0 + outline.get_noise_2d(x, y) * OUTLINE_WARP))
				if t < 1.0:
					height[IslandData.index(x, y)] += rise * smoothstep(1.0, SHOULDER, t)
	return massifs


## Raises the middle of each massif so its center stands a little over its top, whatever erosion
## left there. It runs before the crags, so the raised crown gets ledges and walls too.
static func lift(height: PackedFloat32Array, massifs: Array[Massif]) -> void:
	var size: int = IslandData.SIZE
	for massif: Massif in massifs:
		# The margin leaves the cone of sharpen() to shape the crown. Without it a crown eroded low came
		# up as a spike too steep to climb.
		var rise: float = maxf(massif.top - height[IslandData.index(massif.x, massif.y)], 0.0) + BODY_GAP
		# Spacing keeps lifts apart but for a sliver where two feet meet.
		var radius: float = massif.radius * TOP_RADIUS
		var reach: int = ceili(radius)
		for y: int in range(maxi(massif.y - reach, 0), mini(massif.y + reach + 1, size)):
			for x: int in range(maxi(massif.x - reach, 0), mini(massif.x + reach + 1, size)):
				height[IslandData.index(x, y)] += rise * smoothstep(radius, 0.0, _distance(massif, x, y))


## Cuts each massif under a cone over its center, so the massif has one pointed top at its center
## cell, and puts outcrops on the cone. Each cell takes the cone of the massif it lies deepest
## inside, so a massif's cone never cuts into its neighbor.
static func sharpen(height: PackedFloat32Array, massifs: Array[Massif], rock: FastNoiseLite) -> void:
	var size: int = IslandData.SIZE
	# Distance in radii to the nearest massif's center, and which massif that is.
	var nearest := PackedFloat32Array()
	nearest.resize(height.size())
	nearest.fill(INF)
	var owner := PackedByteArray()
	owner.resize(height.size())
	for m: int in massifs.size():
		var massif: Massif = massifs[m]
		var reach: int = ceili(massif.radius * REACH)
		for y: int in range(maxi(massif.y - reach, 0), mini(massif.y + reach + 1, size)):
			for x: int in range(maxi(massif.x - reach, 0), mini(massif.x + reach + 1, size)):
				var i: int = IslandData.index(x, y)
				var t: float = _distance(massif, x, y) / massif.radius
				if t < nearest[i]:
					nearest[i] = t
					owner[i] = m
	for m: int in massifs.size():
		var massif: Massif = massifs[m]
		# A terrace step can drop the lifted center below the top again, so the crown fills back up.
		var fill: float = maxf(massif.top - height[IslandData.index(massif.x, massif.y)], 0.0)
		var crown: float = massif.radius * CROWN
		var reach: int = ceili(massif.radius * REACH)
		for y: int in range(maxi(massif.y - reach, 0), mini(massif.y + reach + 1, size)):
			for x: int in range(maxi(massif.x - reach, 0), mini(massif.x + reach + 1, size)):
				var i: int = IslandData.index(x, y)
				if owner[i] != m:
					continue
				var d: float = _distance(massif, x, y)
				if d < crown:
					height[i] += fill * smoothstep(crown, 0.0, d)
				# Falls at CONE_SLOPE from the top and levels out CONE_DEPTH below it. It falls at every
				# distance, so no cell but the center can reach the top.
				var drop: float = CONE_DEPTH * (1.0 - exp(-d * CONE_SLOPE / CONE_DEPTH))
				# Outcrops on the cone, in proportion to its drop, so they never reach the top.
				var crag: float = rock.get_noise_2d(x, y) * CONE_CRAGS * drop * smoothstep(massif.radius, massif.radius * 0.5, d)
				height[i] = minf(height[i], massif.top - drop) + crag


## Carves a way up each massif, a band WAY_UP_HALF_WIDTH cells to each side of a line from the top
## out past the foot, whose slope never passes WAY_UP_SLOPE. Where the terrain beside it is gentle
## enough the way follows it, through a wall it cuts a notch or builds a ramp. Walls and the crown can
## close a massif off on every side, so this is what keeps every top in the player's reach.
static func carve_way_up(height: PackedFloat32Array, massifs: Array[Massif]) -> void:
	var size: int = IslandData.SIZE
	for massif: Massif in massifs:
		var direction := Vector2.from_angle(massif.way_up)
		var length: int = ceili(massif.radius * (1.0 + OUTLINE_WARP))
		# The way's height along its middle line, one sample per cell, limited in slope from the top out.
		var line := PackedFloat32Array([height[IslandData.index(massif.x, massif.y)]])
		for k: int in range(1, length + 1):
			var point: Vector2 = Vector2(massif.x, massif.y) + direction * k
			var x: int = clampi(roundi(point.x), 0, size - 1)
			var y: int = clampi(roundi(point.y), 0, size - 1)
			line.append(clampf(height[IslandData.index(x, y)], line[k - 1] - WAY_UP_SLOPE, line[k - 1] + WAY_UP_SLOPE))
		var reach: int = length + ceili(WAY_UP_HALF_WIDTH + WAY_UP_BLEND)
		for y: int in range(maxi(massif.y - reach, 0), mini(massif.y + reach + 1, size)):
			for x: int in range(maxi(massif.x - reach, 0), mini(massif.x + reach + 1, size)):
				var offset := Vector2(x - massif.x, y - massif.y)
				var along: float = offset.dot(direction)
				var across: float = absf(offset.cross(direction))
				# Not at along 0, where the way stands as high as the top.
				if along <= 0.0 or along > length or across > WAY_UP_HALF_WIDTH + WAY_UP_BLEND:
					continue
				var k: int = mini(floori(along), length - 1)
				var way: float = lerpf(line[k], line[k + 1], along - k)
				# Fades out over the last cells, where the line has met the terrain again.
				var weight: float = smoothstep(WAY_UP_HALF_WIDTH + WAY_UP_BLEND, WAY_UP_HALF_WIDTH, across) \
					* smoothstep(length, length - WAY_UP_BLEND * 2.0, along)
				var i: int = IslandData.index(x, y)
				height[i] = lerpf(height[i], way, weight)


## Distance from a massif's center to cell x, y, in cells.
static func _distance(massif: Massif, x: int, y: int) -> float:
	return Vector2(x - massif.x, y - massif.y).length()
