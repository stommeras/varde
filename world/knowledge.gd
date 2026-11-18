class_name Knowledge
## What the player knows about each cell of an island: unknown, seen or surveyed. The shaders read it
## as textures, so fog and the map can follow it. A level only goes up, never down.

enum Level { UNKNOWN, SEEN, SURVEYED }

## The reveal time of a cell that is still unknown. Far enough ahead that the shader's fog never clears.
const NEVER: float = 1e9
## A reveal time far enough back that the fog has already cleared, for land that should show at once,
## such as the title backdrop.
const LONG_AGO: float = -1e9

## One byte per cell, a Level, in the same order as IslandData's arrays.
var levels := PackedByteArray()
## Seconds on the clock `now` at which each cell first left UNKNOWN, or NEVER, as one 32-bit float per
## cell. The terrain shader clears the fog from a cell over the second after it. Bytes rather than a
## PackedFloat32Array, because converting the array for each upload took 0.8 ms. Read it with revealed_at().
var reveal_bytes := PackedByteArray()
## The levels as an R8 texture on the island's grid. It shows the levels as of the last upload().
var texture: ImageTexture
## reveal_bytes as an RF texture on the island's grid, as of the last upload().
var reveal_texture: ImageTexture
## Seconds the island has been shown, which IslandTerrain advances each frame. A clock of its own
## instead of the engine's ticks, so the fog's clearing pauses with the game and follows a movie's fixed frame rate.
var now: float = 0.0
## Counts the uploads that changed the textures, so the map screen can redraw only when it rises.
var version: int = 0
var _image: Image
var _reveal_image: Image
var _dirty: bool = false
## True when a reveal time changed since the last upload. Kept apart from _dirty, because surveying
## changes only levels, and the reveal grid is 4 of the 5 MB.
var _reveal_dirty: bool = false


func _init() -> void:
	levels.resize(IslandData.SIZE * IslandData.SIZE)
	var never := PackedFloat32Array()
	never.resize(levels.size())
	never.fill(NEVER)
	reveal_bytes = never.to_byte_array()
	_image = Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_R8, levels)
	texture = ImageTexture.create_from_image(_image)
	_reveal_image = Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_RF, reveal_bytes)
	reveal_texture = ImageTexture.create_from_image(_reveal_image)


## Raises cell to level. A cell already at that level or higher stays as it is. An unknown cell
## starts clearing its fog at time `at`.
func mark(cell: int, level: Level, at: float = now) -> void:
	if levels[cell] < level:
		if levels[cell] == Level.UNKNOWN:
			reveal_bytes.encode_float(cell * 4, at)
			_reveal_dirty = true
		levels[cell] = level
		_dirty = true


## Raises each of cells to level, like mark() on each but without a call per cell, which cost
## 1.4 ms for the 10,000 cells seen from the summit against 0.4 ms here. Unknown cells start
## clearing their fog at time `at`.
func mark_cells(cells: PackedInt32Array, level: Level, at: float = now) -> void:
	for cell: int in cells:
		if levels[cell] < level:
			if levels[cell] == Level.UNKNOWN:
				reveal_bytes.encode_float(cell * 4, at)
				_reveal_dirty = true
			levels[cell] = level
			_dirty = true


## The second on the clock `now` at which cell first left UNKNOWN, or NEVER.
func revealed_at(cell: int) -> float:
	return reveal_bytes.decode_float(cell * 4)


## Raises every cell to level, for the debug view, god mode and the title backdrop. Unknown cells
## start clearing their fog at time `at`.
func mark_all(level: Level, at: float = now) -> void:
	# Not a call to mark() per cell, because a million GDScript calls hitch the frame.
	for cell: int in levels.size():
		if levels[cell] < level:
			if levels[cell] == Level.UNKNOWN:
				reveal_bytes.encode_float(cell * 4, at)
				_reveal_dirty = true
			levels[cell] = level
			_dirty = true


## Sends the levels and reveal times to the textures if any changed since the last call. Call it
## once a frame at most, after all the marking, because every call that finds a change uploads a
## whole grid, 1 MB of levels and 4 MB of reveal times.
func upload() -> void:
	if not _dirty:
		return
	_dirty = false
	version += 1
	_image.set_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_R8, levels)
	texture.update(_image)
	if not _reveal_dirty:
		return
	_reveal_dirty = false
	_reveal_image.set_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_RF, reveal_bytes)
	reveal_texture.update(_reveal_image)
