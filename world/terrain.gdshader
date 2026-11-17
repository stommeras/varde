shader_type spatial;
// Draws the terrain from grid-sized height and material textures. Every pixel is a step of a ramp
// from world/ramps.gd: light picks a position along the material's ramp, and ordered dithering
// snaps it to one of the two nearest steps instead of blending them. The sea is part of the same
// mesh, flat at sea level, and the height map's negative sea floor gives its depth.
//
// Ambient light would add color on top of the ramp step, so it is off. The sun alone lights the
// terrain, and light() replaces Godot's lighting with the ramp lookup.
render_mode ambient_light_disabled;

// One float per cell. Sea level is 0.0 and the summit 1.0, as in IslandData.height.
uniform sampler2D height_map : filter_linear, repeat_disable;
// One byte per cell, a Ramps.Terrain value.
uniform sampler2D material_map : filter_nearest, repeat_disable;
// One byte per cell, 1 where a river or lake covers it, which the shader reads as 1 / 255. Linear,
// so a river's edge runs between cells instead of along their sides.
uniform sampler2D fresh_water_map : filter_linear, repeat_disable;
// Row t holds the steps of ramp t, darkest first. TerrainMaterial builds it from Ramps.RAMPS.
uniform sampler2D ramps : source_color, filter_nearest, repeat_disable;
// How many steps each ramp in `ramps` has, indexed by Ramps.Terrain.
uniform int ramp_sizes[8];
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
// The normal's y below which a face counts as a cliff and turns to rock. cos(73°) is about 0.3.
// Raising it turns gentler slopes to rock too. At 0.5 (60°) the eroded valley sides of #33 turned
// whole mountains to rock, and their strata drew contour rings around them.
uniform float cliff_normal_y = 0.3;
// How much noise moves the cliff threshold, so rock edges on a slope are ragged instead of following
// one contour of steepness.
uniform float cliff_wobble = 0.15;
// World units between the tops of two strata. Lower gives thinner bands. At 1.2 the bands read as
// fine rings around each mountain instead of layers in a cliff.
uniform float strata_spacing = 5.0;
// How many spacings noise can bend a stratum up or down along the cliff, so the bands aren't perfectly level.
uniform float strata_wobble = 0.6;
// Ramp position, from 0 to 1, of faces turned away from the sun, before shadow_steps darkens the ones
// in shadow. Raising it lightens the shade side, lowering it to 0 makes the shade side the ramp's
// darkest step.
uniform float shade = 0.15;
// Ramp steps a cast shadow takes off on top of the shade. Under a low sun, flat ground gets little
// more light than the shade side, and without this its shadows are a faint change in the dither.
// Raising it darkens shadows, 0 shades them like faces turned away from the sun.
uniform float shadow_steps = 1.0;

// Depth below sea level, in height-map units, where the sea reaches its darkest step. The summit is
// 1.0, and the sea floor drops about 0.012 per cell from the coast. Raising it widens the light
// shallows, lowering it makes the sea dark close to land.
uniform float deep_water = 0.6;
// Cells one tile of `noise` covers for the ripples. Lower gives smaller, denser ripples.
uniform float ripple_scale = 20.0;
// Noise tiles per second the two ripple layers drift. Raising it makes the sea busier. Godot wraps
// TIME every hour, and the crests jump at the wrap unless each layer has moved a whole number of
// tiles. The drift directions are in tenths, so keep 360 * speed a whole number. 1/60 gives 6.
uniform float ripple_speed = 0.016666667;
// How close the two ripple layers must be, in noise values, to draw a crest. Raising it gives
// thicker crests that cover more of the sea.
uniform float ripple_width = 0.04;
// Ramp steps a crest lifts the water. Raising it makes crests brighter, 0 hides them.
uniform float ripple_steps = 1.0;
// Depth, in height-map units, out to which foam reaches. 0.08 is about 6 cells from the coast.
// Raising it carries the bands farther out to sea.
uniform float foam_depth = 0.08;
// Depth between two bands of foam rolling in. Lower gives more, closer bands.
uniform float foam_spacing = 0.03;
// Bands per second that roll in toward the shore. Raising it makes the surf faster. Keep
// 3600 * speed a whole number, so the hourly wrap of TIME doesn't jump.
uniform float foam_speed = 0.25;
// Share of the spacing a band covers at the shoreline. Bands thin out to nothing at foam_depth.
uniform float foam_width = 0.45;
// Depth of the unbroken line of foam along the coast. 0.008 is about one cell. Raising it widens the line.
uniform float foam_edge = 0.008;

// The interpolated fresh water map above which a pixel is water. At 0.5 a river one cell wide pinches
// shut where it steps diagonally, because the corner between two diagonal cells reads 0.5. Lowering
// it widens every river.
uniform float river_edge = 0.35;

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
// Ramp steps added to the light's position along the ramp, from grain, strata and ripples.
varying float step_offset;
// The share of the ramp full sun reaches. 1 on land and foam, and less in deeper water.
varying float ramp_reach;
// This pixel's position in screen pixels, measured from the world origin instead of the screen corner.
varying vec2 world_pixel;

