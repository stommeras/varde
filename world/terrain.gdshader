shader_type spatial;
// Draws the terrain from grid-sized height and material textures. Every pixel is a step of a ramp
// from world/ramps.gd: light picks a position along the material's ramp, and ordered dithering
// snaps it to one of the two nearest steps instead of blending them.
//
// Ambient light would add color on top of the ramp step, so it is off. The sun alone lights the
// terrain, and light() replaces Godot's lighting with the ramp lookup.
render_mode ambient_light_disabled;

// One float per cell. Sea level is 0.0 and the summit 1.0, as in IslandData.height.
uniform sampler2D height_map : filter_linear, repeat_disable;
// One byte per cell, a Ramps.Terrain value.
uniform sampler2D material_map : filter_nearest, repeat_disable;
// Row t holds the steps of ramp t, darkest first. TerrainMaterial builds it from Ramps.RAMPS.
uniform sampler2D ramps : source_color, filter_nearest, repeat_disable;
// How many steps each ramp in `ramps` has, indexed by Ramps.Terrain.
uniform int ramp_sizes[7];
// Seamless FastNoiseLite noise from 0 to 1, tiled across the world.
uniform sampler2D noise : filter_linear, repeat_enable;

// Cells one tile of `noise` covers when warping material boundaries. Raising it makes the
// boundaries wander in longer, smoother curves, lowering it makes them more ragged.
uniform float warp_scale = 24.0;
// How far, in cells, a boundary can move from the grid. Below about 0.5 the grid's straight edges
// show, and above about 3 thin bands of a material break up into islands.
uniform float warp_cells = 1.5;
// Cells one tile of `noise` covers for the grain inside a material. Lower is finer grain.
uniform float grain_scale = 6.0;
// How many ramp steps the grain shifts the light up or down. 0 gives flat dithering, above about
// 1 the grain drowns out the shape of the land.
uniform float grain_steps = 0.6;
// The normal's y below which a face counts as a cliff and turns to rock. cos(60°) is 0.5.
// Raising it turns gentler slopes to rock too, and their strata draw contour rings around whole hills.
uniform float cliff_normal_y = 0.5;
// How much noise moves the cliff threshold, so rock edges on a slope are ragged instead of following
// one contour of steepness.
uniform float cliff_wobble = 0.15;
// World units between the tops of two strata. Lower gives thinner bands.
uniform float strata_spacing = 1.2;
// How many spacings noise can bend a stratum up or down along the cliff, so the bands aren't perfectly level.
uniform float strata_wobble = 0.6;
// Ramp position, from 0 to 1, of faces turned away from the sun. Raising it lightens the shade
// side, lowering it to 0 makes the shade side the ramp's darkest step.
uniform float shade = 0.15;

// A 4×4 Bayer matrix. Each pixel in a 4×4 block gets a different threshold, so a light level between
// two steps shows as an even pattern of both.
const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

varying vec3 world_position;
// The Ramps.Terrain value whose ramp this pixel uses. Floats, because light() reads it.
varying float terrain;
// Ramp steps added to the light's position along the ramp, from grain and strata.
varying float step_offset;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// A cell's center sits at (column + 0.5, row + 0.5) in the world, which is its texel center.
	vec2 cell = world_position.xz;
	vec2 texel = 1.0 / vec2(textureSize(height_map, 0));
	vec2 uv = cell * texel;
	// The mesh's y scale is the summit height in world units.
	float summit = length(MODEL_MATRIX[1].xyz);

	// The normal comes from the height texture instead of the mesh, so the shading keeps its detail on
	// coarse meshes far from the camera. The surface y = h(x, z) has the normal (-dh/dx, 1, -dh/dz),
	// and the sea is flat, as in the mesh.
	float west = max(texture(height_map, uv - vec2(texel.x, 0.0)).r, 0.0);
	float east = max(texture(height_map, uv + vec2(texel.x, 0.0)).r, 0.0);
	float north = max(texture(height_map, uv - vec2(0.0, texel.y)).r, 0.0);
	float south = max(texture(height_map, uv + vec2(0.0, texel.y)).r, 0.0);
	vec3 world_normal = normalize(vec3((west - east) * summit * 0.5, 1.0, (north - south) * summit * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// Two samples far apart in the same noise tile act as two independent noises for x and z.
	vec2 warp_uv = cell / warp_scale;
	vec2 warp = vec2(texture(noise, warp_uv).r, texture(noise, warp_uv + vec2(0.5, 0.31)).r) - 0.5;
	ivec2 size = textureSize(material_map, 0);
	ivec2 warped = clamp(ivec2(floor(cell + warp * 2.0 * warp_cells)), ivec2(0), size - 1);
	int kind = int(round(texelFetch(material_map, warped, 0).r * 255.0));

	// The interpolated height crosses sea level on a smooth curve, which draws the coast without the
	// grid. Warping can still land a shore pixel on a sea cell, and all land at the shore is beach.
	float height = texture(height_map, uv).r;
	if (height <= 0.0) {
		kind = 0;  // Ramps.Terrain.WATER
	} else if (kind == 0) {
		kind = 1;  // Ramps.Terrain.BEACH
	}

	float grain = texture(noise, cell / grain_scale + vec2(0.17, 0.73)).r - 0.5;
	step_offset = grain * 2.0 * grain_steps;
	if (kind != 0 && world_normal.y + warp.y * 2.0 * cliff_wobble < cliff_normal_y) {
		kind = 5;  // Ramps.Terrain.ROCK
		// Every other stratum is one step darker, which draws level bands across the cliff.
		float stratum = floor(height * summit / strata_spacing + warp.x * 2.0 * strata_wobble);
		step_offset -= mod(stratum, 2.0);
	}
	terrain = float(kind);
	ALBEDO = vec3(1.0);
}

void light() {
	// ATTENUATION carries the shadow once the sun casts one, so a shadowed face shades like one
	// turned away from the sun.
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	int kind = int(terrain);
	int steps = ramp_sizes[kind];
	float position = mix(shade, 1.0, lit) * float(steps - 1) + step_offset;
	ivec2 pixel = ivec2(FRAGCOORD.xy) % 4;
	float threshold = (BAYER[pixel.y * 4 + pixel.x] + 0.5) / 16.0;
	int ramp_step = clamp(int(floor(position + threshold)), 0, steps - 1);
	// The albedo is white, so this is the pixel's final color.
	DIFFUSE_LIGHT = texelFetch(ramps, ivec2(ramp_step, kind), 0).rgb;
}
