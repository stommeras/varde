shader_type spatial;
// Draws the ring floating over a peak's survey zone. The middle of the tube, where it faces the
// camera, is light and its edges are dark, so the ring shows against snow and against rock alike.
// It dithers in and out instead of blending, like the fog.
render_mode unshaded, shadows_disabled;

#include "res://world/dither.gdshaderinc"

// The colors of the middle at the top and the bottom of the pulse, and of the edges, from Ramps.
// ZoneRing sets them.
uniform vec3 core : source_color;
uniform vec3 core_dim : source_color;
uniform vec3 rim : source_color;
// Where the pulse is, from 0, all core_dim, to 1, all core. Between them the middle dithers.
uniform float glow = 1.0;
// How much of the ring shows, from 0, hidden, to 1. The dither drops pixels below it.
uniform float amount = 1.0;
// The tube draws as core where its normal faces the camera more than this. Raising it thins the
// light middle and widens the dark edges.
uniform float core_facing = 0.6;

void fragment() {
	vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float threshold = dither(screen_pixel(world_position, INV_VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE));
	if (threshold >= amount) {
		discard;
	}
	vec3 middle = threshold < glow ? core : core_dim;
	ALBEDO = dot(NORMAL, VIEW) > core_facing ? middle : rim;
}