// Ramp steps that the drifting ripple crests lift the water at cell. Two layers of the noise drift
// in different directions, and a crest is drawn where their values meet. That traces thin,
// wandering lines that change shape as the layers slide.
float ripple(vec2 cell) {
	vec2 ripple_uv = cell / ripple_scale;
	float a = texture(noise, ripple_uv + TIME * ripple_speed * vec2(0.6, 0.8)).r;
	float b = texture(noise, ripple_uv * 1.3 + vec2(0.41, 0.07) - TIME * ripple_speed * vec2(0.8, -0.3)).r;
	return ripple_steps * (1.0 - smoothstep(0.0, ripple_width, abs(a - b)));
}

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

	float height = texture(height_map, uv).r;

	// The normal comes from the height texture instead of the mesh, so the shading keeps its detail on
	// coarse meshes far from the camera. The surface y = h(x, z) has the normal (-dh/dx, 1, -dh/dz),
	// and the sea is flat, as in the mesh, so water next to a slope doesn't take its tilt.
	float west = max(texture(height_map, uv - vec2(texel.x, 0.0)).r, 0.0);
	float east = max(texture(height_map, uv + vec2(texel.x, 0.0)).r, 0.0);
	float north = max(texture(height_map, uv - vec2(0.0, texel.y)).r, 0.0);
	float south = max(texture(height_map, uv + vec2(0.0, texel.y)).r, 0.0);
	vec3 world_normal = height <= 0.0 ? vec3(0.0, 1.0, 0.0) : normalize(vec3((west - east) * summit * 0.5, 1.0, (north - south) * summit * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// Two samples far apart in the same noise tile act as two independent noises for x and z.
	vec2 warp_uv = cell / warp_scale;
	vec2 warp = vec2(texture(noise, warp_uv).r, texture(noise, warp_uv + vec2(0.5, 0.31)).r) - 0.5;
	ivec2 size = textureSize(material_map, 0);
	ivec2 warped = clamp(ivec2(floor(cell + warp * 2.0 * warp_cells)), ivec2(0), size - 1);
	int kind = int(round(texelFetch(material_map, warped, 0).r * 255.0));

	// The interpolated height crosses sea level on a smooth curve, which draws the coast without the
	// grid. Warping can still land a shore pixel on a sea cell, and all land at the shore is beach.
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
	ramp_reach = 1.0;
	if (kind == 0) {
		float depth = -height;
		// Bands of foam lie along lines of equal depth, which follow the coast. Adding time to the phase
		// moves each band toward shallower water, so they roll in and thin out as they near foam_depth
		// from the shore. The warp noise bends them, so they don't trace the depth contours exactly.
		float shore = 1.0 - depth / foam_depth;
		float phase = depth / foam_spacing + TIME * foam_speed + warp.x;
		if (depth < foam_edge * (1.0 + warp.y * 2.0) || fract(phase) < foam_width * shore) {
			kind = 7;  // Ramps.Terrain.FOAM, which keeps the grain and the full ramp.
		} else {
			ramp_reach = 1.0 - smoothstep(0.0, deep_water, depth);
			step_offset = ripple(cell);
		}
	}
	// The same warp as the material boundaries, so rivers and lake shores wander off the grid's lines.
	// A river runs over cliffs too, as a waterfall. It keeps the slope's normal and the ramp's full
	// reach, so it shades like shallow water on the slope, and a lake is flat.
	if (height > 0.0 && texture(fresh_water_map, (cell + warp * 2.0 * warp_cells) * texel).r * 255.0 > river_edge) {
		kind = 0;  // Ramps.Terrain.WATER
		step_offset = ripple(cell);
	}
	terrain = float(kind);
	ALBEDO = vec3(1.0);

	// A dither pattern fixed to the screen stays still while the land slides under it, so panning
	// shimmers. Counting pixels along the camera's right and up axes from the world origin moves
	// the pattern with the land. An orthographic PROJECTION_MATRIX[1][1] is 2 / the view's height
	// in world units. The camera moves in whole pixels, so each pixel's count stays put as it pans.
	float pixel_size = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	world_pixel = vec2(dot(world_position, INV_VIEW_MATRIX[0].xyz), dot(world_position, INV_VIEW_MATRIX[1].xyz)) / pixel_size;
}

void light() {
	// ATTENUATION is the sun's shadow, 0 in full shadow. A shadowed face shades like one turned away
	// from the sun, and then shadow_steps darker, so a shadow on flat ground still shows under a low sun.
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = facing * ATTENUATION;
	// Faces turned away from the sun always fall in the shadow map's shadow, because the sun's ray to
	// them passes through the hill. Only faces turned toward it take the extra steps, so the shade side
	// keeps the shade step. The short ramp in from the terminator hides shadow acne at grazing angles.
	float cast = (1.0 - ATTENUATION) * smoothstep(0.0, 0.05, facing);
	int kind = int(terrain);
	int steps = ramp_sizes[kind];
	float position = mix(shade, 1.0, lit) * ramp_reach * float(steps - 1) + step_offset - shadow_steps * cast;
	// Float mod, because the count is negative left of and below the origin, where % on ints is undefined.
	ivec2 pixel = ivec2(mod(floor(world_pixel), 4.0));
	float threshold = (BAYER[pixel.y * 4 + pixel.x] + 0.5) / 16.0;
	int ramp_step = clamp(int(floor(position + threshold)), 0, steps - 1);
	// The albedo is white, so this is the pixel's final color.
	DIFFUSE_LIGHT = texelFetch(ramps, ivec2(ramp_step, kind), 0).rgb;
}
