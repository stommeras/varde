extends RefCounted
## Base for test files. Extend it by path, write methods named test_*, and call expect().

## Tests that check every island loop over seeds 0 to SEEDS - 1.
const SEEDS: int = 10

## Generated islands by seed, shared by every test in the run.
static var _islands: Dictionary[int, IslandData] = {}

var failures: PackedStringArray = []


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## The island for a seed, generated once per test run because each one takes about a second.
static func island(island_seed: int) -> IslandData:
	if not _islands.has(island_seed):
		_islands[island_seed] = IslandGenerator.generate(island_seed)
	return _islands[island_seed]
