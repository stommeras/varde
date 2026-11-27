shader_type spatial;
// Draws the ground details: tufts, stones, shrubs, reeds and driftwood standing on the terrain. The
// mesh holds one quad per cell of a chunk, and this shader decides on the GPU whether a detail
// stands in that cell, which sprite it shows and where in the cell it stands. Each choice comes from
// a hash of the cell and the island's seed, so the same seed always scatters the same details and
// the CPU places none of them.
//
// A sprite's pixels hold a ramp and a step offset instead of a color. light() lights them like the
// ground they stand on, with that ground's normal, and moves each pixel the offset's steps along its
// ramp, so a detail takes the sun, the shade side and cast shadows as the terrain does.
//
// skip_vertex_transform, because vertex() builds the quad in view space, where it lines the sprite
// up with the screen's pixels.
render_mode ambient_light_disabled, skip_vertex_transform, cull_disabled;

#include "res://world/ground.gdshaderinc"

// Row t holds the sprites that stand on ground of Ramps.Terrain t. In each pixel, red is the
// Ramps.Terrain ramp, green the step offset plus 8, and alpha 0 where the sprite is empty. Not
// source_color, so Godot reads the bytes as they are.
uniform sampler2D atlas : filter_nearest, repeat_disable;
// Pixels along one side of a sprite's square in the atlas.
uniform int sprite_pixels = 16;
// The island's seed, so each island scatters its own details.
uniform int island_seed = 0;

// The share of cells of each Ramps.Terrain value that hold a detail where the clumps are at their
// average. Raising one fills that ground more densely. At 0.3 on grass, most of a screen at zoom 40
// was bare dithered color. Water and foam hold none, and snow few, because a field of snow reads
// better bare. Beach and rock hold few, so they stay open ground between the greener land.
const float DENSITY[8] = float[](0.0, 0.08, 0.45, 0.45, 0.45, 0.12, 0.03, 0.0);
// Cells one tile of `noise` covers for the clumps. Details gather where the noise is high and leave
// bare ground where it is low, so walking passes thick patches and open stretches. Lowering it
// gives smaller, more frequent clumps.
const float CLUMP_SCALE = 14.0;
// How far a detail can stand from its cell's center, as a share of the cell. Lowering it lines the
// details up in rows along the grid.
const float JITTER = 0.45;

// The sprite's square in the atlas, in sprites.
varying flat vec2 sprite;
// 1 when the sprite is drawn mirrored.
varying flat float flip;
// The ground's normal under the detail, in view space.
varying flat vec3 ground;
// The pixel's ramp and step offset, which fragment() reads from the atlas for light().
varying float pixel_kind;
varying float pixel_offset;

// A 32-bit integer hash with good mixing, from Chris Wellons' hash prospector.
uint hash(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return x;
}

// A number from 0 to 1 for the cell's hash h and a salt that picks one of several independent draws.
float draw(uint h, uint salt) {
	return float(hash(h ^ (salt * 0x9e3779b9u))) / 4294967295.0;
}

// The height of the terrain mesh's vertex on the cell at column and row, in height-map units.
float vertex_height(ivec2 cell) {
	ivec2 size = textureSize(height_map, 0);
	return max(texelFetch(height_map, clamp(cell, ivec2(0), size - 1), 0).r, 0.0);
}

// The height of the terrain mesh at point, in height-map units. The mesh has a vertex on each cell's
// center and splits each square along the diagonal from north-west to south-east, as in
// Player.height_at(), so a detail's base meets the triangles and doesn't float or sink.
float mesh_height(vec2 point) {
	vec2 p = point - 0.5;
	ivec2 nw = ivec2(floor(p));
	vec2 f = p - vec2(nw);
	float h_nw = vertex_height(nw);
	float h_se = vertex_height(nw + ivec2(1, 1));
	if (f.x >= f.y) {
		float h_ne = vertex_height(nw + ivec2(1, 0));
		return h_nw + (h_ne - h_nw) * f.x + (h_se - h_ne) * f.y;
	}
	float h_sw = vertex_height(nw + ivec2(0, 1));
	return h_nw + (h_sw - h_nw) * f.y + (h_se - h_sw) * f.x;
}

