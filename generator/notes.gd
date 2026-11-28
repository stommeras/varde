class_name Notes
## Generator step 8, after the old vardes: the notes. The wreck's note tells of the old vardes up
## the mountains and gives no direction. The top varde of each line names the direction of the nearest
## higher peak and, where one lies near that peak, a feature beside it, such as a lake at its foot or
## a river that springs on it. The note on the summit's line says no top stands higher.
## A note is a direction sentence, then a feature sentence, each picked from a list. On one island
## the writer picks a sentence it hasn't used yet and a kind of feature it hasn't named yet, while
## any are left, so 4 to 6 notes on an island don't read alike.

## The language of the notes, the name of its file in notes/.
const LANGUAGE: String = "nb"
## Most cells from the higher peak's top to a feature the note names. The feature needn't be in
## sight from the varde. Raising it names features further from the peak, which then point less
## clearly at it, and lowering it leaves more notes with the direction alone.
const LANDMARK_REACH: float = 80.0
## Fewest cells a lake needs to be "et vann". A smaller one is "et tjern". Raising it calls more
## lakes tarns.
const TARN_CELLS: int = 400
## Fewest cells a river needs to be "ei elv". A shorter one is "en bekk". Raising it calls more
## rivers brooks.
const BROOK_CELLS: int = 80


## The file that holds the notes of language.
static func path(language: String) -> String:
	return "res://notes/%s.cfg" % language


## Fills data.notes with the wreck's note and the note of each line's top varde. rng picks the
## feature and the sentences.
static func write(data: IslandData, rng: RandomNumberGenerator) -> void:
	data.notes = {}
	var file := ConfigFile.new()
	if file.load(path(LANGUAGE)) != OK:
		push_error("Notes: can't load %s" % path(LANGUAGE))
		return
	# The sentences and feature kinds used on this island so far.
	var used: Dictionary[String, bool] = {}
	if data.wreck >= 0:
		data.notes[data.wreck] = _fill(file, "wreck", {}, used, rng)
	var opening: String = file.get_value("varde", "opening")
	var words: Array = file.get_value("compass", "words")
	for i: int in data.vardes.size():
		var top: int = data.varde_peaks[i]
		if i < data.vardes.size() - 1 and data.varde_peaks[i + 1] == top:
			continue
		var higher: int = Trail.higher_peak(data, top)
		var text: String
		if higher < 0:
			text = _fill(file, "summit", {}, used, rng)
		else:
			var slots: Dictionary = {"direction": words[compass(top, higher)]}
			text = _fill(file, "direction", slots, used, rng)
			var found: Dictionary[String, String] = _landmarks(data, higher)
			if not found.is_empty():
				var kind: String = _pick(found.keys(), used, rng)
				var forms: Array = file.get_value("nouns", found[kind])
				slots["feature"] = forms[0]
				slots["the_feature"] = forms[1]
				text += " " + _fill(file, kind, slots, used, rng)
		data.notes[data.vardes[i]] = opening + text

## The nearest of the 8 compass directions from cell from to cell to, 0 for north and counting
## clockwise, so 2 is east. North is up on the map, whichever way the camera faces.
static func compass(from: int, to: int) -> int:
	var size: int = IslandData.SIZE
	var east: int = to % size - from % size
	var north: int = from / size - to / size
	return posmod(roundi(atan2(east, north) / (PI / 4.0)), 8)


## The noun of each kind of feature within LANDMARK_REACH of the top peak, by kind. A river counts
## when it springs within reach, so it runs off the peak. Each kind counts once, so an island with
## many rivers doesn't name rivers in nearly every note.
static func _landmarks(data: IslandData, peak: int) -> Dictionary[String, String]:
	var at: Vector2 = IslandData.center(peak)
	var found: Dictionary[String, String] = {}
	for lake: PackedInt32Array in data.lakes:
		if _near(lake, at):
			found["lake"] = "tarn" if lake.size() < TARN_CELLS else "lake"
			break
	for river: PackedInt32Array in data.rivers:
		if IslandData.center(river[0]).distance_to(at) <= LANDMARK_REACH:
			found["river"] = "brook" if river.size() < BROOK_CELLS else "river"
			break
	if _near(data.river_forks, at):
		found["fork"] = "fork"
	if _near(data.coves, at):
		found["cove"] = "cove"
	if _near(data.forest, at):
		found["forest"] = "forest"
	return found

static func _near(cells: PackedInt32Array, at: Vector2) -> bool:
	for cell: int in cells:
		if IslandData.center(cell).distance_to(at) <= LANDMARK_REACH:
			return true
	return false


static func _fill(file: ConfigFile, kind: String, slots: Dictionary, used: Dictionary[String, bool], rng: RandomNumberGenerator) -> String:
	return _pick(file.get_value("templates", kind), used, rng).format(slots)


## One of options picked by rng, from those not in used while any are left, and marks it used.
static func _pick(options: Array, used: Dictionary[String, bool], rng: RandomNumberGenerator) -> String:
	var fresh: Array = options.filter(func(option: String) -> bool: return not used.has(option))
	var pool: Array = fresh if not fresh.is_empty() else options
	var picked: String = pool[rng.randi_range(0, pool.size() - 1)]
	used[picked] = true
	return picked
