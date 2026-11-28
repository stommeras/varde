extends "res://tests/test_case.gd"


func test_shares_count_only_the_main_island() -> void:
	var island := IslandData.new()
	island.island_seed = 7
	island.main_island.resize(IslandData.SIZE * IslandData.SIZE)
	for cell: int in 4:
		island.main_island[cell] = 1
	var knowledge := Knowledge.new()
	knowledge.mark(0, Knowledge.Level.SURVEYED)
	knowledge.mark(1, Knowledge.Level.SEEN)
	knowledge.mark(10, Knowledge.Level.SURVEYED)
	var stats := RunStats.record(island, knowledge, 3, 5)
	expect(is_equal_approx(stats.seen_share, 0.5), "seen share is %f" % stats.seen_share)
	expect(is_equal_approx(stats.surveyed_share, 0.25), "surveyed share is %f" % stats.surveyed_share)
	expect(stats.vardes_built == 3 and stats.vardes_found == 5 and stats.island_seed == 7, "the counts or the seed are lost")


func test_the_summit_has_its_texts() -> void:
	for key: String in ["FINISH_RUN", "CONFIRM_FINISH"]:
		expect(TranslationServer.translate(key) != key, "%s has no text" % key)
