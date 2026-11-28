class_name RunStats
extends RefCounted
## What a run achieved, recorded when the player ends it at the summit varde, before the final survey
## and reveal add anything. The end screen shows it.

## Shares of the main island's cells the player saw or surveyed, from 0 to 1. Surveyed cells count as
## seen too.
var seen_share: float = 0.0
var surveyed_share: float = 0.0
## Peaks the player surveyed, each of which got one of their vardes.
var vardes_built: int = 0
## Old vardes the player came within reach of.
var vardes_found: int = 0
var island_seed: int = 0


## The stats of a run on island, from what knowledge holds now and the two counts.
static func record(island: IslandData, knowledge: Knowledge, built: int, found: int) -> RunStats:
	var stats := RunStats.new()
	var land: int = 0
	var seen: int = 0
	var surveyed: int = 0
	for cell: int in island.main_island.size():
		if island.main_island[cell] == 0:
			continue
		land += 1
		var level: int = knowledge.levels[cell]
		if level >= Knowledge.Level.SEEN:
			seen += 1
		if level == Knowledge.Level.SURVEYED:
			surveyed += 1
	stats.seen_share = float(seen) / maxi(land, 1)
	stats.surveyed_share = float(surveyed) / maxi(land, 1)
	stats.vardes_built = built
	stats.vardes_found = found
	stats.island_seed = island.island_seed
	return stats
