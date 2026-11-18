class_name Knowledge
## What the player knows about each cell of an island: unknown, seen or surveyed. The shaders read it
## as an R8 texture, so fog and the map can follow it. A level only goes up, never down.

enum Level { UNKNOWN, SEEN, SURVEYED }

## One byte per cell, a Level, in the same order as IslandData's arrays.
var levels := PackedByteArray()
## The levels as an R8 texture on the island's grid. It shows the levels as of the last upload().
var texture: ImageTexture
var _image: Image
var _dirty: bool = false


func _init() -> void:
	levels.resize(IslandData.SIZE * IslandData.SIZE)
	_image = Image.create_from_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_R8, levels)
	texture = ImageTexture.create_from_image(_image)


## Raises cell to level. A cell already at that level or higher stays as it is.
func mark(cell: int, level: Level) -> void:
	if levels[cell] < level:
		levels[cell] = level
		_dirty = true


## Raises every cell to level, for the debug view and god mode.
func mark_all(level: Level) -> void:
	# Not a call to mark() per cell, because a million GDScript calls hitch the frame.
	for cell: int in levels.size():
		if levels[cell] < level:
			levels[cell] = level
			_dirty = true


## Sends the levels to the texture if any changed since the last call. Call it once a frame at most,
## after all the marking, because every call that finds a change uploads the whole grid.
func upload() -> void:
	if not _dirty:
		return
	_dirty = false
	_image.set_data(IslandData.SIZE, IslandData.SIZE, false, Image.FORMAT_R8, levels)
	texture.update(_image)
