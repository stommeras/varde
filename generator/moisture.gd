class_name Moisture
## Generator step 2: a second noise layer, from 0.0 (driest cell) to 1.0 (wettest cell).

## Cycles per cell. Raising it gives smaller, more scattered wet and dry patches.
const FREQUENCY: float = 0.003


## Takes the next seed from rng, so it must run after Height.
static func generate(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var noise := Height.make_noise(rng, FREQUENCY, 4)
	var size: int = IslandData.SIZE
	var moisture := PackedFloat32Array()
	moisture.resize(size * size)
	var lowest: float = INF
	var highest: float = -INF
	for y: int in size:
		for x: int in size:
			var i: int = IslandData.index(x, y)
			moisture[i] = noise.get_noise_2d(x, y)
			lowest = minf(lowest, moisture[i])
			highest = maxf(highest, moisture[i])
	# Fractal noise spans a different range on each seed. Stretching it to 0..1 keeps the
	# material thresholds meaning the same thing on every island.
	for i: int in moisture.size():
		moisture[i] = (moisture[i] - lowest) / (highest - lowest)
	return moisture
