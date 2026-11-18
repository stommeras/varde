extends "res://tests/test_case.gd"


## The title screen and the debug view both read their seed fields with seed_from().
func test_seed_from_takes_numbers_as_they_are_and_hashes_other_text() -> void:
	expect(IslandLoader.seed_from(" 123 ") == 123, "a number is not used as it is")
	expect(IslandLoader.seed_from("-5") == -5, "a negative number is not used as it is")
	expect(IslandLoader.seed_from("fjell") == "fjell".hash(), "text is not hashed")
	expect(IslandLoader.seed_from("fjell") != IslandLoader.seed_from("hav"), "two words give the same seed")


## The loader's bar looks each finished step up in STEP_MSEC, so a renamed or added step must be added there too.
func test_generator_reports_the_steps_the_loader_weighs() -> void:
	var steps: Array[String] = []
	IslandGenerator.generate(1, steps.append)
	var expected: Array = IslandLoader.STEP_MSEC.keys()
	expected.erase("mesh")
	expect(steps == expected, "the generator reports %s, the loader weighs %s" % [steps, expected])
