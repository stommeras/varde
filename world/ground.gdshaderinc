// What the terrain shader and the ground detail shader share: the island's grids, the ramps, the
// rules that pick a pixel's material, the ramp lighting, the fog over unknown land and the fade in
// front of the player.
// IslandTerrain sets the same values on both materials, so a detail always sits on ground that the
// terrain draws in its own material and light, and fades with it.

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
// Row t holds the steps of ramp t, darkest first, as linear colors. TerrainMaterial builds it from
// Ramps.RAMPS. Not source_color, because the Compatibility renderer skips that decode in texelFetch.
uniform sampler2D ramps : filter_nearest, repeat_disable;
// How many steps each ramp in `ramps` has, indexed by Ramps.Terrain.
uniform int ramp_sizes[9];
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

// How far the fade in front of the player is open, from 0 (shut) to 1 (fade_radius). The player
// opens it while terrain hides the figure and moves player_position to the feet each frame. The
// debug view has no player and leaves it shut.
uniform float fade_amount = 0.0;
// The player's feet in world units.
uniform vec3 player_position;
// World units on screen from the feet to where the fade ends, about 19 screen pixels per unit at
// zoom 40. Raising it opens a wider hole around the player in a ridge. At 4 and 7 a ridge in front
// still hid most of the ground behind the player, and the hole read as a bite out of the rock.
uniform float fade_radius = 10.0;
// World units over which the fade dithers out at its rim, at fade_ground above the feet and at the
// feet's depth. Raising it gives a softer, wider dithered edge, and at 0 the hole has a hard rim.
uniform float fade_edge = 2.5;
// World units the view ray behind a faded pixel must clear the ground by somewhere past the pixel.
// A pixel whose ray never leaves the ground stays, because cutting it would show the empty space
// under the terrain. The mesh runs straight between cell centers and the height map blends four of
// them, so on steep rock they disagree by up to a unit or so, and below about 1 the hole shows specks
// of that space. Terrain less than this above the feet never fades, which keeps the ground the player
// stands on. Raising it leaves more of the terrain in front of the player.
uniform float fade_ground = 1.0;
// World units between the samples the fade takes along the view ray, and how many it takes. A gap
// narrower than a step between a ridge and the land behind it can be missed, which keeps that pixel.
// 96 steps of 1 reach about 68 units down, more than a ridge stands above the valley behind it.
uniform float fade_step = 1.0;
uniform int fade_steps = 96;

#include "res://world/dither.gdshaderinc"

// How far the fog has cleared from the cell at column and row, from 0 while it is unknown to 1 a
// clear_seconds after the player saw it. It eases in and out.
float clear_of(ivec2 cell) {
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

// True where the fade in front of the player cuts the terrain at world_position, which lies at
// view_position in view space. threshold is the pixel's dither threshold. The fade cuts terrain that
// is nearer the camera than the player and higher than the feet, so on open ground nothing fades.
bool is_faded(vec3 world_position, vec3 view_position, mat4 view_matrix, mat4 inv_view_matrix, float summit, float threshold) {
	if (fade_amount <= 0.0) {
		return false;
	}
	vec3 feet = (view_matrix * vec4(player_position, 1.0)).xyz;
	float rise = world_position.y - player_position.y;
	// smoothstep is undefined when its edges meet, so a fade_edge of 0 keeps a sliver of width.
	float edge = max(fade_edge, 0.001);
	float radius = fade_radius * fade_amount;
	float keep = max(smoothstep(radius - edge, radius, length(view_position.xy - feet.xy)),
		1.0 - smoothstep(fade_ground, fade_ground + edge, rise));
	// Terrain that crosses the feet's depth dithers out too, instead of ending in a straight line.
	keep = max(keep, 1.0 - smoothstep(0.0, edge, view_position.z - feet.z));
	// The pixels that survive in the dithered rim have low thresholds, and light() rounds them down
	// a ramp step with the same threshold, so the rim reads as a darker outline. A shifted Bayer
	// pattern evens that out but draws stripes along the rim.
	if (keep >= threshold) {
		return false;
	}
	// Marches the view ray on past this pixel. Once it lies fade_ground above the height map, it
	// has come out of the ground, and the land it meets next shows through the hole. That land
	// fades only if its own ray comes out again further on, so some land always shows.
	vec2 texel = 1.0 / vec2(textureSize(height_map, 0));
	vec3 ray = -inv_view_matrix[2].xyz;
	for (int i = 1; i <= fade_steps; i++) {
		vec3 point = world_position + ray * float(i) * fade_step;
		// The height map never drops below sea level, so a ray this low can't clear it any more.
		if (point.y < fade_ground) {
			return false;
		}
		float ground = max(texture(height_map, point.xz * texel).r, 0.0) * summit;
		if (ground < point.y - fade_ground) {
			return true;
		}
	}
	return false;
}
