class_name Notes
## Generator step 8, after the old vardes: the notes. The wreck's tells of the old vardes up the
## mountains, with no direction. The top varde of each line names the direction of the nearest
## higher peak and, where one lies near that peak, a feature it stands over, such as a lake at its
## foot or a river that runs off it. The note on the summit's line says no top stands higher. The
## words come from one ConfigFile per language, so another language is a new file in notes/.

## The language of the notes, the name of its file in notes/.
const LANGUAGE: String = "nb"
## The feature types a note can name, each a section key under [templates] in the language file.
const KINDS: Array[String] = ["lake", "river", "fork", "cove", "forest"]
## Most cells from the higher peak's top to a feature the note names. The feature needn't be in
## sight from the varde. Raising it names features further from the peak, which then point less
## clearly at it, and lowering it leaves more notes with the direction alone.
const LANDMARK_REACH: float = 80.0
## Fewest cells a lake needs to be "et vann". A smaller one is "et tjern".
const TARN_CELLS: int = 400
## Fewest cells a river needs to be "ei elv". A shorter one is "en bekk".
const BROOK_CELLS: int = 80


## The file that holds the notes of language.
static func path(language: String) -> String:
	return "res://notes/%s.cfg" % language


## Fills data.notes with the wreck's note and the note of each line's top varde. rng picks the
## feature and the template.
static func write(data: IslandData, rng: RandomNumberGenerator, language: String = LANGUAGE) -> void:
	data.notes = {}
	var file := ConfigFile.new()
	file.load(path(language))
	if data.wreck >= 0:
		data.notes[data.wreck] = _fill(file, "wreck", {}, rng)
	var opening: String = file.get_value("note", "varde")
	var words: Array = file.get_value("compass", "words")
	for i: int in data.vardes.size():
		var top: int = data.varde_peaks[i]
		if i < data.vardes.size() - 1 and data.varde_peaks[i + 1] == top:
			continue
		var higher: int = Trail.higher_peak(data, top)
		var text: String
		if higher < 0:
			text = _fill(file, "summit", {}, rng)
		else:
			var slots: Dictionary = {"direction": words[compass(top, higher)]}
			var landmark: PackedStringArray = _landmark(data, higher, rng)
			if landmark.is_empty():
				text = _fill(file, "higher", slots, rng)
			else:
				var forms: Array = file.get_value("nouns", landmark[1])
				slots["feature"] = forms[0]
				slots["the_feature"] = forms[1]
				text = _fill(file, landmark[0], slots, rng)
		data.notes[data.vardes[i]] = opening + text


## The nearest of the 8 compass directions from cell from to cell to, 0 for north and counting
## clockwise, so 2 is east. North is up on the map, whichever way the camera faces.
static func compass(from: int, to: int) -> int:
	var size: int = IslandData.SIZE
	var east: int = to % size - from % size
	var north: int = from / size - to / size
	return posmod(roundi(atan2(east, north) / (PI / 4.0)), 8)


## The kind and noun of a feature within LANDMARK_REACH of the top peak, picked by rng, or an empty
## array if none lies there. Each kind counts once, so an island with many rivers doesn't name
## rivers in nearly every note.
static func _landmark(data: IslandData, peak: int, rng: RandomNumberGenerator) -> PackedStringArray:
	var at: Vector2 = IslandData.center(peak)
	var found: Array[PackedStringArray] = []
	for lake: PackedInt32Array in data.lakes:
		if _near(lake, at):
			found.append(PackedStringArray(["lake", "tarn" if lake.size() < TARN_CELLS else "lake"]))
			break
	for river: PackedInt32Array in data.rivers:
		if data.main_island[river[0]] == 1 and _near(river, at):
			found.append(PackedStringArray(["river", "brook" if river.size() < BROOK_CELLS else "river"]))
			break
	if _near(data.river_forks, at):
		found.append(PackedStringArray(["fork", "fork"]))
	if _near(data.coves, at):
		found.append(PackedStringArray(["cove", "cove"]))
	if _near(data.forest, at):
		found.append(PackedStringArray(["forest", "forest"]))
	return found[rng.randi_range(0, found.size() - 1)] if not found.is_empty() else PackedStringArray()


static func _near(cells: PackedInt32Array, at: Vector2) -> bool:
	for cell: int in cells:
		if IslandData.center(cell).distance_to(at) <= LANDMARK_REACH:
			return true
	return false


## A template for kind from file, picked by rng, with slots filled in.
static func _fill(file: ConfigFile, kind: String, slots: Dictionary, rng: RandomNumberGenerator) -> String:
	var templates: Array = file.get_value("templates", kind)
	var template: String = templates[rng.randi_range(0, templates.size() - 1)]
	return template.format(slots)