void vertex() {
	// VERTEX is the center of this quad's cell, and UV the quad's corner, with v = 1 at the bottom.
	vec3 center = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float summit = length(MODEL_MATRIX[1].xyz);
	ivec2 cell = ivec2(floor(center.xz));
	uint h = hash(uint(cell.x) ^ hash(uint(cell.y) ^ hash(uint(island_seed))));
	vec2 point = vec2(cell) + 0.5 + (vec2(draw(h, 1u), draw(h, 2u)) - 0.5) * 2.0 * JITTER;

	// The ground's material, normal and water decide as the terrain shader does, so the detail stands
	// on ground the terrain draws in the material the detail belongs to.
	vec2 uv = point / vec2(textureSize(height_map, 0));
	float height = texture(height_map, uv).r;
	vec3 normal = ground_normal(uv, height, summit);
	vec2 warp = warp_at(point);
	int kind = material_at(point, warp, height);
	float clump = 2.0 * smoothstep(0.3, 0.7, texture(noise, point / CLUMP_SCALE + vec2(0.61, 0.23)).r);
	bool stands = height > 0.0 && draw(h, 3u) < DENSITY[kind] * clump
		&& !is_cliff(point, warp) && !is_fresh_water(point, warp);

	vec3 base = vec3(point.x, mesh_height(point) * summit, point.y);
	vec3 base_view = (VIEW_MATRIX * vec4(base, 1.0)).xyz;
	// An orthographic PROJECTION_MATRIX[1][1] is 2 / the view's height in world units. Godot flips y
	// for Vulkan in the projection, so it is negative, and the sign would hang the sprite downward.
	float pixel_size = abs(2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y));
	ground = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	// Hidden until the fog has cleared all the way from the ground under it. Showing them by the
	// terrain's dithered test put sharp, full-color sprites on top of the thinning fog.
	stands = stands && !is_fogged(point, warp, 0.0);
	if (!stands) {
		// All four corners on one point draw nothing.
		VERTEX = vec3(0.0);
	} else {
		// The camera moves in whole pixels, so a base snapped to whole pixels in view space puts each
		// texel of the sprite on one screen pixel.
		base_view.xy = round(base_view.xy / pixel_size) * pixel_size;
		vec2 corner = vec2(UV.x - 0.5, 1.0 - UV.y) * float(sprite_pixels) * pixel_size;
		// Up the screen by corner.y, along the world's up axis, so the sprite stands upright in depth
		// too. A flat card facing the camera would sink into ground that rises behind it more steeply
		// than the view.
		vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
		VERTEX = base_view + vec3(corner.x, 0.0, 0.0) + up * (corner.y / up.y);
	}
	int variants = textureSize(atlas, 0).x / sprite_pixels;
	sprite = vec2(float(min(int(draw(h, 4u) * float(variants)), variants - 1)), float(kind));
	flip = draw(h, 5u) < 0.5 ? 1.0 : 0.0;
}

void fragment() {
	vec2 texel = vec2(flip > 0.5 ? 1.0 - UV.x : UV.x, UV.y);
	vec4 pixel = texture(atlas, (sprite + texel) / vec2(textureSize(atlas, 0) / sprite_pixels));
	if (pixel.a < 0.5) {
		discard;
	}
	pixel_kind = round(pixel.r * 255.0);
	pixel_offset = round(pixel.g * 255.0) - 8.0;
	NORMAL = ground;
	ALBEDO = vec3(1.0);
}

void light() {
	// Rounded instead of dithered, so a sprite a few pixels across keeps clean steps.
	DIFFUSE_LIGHT = ramp_color(clamp(dot(NORMAL, LIGHT), 0.0, 1.0), ATTENUATION, int(pixel_kind), 1.0, pixel_offset, 0.5);
}
