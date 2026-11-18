extends "res://tests/test_case.gd"


func test_marking_raises_a_level_and_never_lowers_it() -> void:
	var knowledge := Knowledge.new()
	expect(knowledge.levels[5] == Knowledge.Level.UNKNOWN, "a new cell is not unknown")
	knowledge.mark(5, Knowledge.Level.SEEN)
	expect(knowledge.levels[5] == Knowledge.Level.SEEN, "marking seen left the cell at %d" % knowledge.levels[5])
	knowledge.mark(5, Knowledge.Level.SURVEYED)
	expect(knowledge.levels[5] == Knowledge.Level.SURVEYED, "marking surveyed left the cell at %d" % knowledge.levels[5])
	knowledge.mark(5, Knowledge.Level.SEEN)
	knowledge.mark(5, Knowledge.Level.UNKNOWN)
	expect(knowledge.levels[5] == Knowledge.Level.SURVEYED, "a lower mark lowered the cell to %d" % knowledge.levels[5])


func test_mark_all_raises_every_cell_and_keeps_higher_ones() -> void:
	var knowledge := Knowledge.new()
	knowledge.mark(7, Knowledge.Level.SURVEYED)
	knowledge.mark_all(Knowledge.Level.SEEN)
	expect(knowledge.levels[7] == Knowledge.Level.SURVEYED, "mark_all lowered a surveyed cell")
	expect(knowledge.levels[0] == Knowledge.Level.SEEN and knowledge.levels[knowledge.levels.size() - 1] == Knowledge.Level.SEEN, "mark_all missed an end cell")
	knowledge.mark_all(Knowledge.Level.SURVEYED)
	expect(knowledge.levels.count(Knowledge.Level.SURVEYED) == knowledge.levels.size(), "some cell is not surveyed after mark_all")


func test_a_cell_clears_from_the_time_it_was_first_seen() -> void:
	var knowledge := Knowledge.new()
	expect(knowledge.revealed_at(3) == Knowledge.NEVER, "an unknown cell has a reveal time")
	knowledge.now = 5.0
	knowledge.mark(3, Knowledge.Level.SEEN)
	knowledge.now = 9.0
	knowledge.mark(3, Knowledge.Level.SURVEYED)
	expect(knowledge.revealed_at(3) == 5.0, "surveying moved the reveal time to %f" % knowledge.revealed_at(3))
	knowledge.mark_all(Knowledge.Level.SURVEYED, Knowledge.LONG_AGO)
	expect(knowledge.revealed_at(3) == 5.0 and knowledge.revealed_at(4) == Knowledge.LONG_AGO, "mark_all gave the wrong reveal times")


func test_mark_cells_starts_clearing_unknown_cells_only() -> void:
	var knowledge := Knowledge.new()
	knowledge.mark(1, Knowledge.Level.SEEN, 2.0)
	knowledge.mark_cells(PackedInt32Array([1, 2]), Knowledge.Level.SEEN, 7.0)
	expect(knowledge.revealed_at(1) == 2.0 and knowledge.revealed_at(2) == 7.0, "mark_cells gave reveal times %f and %f" % [knowledge.revealed_at(1), knowledge.revealed_at(2)])
