extends "res://tests/test_case.gd"


## The terrain and figure shaders read these images as linear colors.
func test_ramp_image_holds_each_ramp_in_its_row() -> void:
	for ramps: Dictionary in [Ramps.RAMPS, Ramps.FIGURE]:
		var image: Image = Ramps.image(ramps)
		for row: int in ramps:
			var ramp: PackedColorArray = ramps[row]
			for i: int in ramp.size():
				var pixel: Color = image.get_pixel(i, row).linear_to_srgb()
				expect(pixel.to_rgba32() == ramp[i].to_rgba32(), "ramp %d step %d is %s, expected %s" % [row, i, pixel.to_html(false), ramp[i].to_html(false)])


## terrain.gdshader writes these values as literals and sizes ramp_sizes for this many ramps.
func test_shader_literals_match_the_terrain_enum() -> void:
	expect(Ramps.Terrain.size() == 10, "%d terrains, but the shader's ramp_sizes holds 10" % Ramps.Terrain.size())
	expect(Ramps.Terrain.WATER == 0 and Ramps.Terrain.BEACH == 1 and Ramps.Terrain.ROCK == 5 and Ramps.Terrain.FOAM == 7 and Ramps.Terrain.FOG == 8 and Ramps.Terrain.CLOUD == 9, "the shader's literals for water, beach, rock, foam, fog and cloud are out of date")


## ground.gdshaderinc sizes cloud_base and cloud_gone for one cloud per contender at the most.
func test_cloud_arrays_fit_every_contender() -> void:
	expect(Contenders.MAX_COUNT == 5, "up to %d contenders, but the shader's cloud arrays hold 5" % Contenders.MAX_COUNT)
