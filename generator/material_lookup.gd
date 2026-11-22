class_name MaterialLookup
## Generator step 3: a lookup table from height and moisture to what the ground is made of.
## Cells at or below sea level are water. Values are Ramps.Terrain.

## Upper height of each band in TABLE, up from sea level. Land above the last value is the top band.
## Height._curve keeps the lowland low, and only the massifs rise above about 0.4. With rock from
## 0.35 and snow from 0.6, the massifs turned to bare rock from their feet up. Raising a value widens
## that band and pushes the ones above it up the slopes.
const HEIGHT_BANDS: Array[float] = [0.003, 0.08, 0.5, 0.75]
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
## Fewest cells a patch of snow needs, counting cells that touch at a corner. A smaller patch is a
## bump or a wet spot just over the snow line, and it takes the ground of the band below. On seed 0,
## patches of 16 to 28 cells lay as specks on bare rock, and the smallest real snowfield had 92.
## Raising it clears bigger patches off the lower peaks.
const SNOW_PATCH_CELLS: int = 32


## Returns a Ramps.Terrain value per cell from the height and moisture of the same cell.
static func generate(height: PackedFloat32Array, moisture: PackedFloat32Array) -> PackedByteArray:
	var material := PackedByteArray()
	material.resize(height.size())
	var snow := PackedInt32Array()
	for i: int in height.size():
		var h: float = height[i]
		if h <= 0.0:
			material[i] = Ramps.Terrain.WATER
			continue
		var row: int = _band(HEIGHT_BANDS, h)
		var column: int = _band(MOISTURE_BANDS, moisture[i])
		material[i] = TABLE[row][column]
		if material[i] == Ramps.Terrain.SNOW:
			snow.append(i)
	_clear_snow_specks(material, moisture, snow)
	return material


## Turns each patch of snow smaller than SNOW_PATCH_CELLS into the ground the band below the top one
## has at the same moisture. snow holds every snow cell of material.
static func _clear_snow_specks(material: PackedByteArray, moisture: PackedFloat32Array, snow: PackedInt32Array) -> void:
	var size: int = IslandData.SIZE
	var seen := PackedByteArray()
	seen.resize(material.size())
	for start: int in snow:
		if seen[start] == 1:
			continue
		seen[start] = 1
		var patch := PackedInt32Array([start])
		var head: int = 0
		while head < patch.size():
			var i: int = patch[head]
			head += 1
			# Land never reaches the grid's edge, so a snow cell's neighbors are always on the grid.
			for n: int in [i - size - 1, i - size, i - size + 1, i - 1, i + 1, i + size - 1, i + size, i + size + 1]:
				if seen[n] == 0 and material[n] == Ramps.Terrain.SNOW:
					seen[n] = 1
					patch.append(n)
		if patch.size() < SNOW_PATCH_CELLS:
			for i: int in patch:
				material[i] = TABLE[HEIGHT_BANDS.size() - 1][_band(MOISTURE_BANDS, moisture[i])]


## The index of the first band whose upper value is above value, or the top band past the last one.
static func _band(bands: Array[float], value: float) -> int:
	for band: int in bands.size():
		if value < bands[band]:
			return band
	return bands.size()
