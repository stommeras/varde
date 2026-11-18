extends "res://tests/test_case.gd"


## The shader reads every part's ramp from one texture as wide as the first ramp.
func test_figure_ramps_have_the_same_steps() -> void:
	var steps: int = Ramps.FIGURE[Ramps.FigurePart.SKIN].size()
	for part: Ramps.FigurePart in Ramps.FigurePart.values():
		expect(Ramps.FIGURE.has(part) and Ramps.FIGURE[part].size() == steps, "part %d has no ramp of %d steps" % [part, steps])


func test_stands_straight_and_swings_its_legs_apart() -> void:
	var figure := Figure.new()
	figure.walk(0.0)
	for side: int in 2:
		expect(figure._hips[side].rotation.x == 0.0 and figure._knees[side].rotation.x == 0.0, "standing bends leg %d" % side)
	figure.walk(Figure.CELLS_PER_CYCLE / 4.0)
	expect(figure._hips[0].rotation.x > 0.0 and figure._hips[1].rotation.x < 0.0, "a quarter cycle in, the legs don't swing apart")
	expect(figure._shoulders[0].rotation.x < 0.0, "an arm doesn't swing against the leg on its side")
	figure.free()


## The figure's front is -z, so facing east turns it toward +x.
func test_faces_the_walking_direction() -> void:
	var figure := Figure.new()
	figure.face(Vector2.RIGHT)
	expect((-figure._body.basis.z).is_equal_approx(Vector3.RIGHT), "facing east points the figure along %s" % -figure._body.basis.z)
	figure.free()


## The hips are lowest with the legs furthest apart, and the body leans by the share of full speed.
func test_bobs_and_leans_with_pace() -> void:
	var figure := Figure.new()
	figure.walk(Figure.CELLS_PER_CYCLE / 4.0, 1.0)
	expect(figure._body.position.y < 0.0, "the body doesn't drop at a footfall")
	expect(figure._body.basis.y.z < 0.0, "the body doesn't lean toward its front")
	var full_lean: float = figure._lean
	figure.walk(Figure.CELLS_PER_CYCLE / 4.0, 0.5)
	expect(is_equal_approx(figure._lean, full_lean / 2.0), "half pace doesn't lean half as far")
	figure.walk(0.0)
	expect(figure._body.position.y == 0.0 and figure._lean == 0.0, "standing still doesn't stand upright")
	figure.free()
