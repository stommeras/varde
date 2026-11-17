class_name Height
## Generator step 1: layered noise, pulled down toward the edges so the island sits in the sea.

## Raises land heights to this power, so most land is lowland and the peaks stand out.
const PEAK_SHARPNESS: float = 1.8


## Each noise layer takes its seed from rng, in a fixed order.
static func generate(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var size: int = IslandData.SIZE
	# Base noise stops at 3 octaves, so its finest detail is about 30 cells wide. Each octave more
	# halves that width and puts bumps on every slope, which the 3D view shows as noise (#31).
	var base := make_noise(rng, 0.004, 3)
	# Ridged noise gives the crests that run off each top, and a slow mask decides where the
	# mountains rise. One octave gives a few long ridges about 200 cells apart. A second octave
	# fluted every flank with grooves and scooped bowls between them.
	var ridges := make_noise(rng, 0.005, 1)
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	# Bends the ridges, so they don't run in straight lines. Raising the amplitude bends them more.
	# The warp has no fractal octaves, because Godot's default of 5 adds small bumps everywhere.
	ridges.domain_warp_enabled = true
	ridges.domain_warp_frequency = 0.004
	ridges.domain_warp_amplitude = 60.0
	ridges.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_NONE
	# One bump of the mask is one mountain. Raising the frequency gives more and smaller mountains,
	# lowering it fewer and larger. 0.0035 gives 7 to 13 peaks with 15% prominence on seeds 0 to 9.
	var mountains := make_noise(rng, 0.0035, 2)
	# Bends the falloff so the coast isn't a rounded square.
	var coast := make_noise(rng, 0.002, 3)

	var height := PackedFloat32Array()
	height.resize(size * size)
	var half: float = (size - 1) / 2.0
	var highest: float = 0.0
	for y: int in size:
		for x: int in size:
			var dx: float = (x - half) / half
			var dy: float = (y - half) / half
			# 0 at the center, 1 at the middle of each edge, 2 in the corners, plus coast noise.
			var falloff: float = dx * dx + dy * dy + coast.get_noise_2d(x, y) * 0.5
			# The mask has no upper clamp, so it keeps rising to the middle of each mountain and the
			# ridge crest nearest that middle becomes the one clear top. A clamp at 1 made a plateau
			# where every crest reached the same height, a crown of equal tops.
			var mask: float = maxf(mountains.get_noise_2d(x, y) * 2.0 + 0.4, 0.0)
			# The ridges fade in over the mask's outer edge (0 to 0.6), so foothills stay smooth instead
			# of rising in grooves. Above 0.6 they grow with the mask, which keeps small mountains tall
			# enough to count as peaks.
			# The last term sinks the outer 15% of the map, so the edge is sea whatever the noise does.
			var h: float = 0.15 + base.get_noise_2d(x, y) * 0.35 \
				+ (ridges.get_noise_2d(x, y) * 0.5 + 0.5) * mask * smoothstep(0.0, 0.6, mask) * 0.8 \
				- falloff * 1.1 \
				- smoothstep(0.85, 1.0, maxf(absf(dx), absf(dy))) * 2.0
			var i: int = IslandData.index(x, y)
			height[i] = h
			# Read back the stored 32-bit value, so dividing by it gives exactly 1.0.
			highest = maxf(highest, height[i])

	# Scale land so the summit is exactly 1.0, and leave the sea floor as it is.
	for i: int in height.size():
		if height[i] > 0.0:
			height[i] = pow(height[i] / highest, PEAK_SHARPNESS)
	return height


## Simplex noise with fractal octaves, seeded from rng. Other steps use it for their own layers.
static func make_noise(rng: RandomNumberGenerator, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise
