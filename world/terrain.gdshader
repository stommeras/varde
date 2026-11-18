shader_type spatial;
// Draws the terrain from grid-sized height and material textures. Every pixel is a step of a ramp
// from world/ramps.gd: light picks a position along the material's ramp, and ordered dithering
// snaps it to one of the two nearest steps instead of blending them. The sea is part of the same
// mesh, flat at sea level, and the height map's negative sea floor gives its depth.
//
// Land the player doesn't know yet lies flat at sea level under fog, so an unexplored peak casts no
// shadow and its silhouette doesn't give the summit away. Once seen, it rises to its real height
// over rise_seconds and the fog thins out of it.
//
// Ambient light would add color on top of the ramp step, so it is off. The sun alone lights the
// terrain, and light() replaces Godot's lighting with the ramp lookup.
render_mode ambient_light_disabled;

#include "res://world/ground.gdshaderinc"

// Cells one tile of `noise` covers for the grain inside a material. Lower is finer grain.
uniform float grain_scale = 6.0;
// How many ramp steps the grain shifts the light up or down. 0 gives flat dithering, above about
// 1 the grain drowns out the shape of the land.
uniform float grain_steps = 0.6;
// World units between the tops of two strata. Lower gives thinner bands. At 1.2 the bands read as
// fine rings around each mountain instead of layers in a cliff.
uniform float strata_spacing = 5.0;
// How many spacings noise can bend a stratum up or down along the cliff, so the bands aren't perfectly level.
uniform float strata_wobble = 0.6;

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
// Cells from the coast out to which foam reaches. Raising it carries the bands farther out to sea.
uniform float foam_reach = 6.0;
// Cells between two bands of foam rolling in. Lower gives more, closer bands.
uniform float foam_spacing = 2.5;
// Bands per second that roll in toward the shore. Raising it makes the surf faster. Keep
// 3600 * speed a whole number, so the hourly wrap of TIME doesn't jump.
uniform float foam_speed = 0.25;
// Share of the spacing a band covers at the shoreline. Bands thin out to nothing at foam_reach.
uniform float foam_width = 0.45;
// Cells out from the coast that the unbroken line of foam covers. Raising it widens the line.
uniform float foam_edge = 0.7;
// World units on screen that one tile of `noise` covers for the light and dark patches in the fog.
// Lower gives smaller patches. At 40 the tile's repeats showed as a grid at zoom 160.
uniform float fog_scale = 90.0;
// Noise tiles per second the fog's patches drift. Keep 3600 * speed * 0.6 and * 0.8 whole numbers,
// so the hourly wrap of TIME doesn't jump. 1/120 drifts about 0.75 world units a second.
uniform float fog_speed = 0.008333333;
// How many ramp steps the patches move the fog's light up or down. 0 gives an even, dithered grey.
uniform float fog_steps = 1.5;

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
	// Every vertex sits on a cell's center. Lowering it here, and not in fragment(), moves the mesh
	// itself, so the shadow pass sees the lowered land and an unknown peak casts no shadow.
	vec2 cell = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y *= rise_of(ivec2(floor(cell)));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// A cell's center sits at (column + 0.5, row + 0.5) in the world, which is its texel center.
	vec2 cell = world_position.xz;
	vec2 uv = cell / vec2(textureSize(height_map, 0));
	// The mesh's y scale is the summit height in world units.
	float summit = length(MODEL_MATRIX[1].xyz);

	float height = texture(height_map, uv).r;

	// The normal comes from the height texture instead of the mesh, so the shading keeps its detail on
	// coarse meshes far from the camera.
	// The land stands at its rise times its height, so its slopes are that much flatter.
	vec3 world_normal = ground_normal(uv, height, summit * rise_at(cell));

	vec2 warp = warp_at(cell);
	int kind = material_at(cell, warp, height);

	float grain = texture(noise, cell / grain_scale + vec2(0.17, 0.73)).r - 0.5;
	step_offset = grain * 2.0 * grain_steps;
	// The slope at full height, so a cliff draws as rock while it rises instead of turning from
	// grass to rock as it steepens.
	if (kind != 0 && is_cliff(ground_normal(uv, height, summit), warp)) {
		kind = 5;  // Ramps.Terrain.ROCK
		// Every other stratum is one step darker, which draws level bands across the cliff.
		float stratum = floor(height * summit / strata_spacing + warp.x * 2.0 * strata_wobble);
		step_offset -= mod(stratum, 2.0);
	}
	ramp_reach = 1.0;
	if (kind == 0) {
		float depth = -height;
		// Foam follows the distance from the coast, which is the depth over the sea floor's slope where
		// the floor slopes evenly. Measured in depth alone, a wide shallow whose floor stays near sea
		// level turned to foam all over, in blocks that showed the cells. A flat floor gives a long
		// distance, so foam only lines its coast. The slope is a central difference across two cells,
		// which, unlike the slope of the bilinear height, doesn't jump at cell borders.
		vec2 texel = 1.0 / vec2(textureSize(height_map, 0));
		vec2 slope = vec2(
			texture(height_map, uv + vec2(texel.x, 0.0)).r - texture(height_map, uv - vec2(texel.x, 0.0)).r,
			texture(height_map, uv + vec2(0.0, texel.y)).r - texture(height_map, uv - vec2(0.0, texel.y)).r) * 0.5;
		float coast = depth / max(length(slope), 1e-6);
		// Bands of foam lie along lines of equal distance, which follow the coast. Adding time to the
		// phase moves each band toward the shore, so they roll in and thin out as they near foam_reach.
		// The warp noise bends them, so they don't trace the coast exactly.
		float shore = 1.0 - coast / foam_reach;
		float phase = coast / foam_spacing + TIME * foam_speed + warp.x;
		if (coast < foam_edge * (1.0 + warp.y * 2.0) || fract(phase) < foam_width * shore) {
			kind = 7;  // Ramps.Terrain.FOAM, which keeps the grain and the full ramp.
		} else {
			ramp_reach = 1.0 - smoothstep(0.0, deep_water, depth);
			step_offset = ripple(cell);
		}
	}
	// A river runs over cliffs too, as a waterfall. It keeps the slope's normal and the ramp's full
	// reach, so it shades like shallow water on the slope, and a lake is flat.
	if (height > 0.0 && is_fresh_water(cell, warp)) {
		kind = 0;  // Ramps.Terrain.WATER
		step_offset = ripple(cell);
	}
	world_pixel = screen_pixel(world_position, INV_VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE);

	// The fog covers unknown sea too, or the coast's outline would give the island's shape away.
	// It dithers out as the land rises, so the land grows out of it.
	if (mist_at(cell, warp, height * summit) > dither(world_pixel)) {
		kind = 8;  // Ramps.Terrain.FOG
		world_normal = vec3(0.0, 1.0, 0.0);
		ramp_reach = 1.0;
		// Laid out along the screen's axes, not the ground's, so the patches lie on a flat layer in front
		// of land that is still rising. Sampled by ground position, they ran down its slopes in streaks.
		vec2 across = vec2(dot(world_position, INV_VIEW_MATRIX[0].xyz), dot(world_position, INV_VIEW_MATRIX[1].xyz));
		vec2 fog_uv = across / fog_scale + TIME * fog_speed * vec2(0.6, 0.8);
		step_offset = (texture(noise, fog_uv).r - 0.5) * 2.0 * fog_steps;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	terrain = float(kind);
	ALBEDO = vec3(1.0);

	// The shadow pass skips the fade, so a faded ridge still casts its shadow.
	if (!IN_SHADOW_PASS && is_faded(world_position, VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, summit, dither(world_pixel))) {
		discard;
	}
}

void light() {
	// ATTENUATION is the sun's shadow, 0 in full shadow. The albedo is white, so this is the pixel's
	// final color.
	// Fog takes no cast shadows. The walls the mesh drops from seen land to the fog draw as fog,
	// and the land above shaded them into grey blocks that read as rock.
	float attenuation = int(terrain) == 8 ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT = ramp_color(clamp(dot(NORMAL, LIGHT), 0.0, 1.0), attenuation, int(terrain), ramp_reach, step_offset, dither(world_pixel));
}
