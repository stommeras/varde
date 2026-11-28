// What the terrain shader and the ground detail shader share: the island's grids, the ramps, the
// rules that pick a pixel's material, the ramp lighting and the fog over unknown land.
// IslandTerrain sets the same values on both materials, so a detail always sits on ground that the
// terrain draws in its own material and light.

// One float per cell. Sea level is 0.0 and the summit 1.0, as in IslandData.height.
uniform sampler2D height_map : filter_linear, repeat_disable;
// One byte per cell, a Ramps.Terrain value.
uniform sampler2D material_map : filter_nearest, repeat_disable;
// One byte per cell, 1 where a river or lake covers it, which the shader reads as 1 / 255. Linear,
// so a river's edge runs between cells instead of along their sides.
uniform sampler2D fresh_water_map : filter_linear, repeat_disable;
// One byte per cell, 1 on a cliff the player can't stand on (IslandData.cliff), which the shader
// reads as 1 / 255. Linear, so a cliff's edge runs between cells and rounds its corners.
uniform sampler2D cliff_map : filter_linear, repeat_disable;
// One byte per cell, a Knowledge.Level, which the shader reads as that value / 255. Nearest, so a
// cell is fully one level. Knowledge updates the texture once a frame when the player learns more.
uniform sampler2D knowledge_map : filter_nearest, repeat_disable;
// One float per cell, the second on Knowledge's clock at which the player first saw it, and
// Knowledge.NEVER while the cell is unknown. Read with texelFetch, because linear filtering between
// a time and NEVER gives a time far in the future, not a cell half clear.
uniform sampler2D reveal_map : filter_nearest, repeat_disable;
// True while god mode shows the whole island. It hides the fog and the cloud layer without marking
// any cell known.
uniform bool show_all = false;
// The second on Knowledge's clock now. IslandTerrain sets it each frame.
uniform float reveal_now = 0.0;
// Seconds the fog takes to clear from a cell after the player sees it. Raising it makes the land
// show more slowly.
uniform float clear_seconds = 1.0;
// How far, in cells, the warp noise moves the fog's edge, so it doesn't trace the line of sight's cells.
uniform float fog_edge_cells = 1.5;
// Cells between the samples that smooth the fog's edge, 3 by 3 around each pixel. Raising it rounds
// the edge more and swallows larger gaps the line of sight left. Without it the edge followed every
// cell the line of sight left out, in ragged steps.
uniform float fog_soft_cells = 2.0;
// The share of the averaged fog over which its edge dithers, around the middle. At 1 the edge
// dithered over a few cells, and on a steep peak whose top the player had seen, that band showed
// the unknown slope below as a see-through outline. Lowering it gives a crisper edge.
uniform float fog_edge_dither = 0.3;
// The cloud layer's base and top in height-map units. Above the summit when the island has no layer.
uniform float cloud_base = 2.0;
uniform float cloud_top = 2.0;
// The height of the ground under the player, which decides whether they are under, inside or over
// the layer.
uniform float cloud_eye = 0.0;
// The player's position in cells. Inside the layer, the cloud opens around it.
uniform vec2 cloud_hole = vec2(-1000.0);
// Cells around the player that the cloud leaves open inside the layer. TerrainMaterial sets it to
// LineOfSight.CLOUD_RADIUS.
uniform float cloud_hole_cells = 8.0;
// Cells over which the hole's edge dithers from open to full cloud. Raising it softens the edge and
// shrinks the open ground, since full cloud starts at cloud_hole_cells.
uniform float cloud_hole_edge = 3.0;
// Height-map units the warp noise moves the layer where it meets the ground. Raising it makes the
// edge more ragged, and at 0 the edge is a contour line.
uniform float cloud_wobble = 0.012;
// Row t holds the steps of ramp t, darkest first, as linear colors. TerrainMaterial builds it from
// Ramps.RAMPS. Not source_color, because the Compatibility renderer skips that decode in texelFetch.
uniform sampler2D ramps : filter_nearest, repeat_disable;
// How many steps each ramp in `ramps` has, indexed by Ramps.Terrain.
uniform int ramp_sizes[10];
// Seamless FastNoiseLite noise from 0 to 1, tiled across the world.
uniform sampler2D noise : filter_linear, repeat_enable;

// Cells one tile of `noise` covers when warping material boundaries. Raising it makes the
// boundaries wander in longer, smoother curves, lowering it makes them more ragged.
uniform float warp_scale = 24.0;
// How far, in cells, a boundary can move from the grid. Below about 0.5 the grid's straight edges
// show, and above about 3 thin bands of a material break up into islands.
uniform float warp_cells = 1.5;
// How far, in cells, noise moves a cliff's edge off the grid, so it doesn't run in straight steps.
// Keep it well under 0.5, or the drawn cliff strays onto cells the player can walk. Drawn from the
// slope's normal with a wobble instead, rock showed as noisy blobs on ground either side of the limit.
uniform float cliff_warp_cells = 0.2;
// The interpolated fresh water map above which a pixel is water. At 0.5 a river one cell wide pinches
// shut where it steps diagonally, because the corner between two diagonal cells reads 0.5. Lowering
// it widens every river.
uniform float river_edge = 0.35;
// Ramp position, from 0 to 1, of faces turned away from the sun, before shadow_steps darkens the ones
// in shadow. Raising it lightens the shade side, lowering it to 0 makes the shade side the ramp's
// darkest step. At 0.15 a cast shadow on the shade side reached the darkest step, and valleys read as black.
uniform float shade = 0.3;
// Ramp steps a cast shadow takes off on top of the shade. Under a low sun, flat ground gets little
// more light than the shade side, and without this its shadows are a faint change in the dither.
// Raising it darkens shadows, 0 shades them like faces turned away from the sun.
uniform float shadow_steps = 1.0;

#include "res://world/dither.gdshaderinc"

// How far the fog has cleared from the cell at column and row, from 0 while it is unknown to 1 a
// clear_seconds after the player saw it. It eases in and out.
float clear_of(ivec2 cell) {
	if (show_all) {
		return 1.0;
	}
	ivec2 size = textureSize(reveal_map, 0);
	float revealed = texelFetch(reveal_map, clamp(cell, ivec2(0), size - 1), 0).r;
	return smoothstep(0.0, clear_seconds, reveal_now - revealed);
}

// clear_of() at point, blended between the four nearest cell centers as the height map blends its
// heights.
float clear_at(vec2 point) {
	vec2 p = point - 0.5;
	ivec2 nw = ivec2(floor(p));
	vec2 f = p - vec2(nw);
	return mix(mix(clear_of(nw), clear_of(nw + ivec2(1, 0)), f.x),
		mix(clear_of(nw + ivec2(0, 1)), clear_of(nw + ivec2(1, 1)), f.x), f.y);
}

// The share of fog at point, from 0 where the player knows all the land around to 1 where they know
// none. warp is warp_at(point). It averages 3 by 3 samples fog_soft_cells apart, which rounds the
// edge's shape and fills single cells the line of sight left out.
float mist_at(vec2 point, vec2 warp) {
	vec2 center = point + warp * 2.0 * fog_edge_cells;
	float clear = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			clear += clear_at(center + vec2(float(x), float(y)) * fog_soft_cells);
		}
	}
	return 1.0 - clear / 9.0;
}

// True where the terrain draws fog at point, for a pixel with the dither threshold threshold. The
// edge sits where half the averaged samples are clear, and dithers over fog_edge_dither around it.
bool is_fogged(vec2 point, vec2 warp, float threshold) {
	return mist_at(point, warp) > 0.5 + (threshold - 0.5) * fog_edge_dither;
}

// The share of cloud at point, from 0 in clear air to 1 where the layer hides the ground at height.
// Under the layer it hides the ground over its base, over it the ground under its top, and inside it
// all but the hole around the player.
float cloud_cover(vec2 point, float height, vec2 warp) {
	if (show_all) {
		return 0.0;
	}
	float ground = height + warp.x * 2.0 * cloud_wobble;
	if (cloud_eye < cloud_base) {
		return ground > cloud_base ? 1.0 : 0.0;
	}
	if (cloud_eye >= cloud_top) {
		return ground < cloud_top ? 1.0 : 0.0;
	}
	float hole = distance(point + warp * 2.0, cloud_hole);
	return smoothstep(cloud_hole_cells - cloud_hole_edge, cloud_hole_cells, hole);
}

// The offset, from -0.5 to 0.5 on each axis, that warps material boundaries and rivers at cell.
// Two samples far apart in the same noise tile act as two independent noises for x and z.
vec2 warp_at(vec2 cell) {
	vec2 warp_uv = cell / warp_scale;
	return vec2(texture(noise, warp_uv).r, texture(noise, warp_uv + vec2(0.5, 0.31)).r) - 0.5;
}

// The world normal of the height map at uv, whose height is height, with the summit summit world
// units up. The surface y = h(x, z) has the normal (-dh/dx, 1, -dh/dz), and the sea is flat, as in
// the mesh, so water next to a slope doesn't take its tilt.
vec3 ground_normal(vec2 uv, float height, float summit) {
	vec2 texel = 1.0 / vec2(textureSize(height_map, 0));
	float west = max(texture(height_map, uv - vec2(texel.x, 0.0)).r, 0.0);
	float east = max(texture(height_map, uv + vec2(texel.x, 0.0)).r, 0.0);
	float north = max(texture(height_map, uv - vec2(0.0, texel.y)).r, 0.0);
	float south = max(texture(height_map, uv + vec2(0.0, texel.y)).r, 0.0);
	return height <= 0.0 ? vec3(0.0, 1.0, 0.0) : normalize(vec3((west - east) * summit * 0.5, 1.0, (north - south) * summit * 0.5));
}

// The material the terrain draws at cell before cliffs, foam and fresh water, as a Ramps.Terrain value.
// The interpolated height crosses sea level on a smooth curve, which draws the coast without the
// grid. Warping can still land a shore pixel on a sea cell, and all land at the shore is beach.
int material_at(vec2 cell, vec2 warp, float height) {
	ivec2 size = textureSize(material_map, 0);
	ivec2 warped = clamp(ivec2(floor(cell + warp * 2.0 * warp_cells)), ivec2(0), size - 1);
	int kind = int(round(texelFetch(material_map, warped, 0).r * 255.0));
	if (height <= 0.0) {
		return 0;  // Ramps.Terrain.WATER
	}
	return kind == 0 ? 1 : kind;  // Ramps.Terrain.BEACH
}

// True where the terrain draws a cliff in rock at cell, which is where the cliff map marks the
// ground the player can't stand on.
bool is_cliff(vec2 cell, vec2 warp) {
	vec2 texel = 1.0 / vec2(textureSize(cliff_map, 0));
	return texture(cliff_map, (cell + warp * 2.0 * cliff_warp_cells) * texel).r * 255.0 > 0.5;
}

// True where a river or lake covers land at cell. It takes the same warp as the material boundaries,
// so rivers and lake shores wander off the grid's lines.
bool is_fresh_water(vec2 cell, vec2 warp) {
	vec2 texel = 1.0 / vec2(textureSize(fresh_water_map, 0));
	return texture(fresh_water_map, (cell + warp * 2.0 * warp_cells) * texel).r * 255.0 > river_edge;
}

// The color of a pixel of ramp kind lit by light(). facing is the dot of the normal and the light,
// attenuation the sun's shadow, 0 in full shadow. reach is the share of the ramp full sun reaches,
// offset the ramp steps added to the light, and threshold the dither threshold that picks between
// the two nearest steps.
vec3 ramp_color(float facing, float attenuation, int kind, float reach, float offset, float threshold) {
	// A shadowed face shades like one turned away from the sun, and then shadow_steps darker, so a
	// shadow on flat ground still shows under a low sun.
	float lit = facing * attenuation;
	// Faces turned away from the sun always fall in the shadow map's shadow, because the sun's ray to
	// them passes through the hill. Only faces turned toward it take the extra steps, so the shade side
	// keeps the shade step. The short ramp in from the terminator hides shadow acne at grazing angles.
	float cast = (1.0 - attenuation) * smoothstep(0.0, 0.05, facing);
	int steps = ramp_sizes[kind];
	float position = mix(shade, 1.0, lit) * reach * float(steps - 1) + offset - shadow_steps * cast;
	int ramp_step = clamp(int(floor(position + threshold)), 0, steps - 1);
	return texelFetch(ramps, ivec2(ramp_step, kind), 0).rgb;
}
