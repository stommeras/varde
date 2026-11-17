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
