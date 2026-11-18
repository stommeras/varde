class_name Height
## Generator step 1: layered noise, pulled down toward the edges so the island sits in the sea.
## It runs in two halves around the erosion step: smooth() makes the lowland and hills, Massifs adds
## the mountains for the rivers to cut, and crags() adds rock detail and cliffs to what is left, so
## the cliffs follow the valley walls.

## Raises land heights to this power, so most land is lowland and the peaks stand out.
const PEAK_SHARPNESS: float = 1.8
## Height of the hills the mountain noise raises, in the units of smooth(). Massifs.place() adds the
## big mountains, so these stay small. Raising it gives more and higher hills.
const HILLS: float = 0.1
## Base height of the land before the falloff. Raising it grows the island and the hills with it.
const LAND: float = 0.3
## Hills rise at HILL_SQUASH of their rate above HILL_KNEE, so they stay under about 0.55 and far
## from the massif tops at 0.8 to 1.0. That keeps hills out of the snow and out of Peaks.
const HILL_KNEE: float = 0.35
const HILL_SQUASH: float = 0.4

## Only high ground gets rock detail and cliffs, which leaves them to the massifs. Ruggedness fades
## in as the eroded height rises from RUGGED_FROM to RUGGED_TO, against a summit of 1.0 before
## scaling. Lowering either value toward the hills' 0.55 gives the hills walls too.
const RUGGED_FROM: float = 0.5
const RUGGED_TO: float = 0.8
## Height of the rock detail on rugged mountains, in the same units as the noise sum. Raising it
## gives craggier tops and more small peaks, lowering it rounds the mountains toward smooth domes.
const ROCK: float = 0.2
## Height of one terrace step, the ledge and the cliff above it. Raising it gives fewer and
## taller cliffs, lowering it gives many thin bands that read as stacked rings, as at 0.15.
const BAND: float = 0.22
## Share of each step taken by the cliff face. Lowering it makes cliffs steeper and ledges wider.
## At 0.3 most faces stayed under the cliff threshold, so the massifs had ledges but few walls.
const RISER: float = 0.1
## How far noise moves the steps up and down, in steps. Below about 1 the ledges line up into
## level rings around each mountain, above that they wander and break apart.
const STRATA_WARP: float = 1.5
## How much of the terraced height replaces the smooth height on a rugged cliff side. At 1 the
## ledges are flat, and lower values tilt them back toward the slope.
const TERRACE: float = 1.0


