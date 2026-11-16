class_name MaterialLookup
## Generator step 3: a lookup table from height and moisture to what the ground is made of.
## Cells at or below sea level are water. Values are Ramps.Terrain.

## Upper height of each band in TABLE, up from sea level. Land above the last value is the top band.
## Heights pass through Height.PEAK_SHARPNESS, so half the land lies below 0.07 and only the top few percent above 0.6.
## Raising a value widens that band and pushes the ones above it up the slopes.
const HEIGHT_BANDS: Array[float] = [0.003, 0.08, 0.35, 0.6]
## Upper moisture of the dry and medium columns. Raising a value moves cells toward the drier column.
const MOISTURE_BANDS: Array[float] = [0.4, 0.62]
## One row per height band, one column per moisture band: dry, medium, wet.
const TABLE: Array = [
	[Ramps.Terrain.BEACH, Ramps.Terrain.BEACH, Ramps.Terrain.BEACH],
	[Ramps.Terrain.GRASS, Ramps.Terrain.FOREST, Ramps.Terrain.MARSH],
	[Ramps.Terrain.GRASS, Ramps.Terrain.FOREST, Ramps.Terrain.FOREST],
	[Ramps.Terrain.ROCK, Ramps.Terrain.ROCK, Ramps.Terrain.GRASS],
	# Dry peaks stay bare rock, so only some high peaks get snow.
	[Ramps.Terrain.ROCK, Ramps.Terrain.SNOW, Ramps.Terrain.SNOW],
]


## Returns a Ramps.Terrain value per cell from the height and moisture of the same cell.
static func generate(height: PackedFloat32Array, moisture: PackedFloat32Array) -> PackedByteArray:
	var material := PackedByteArray()
	material.resize(height.size())
	for i: int in height.size():
		var h: float = height[i]
		if h <= 0.0:
			material[i] = Ramps.Terrain.WATER
			continue
		var row: int = _band(HEIGHT_BANDS, h)
		var column: int = _band(MOISTURE_BANDS, moisture[i])
		material[i] = TABLE[row][column]
	return material


## The index of the first band whose upper value is above value, or the top band past the last one.
static func _band(bands: Array[float], value: float) -> int:
	for band: int in bands.size():
		if value < bands[band]:
			return band
	return bands.size()
