extends "res://tests/test_case.gd"


func test_ramp_image_holds_each_ramp_in_its_row() -> void:
	var image: Image = TerrainMaterial.ramp_image()
	for kind: Ramps.Terrain in Ramps.Terrain.values():
		var ramp: PackedColorArray = Ramps.RAMPS[kind]
		for i: int in ramp.size():
			var pixel: Color = image.get_pixel(i, kind).linear_to_srgb()
			expect(pixel.to_rgba32() == ramp[i].to_rgba32(), "ramp %d step %d is %s, expected %s" % [kind, i, pixel.to_html(false), ramp[i].to_html(false)])


## terrain.gdshader writes these values as literals and sizes ramp_sizes for this many ramps.
func test_shader_literals_match_the_terrain_enum() -> void:
	expect(Ramps.Terrain.size() == 8, "%d terrains, but the shader's ramp_sizes holds 8" % Ramps.Terrain.size())
	expect(Ramps.Terrain.WATER == 0 and Ramps.Terrain.BEACH == 1 and Ramps.Terrain.ROCK == 5 and Ramps.Terrain.FOAM == 7, "the shader's literals for water, beach, rock and foam are out of date")