## The smooth island before erosion and before the massifs: lowland, hills and the sea. Hills stay
## under about 0.55, and the sea floor is negative. Each noise layer takes its seed from rng, in a
## fixed order.
static func smooth(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var size: int = IslandData.SIZE
	# Base noise stops at 3 octaves, so its finest detail is about 30 cells wide. Each octave more
	# halves that width and puts bumps on every slope, which the 3D view shows as noise (#31).
	var base := make_noise(rng, 0.004, 3)
	# One bump of the mask is one hill. Raising the frequency gives more and smaller hills, lowering it
	# fewer and larger.
	var mountains := make_noise(rng, 0.005, 2)
	# Bends the falloff so the coast isn't a rounded square.
	var coast := make_noise(rng, 0.002, 3)

	var height := PackedFloat32Array()
	height.resize(size * size)
	var half: float = (size - 1) / 2.0
	for y: int in size:
		for x: int in size:
			var dx: float = (x - half) / half
			var dy: float = (y - half) / half
			# 0 at the center, 1 at the middle of each edge, 2 in the corners, plus coast noise.
			var falloff: float = dx * dx + dy * dy + coast.get_noise_2d(x, y) * 0.5
			var mask: float = maxf(mountains.get_noise_2d(x, y) * 2.0 + 0.4, 0.0)
			# Each hill is the mask's bump. The smoothstep starts it with zero slope at the mask's edge,
			# so the hill meets the lowland without a crease.
			# The last term sinks the outer 15% of the map, so the edge is sea whatever the noise does.
			var h: float = LAND + base.get_noise_2d(x, y) * 0.35 \
				+ mask * smoothstep(0.0, 0.6, mask) * HILLS \
				- falloff * 1.1 \
				- smoothstep(0.85, 1.0, maxf(absf(dx), absf(dy))) * 2.0
			# Hills above the knee rise at a fraction of the rate, so none comes near a massif.
			height[IslandData.index(x, y)] = h if h < HILL_KNEE else HILL_KNEE + (h - HILL_KNEE) * HILL_SQUASH
	return height


## Adds rock detail and cliffs to the high ground of a smooth height, after erosion, and scales land
## so the summit is exactly 1.0. Each noise layer takes its seed from rng, in a fixed order.
static func crags(smooth_height: PackedFloat32Array, massifs: Array[Massifs.Massif], rng: RandomNumberGenerator) -> PackedFloat32Array:
	var size: int = IslandData.SIZE
	# Rock detail on rugged mountains. 3 octaves from 0.012 makes features 20 to 80 cells wide,
	# coarser than the bumps #31 removed.
	var rock := make_noise(rng, 0.012, 3)
	# Moves the terrace steps up and down, so the ledges don't form level rings. Raising the
	# frequency makes the ledges wander over shorter distances, lowering it gives longer level runs.
	# At 0.02 each ledge carried the warp as bumps about 50 cells wide.
	var strata := make_noise(rng, 0.006, 2)
	# Turns the terraces on and off across a mountain, so some sides are cliffs and others slopes.
	# Raising the frequency gives smaller patches of cliff, lowering it gives whole cliffy sides.
	# At 0.008 a patch was wider than a small mountain, so a whole top could turn to cliff and stand
	# as a flat-topped box with a cliff on every side (seed 3).
	var cliffs := make_noise(rng, 0.016, 2)

	var height: PackedFloat32Array = smooth_height.duplicate()
	Massifs.lift(height, massifs)
	var highest: float = 0.0
	for y: int in size:
		for x: int in size:
			var i: int = IslandData.index(x, y)
			var h: float = height[i]
			var rugged: float = smoothstep(RUGGED_FROM, RUGGED_TO, h)
			if rugged > 0.0:
				h += rock.get_noise_2d(x, y) * ROCK * rugged
				var shift: float = strata.get_noise_2d(x, y) * BAND * STRATA_WARP
				# About 94% of each massif gets some cliff and 61% full cliff, for walls on most sides.
				# Before the massifs, 90% closed the ledges into rings round each mountain, like a layer
				# cake, but the strata warp and the outcrops on a massif break the rings up. Moving both
				# edges up gives fewer walls.
				var cliff: float = smoothstep(-0.5, -0.1, cliffs.get_noise_2d(x, y))
				h = lerpf(h, _terrace(h + shift) - shift, rugged * cliff * TERRACE)
				height[i] = h

	Massifs.sharpen(height, massifs, rock)
	Massifs.carve_way_up(height, massifs)
	for h: float in height:
		# Read back the stored 32-bit value, so dividing by it gives exactly 1.0.
		highest = maxf(highest, h)

	# Scale land so the summit is exactly 1.0, and leave the sea floor as it is.
	for i: int in height.size():
		if height[i] > 0.0:
			height[i] = pow(height[i] / highest, PEAK_SHARPNESS)
	return height


## Steps v into ledges BAND high. Each step stays flat for most of its width and rises over the
## last RISER share, with a smoothstep so the cliff meets the ledge without a crease.
static func _terrace(v: float) -> float:
	var t: float = v / BAND
	var step: float = floorf(t)
	return (step + smoothstep(1.0 - RISER, 1.0, t - step)) * BAND


## Simplex noise with fractal octaves, seeded from rng. Other steps use it for their own layers.
static func make_noise(rng: RandomNumberGenerator, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise
