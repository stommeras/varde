class_name Height
## Generator step 1: layered noise, pulled down toward the edges so the island sits in the sea.

## Raises land heights to this power, so most land is lowland and the peaks stand out.
const PEAK_SHARPNESS: float = 1.8


## Each noise layer takes its seed from rng, in a fixed order.
static func generate(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var size: int = IslandData.SIZE
	var base := make_noise(rng, 0.004, 6)
	# Ridged noise gives sharp crests, and a slow mask decides where the mountains rise.
	var ridges := make_noise(rng, 0.005, 5)
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var mountains := make_noise(rng, 0.003, 2)
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
			var mask: float = clampf(mountains.get_noise_2d(x, y) * 2.0 + 0.4, 0.0, 1.0)
			# The last term sinks the outer 15% of the map, so the edge is sea whatever the noise does.
			var h: float = 0.15 + base.get_noise_2d(x, y) * 0.35 \
				+ (ridges.get_noise_2d(x, y) * 0.5 + 0.5) * mask * 0.8 \
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
