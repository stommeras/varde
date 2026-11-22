class_name Height
## Generator step 1: layered noise, pulled down toward the edges so the island sits in the sea, with
## the massifs raised on it. It runs in two halves around the erosion step: smooth() makes the
## lowland, the hills and the massifs for the rivers to cut, and crags() adds rock detail to what is
## left and scales it.

## Raises low land heights to this power, so most land is lowland. From 0.6 up the curve turns
## straight, see _curve().
const PEAK_SHARPNESS: float = 1.8
## How much of the old mountain noise is left, as hills between the massifs. At 1 the noise made
## mountains of its own, which rose as high as the massifs and blurred which tops were peaks.
## Raising it gives taller hills, lowering it flatter lowland.
const HILLS: float = 0.35
## Height of the ridged rock detail on high ground, against a summit of 1.0. Raising it roughens
## the mountainsides and adds small tops, lowering it leaves the smooth eroded slopes.
const ROCK: float = 0.012
## Height of the land before the falloff. Raising it grows the island. Main had 0.15 with the
## mountain noise at full strength, and turning that noise down to hills shrank the land to 11 to
## 15% of the map.
const LAND: float = 0.25


## The smooth island before erosion: lowland, hills, the massifs, and the sea. Heights run to about
## 1.35 on the tallest massif, and the sea floor is negative. Each noise layer takes its seed from
## rng, in a fixed order. Massifs fills softness with the soft rock for the erosion step.
static func smooth(rng: RandomNumberGenerator, softness: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	var size: int = IslandData.SIZE
	# Base noise stops at 3 octaves, so its finest detail is about 30 cells wide. Each octave more
	# halves that width and puts bumps on every slope, which the 3D view shows as noise (#31).
	var base := make_noise(rng, 0.004, 3)
	# One bump of the mask is one hill.
	var hills := make_noise(rng, 0.005, 2)
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
			var mask: float = maxf(hills.get_noise_2d(x, y) * 2.0 + 0.4, 0.0) * HILLS
			# The smoothstep starts each hill with zero slope at the mask's edge, so it meets the
			# lowland without a crease.
			# The last term sinks the outer 15% of the map, so the edge is sea whatever the noise does.
			height[IslandData.index(x, y)] = LAND + base.get_noise_2d(x, y) * 0.35 \
				+ mask * smoothstep(0.0, 0.6, mask) * 0.5 \
				- falloff * 1.1 \
				- smoothstep(0.85, 1.0, maxf(absf(dx), absf(dy))) * 2.0
	Massifs.raise(height, rng, softness)
	return height


## Adds ridged rock detail to the high ground of an eroded height, and scales land so the summit is
## exactly 1.0. The detail's noise takes its seed from rng.
static func crags(eroded: PackedFloat32Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var size: int = IslandData.SIZE
	# Ridged noise 16 cells wide gives rock ribs and gullies finer than the erosion grid can.
	var rock := make_noise(rng, 0.06, 3)
	rock.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var height: PackedFloat32Array = eroded.duplicate()
	_scale(height)
	for y: int in size:
		for x: int in size:
			var i: int = IslandData.index(x, y)
			if height[i] > 0.0:
				# Never below the sea, so the coast stays where erosion left it.
				height[i] = maxf(height[i] + rock.get_noise_2d(x, y) * ROCK * smoothstep(0.15, 0.5, height[i]), 0.001)
	# The detail moved the top a little, so scale once more, straight this time.
	_scale(height, false)
	return height


## Scales land in place so the highest cell is 1.0, through _curve() if curved. The sea floor stays
## as it is.
static func _scale(height: PackedFloat32Array, curved: bool = true) -> void:
	var highest: float = 0.0
	for h: float in height:
		highest = maxf(highest, h)
	for i: int in height.size():
		if height[i] > 0.0:
			# Divides by the stored float32, so the highest cell lands on exactly 1.0.
			height[i] = _curve(height[i] / highest) if curved else height[i] / highest


## Flattens the lowland like a power of PEAK_SHARPNESS, and is straight from 0.6 to the top. A
## plain power made the mountainsides up to 1.8 times as steep near the top, too steep to walk.
static func _curve(h: float) -> float:
	return h * lerpf(pow(h, PEAK_SHARPNESS - 1.0), 1.0, smoothstep(0.0, 0.6, h))


## Simplex noise with fractal octaves, seeded from rng. Other steps use it for their own layers.
static func make_noise(rng: RandomNumberGenerator, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise
