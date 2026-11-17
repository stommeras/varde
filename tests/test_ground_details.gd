extends "res://tests/test_case.gd"


## Every square of a ground's row holds a sprite that stands on the square's bottom, in a ramp that
## exists and an offset the shader can read, and the sea's rows stay empty.
func test_atlas_holds_a_standing_sprite_in_every_square() -> void:
	var image: Image = GroundDetails.atlas()
	var size: int = GroundDetails.SPRITE
	for ground: Ramps.Terrain in Ramps.Terrain.values():
		for column: int in GroundDetails.VARIANTS:
			var pixels: int = 0
			var on_bottom: bool = false
			for y: int in size:
				for x: int in size:
					var pixel: Color = image.get_pixel(column * size + x, ground * size + y)
					if pixel.a8 == 0:
						continue
					pixels += 1
					on_bottom = on_bottom or y == size - 1
					var offset: int = pixel.g8 - 8
					if pixel.r8 >= Ramps.Terrain.size() or offset < -4 or offset > 4:
						expect(false, "ground %d sprite %d has ramp %d, offset %d" % [ground, column, pixel.r8, offset])
						return
			if not GroundDetails.ROWS.has(ground):
				expect(pixels == 0, "ground %d holds no details, but sprite %d has pixels" % [ground, column])
			else:
				expect(on_bottom, "ground %d sprite %d doesn't reach the ground" % [ground, column])
