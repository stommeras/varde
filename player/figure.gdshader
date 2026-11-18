shader_type spatial;
// Draws one part of the walking figure the way the terrain shader draws the land. Light picks a
// position along the part's ramp from Ramps.FIGURE, and ordered dithering snaps it to one of the
// two nearest steps. The head also paints the eyes and the hair from its own normals, so they turn
// with the figure.
render_mode ambient_light_disabled;
// Marks the pixels where the figure shows, so silhouette.gdshader leaves them alone.
stencil_mode write, compare_always, 1;

#include "res://world/dither.gdshaderinc"

// Row p holds the steps of the ramp for Ramps.FigurePart p, darkest first, as linear colors. Figure
// builds it. Not source_color, because the Compatibility renderer skips that decode in texelFetch.
uniform sampler2D ramps : filter_nearest, repeat_disable;
// Steps in each ramp. Every figure ramp has the same count.
uniform int steps = 3;
// The Ramps.FigurePart this part uses.
uniform int part = 0;
// True on the head, which paints eyes and hair over the skin.
uniform bool face = false;
// Ramp position, from 0 to 1, of faces turned away from the sun, as in the terrain shader. The
// figure's ramps are short, so at the terrain's 0.3 the shade side dithers between the dark and middle
// steps. Raising it lightens the shade side.
uniform float shade = 0.3;
// Ramp steps a cast shadow takes off, as in the terrain shader.
uniform float shadow_steps = 1.0;
// The share of the way between two ramp steps over which they dither, centered on halfway. At 1 the
// figure dithers like the terrain, across the whole gap. A round part spans every light level, so on
// a figure a dozen pixels wide that turned the coat into a checkerboard. Lowering it gives flat steps with
// a thin dithered seam, and 0 gives hard edges.
uniform float dither_band = 0.3;
// Where the eyes sit on the head, as a direction in the head's own space: x apart, y up, and -z
// forward. Raising x spreads them, raising y lifts them toward the cap.
uniform vec3 eye = vec3(0.38, -0.12, -0.92);
// Cosine of the angle an eye covers from its center. At zoom 40 an eye of 0.975 covers about one
// pixel. Lowering it makes the eyes bigger.
uniform float eye_size = 0.975;
// The head's normals with a z above this are hair. Lowering it moves the hairline forward over the
// ears, raising it toward the back of the head.
uniform float hairline = 0.15;

varying vec3 local_normal;
varying vec2 world_pixel;
// The Ramps.FigurePart row of this pixel. Floats, because light() reads it.
varying float row;
// Ramp steps to darken this pixel by, so the eyes stay dark on the lit side of the head.
varying float darken;

void vertex() {
	local_normal = NORMAL;
}

void fragment() {
	row = float(part);
	darken = 0.0;
	if (face) {
		vec3 n = normalize(local_normal);
		vec3 left = normalize(eye * vec3(-1.0, 1.0, 1.0));
		if (dot(n, normalize(eye)) > eye_size || dot(n, left) > eye_size) {
			row = 1.0;  // Ramps.FigurePart.HAIR
			darken = float(steps);
		} else if (n.z > hairline) {
			row = 1.0;
		}
	}
	ALBEDO = vec3(1.0);
	vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pixel = screen_pixel(world_position, INV_VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE);
}

void light() {
	// The same lighting as the terrain shader's light(), which explains each step.
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = facing * ATTENUATION;
	float cast = (1.0 - ATTENUATION) * smoothstep(0.0, 0.05, facing);
	float position = mix(shade, 1.0, lit) * float(steps - 1) - shadow_steps * cast - darken;
	float lower = floor(position);
	float between = clamp((position - lower - 0.5) / max(dither_band, 0.001) + 0.5, 0.0, 1.0);
	int ramp_step = clamp(int(lower) + int(between > dither(world_pixel)), 0, steps - 1);
	DIFFUSE_LIGHT = texelFetch(ramps, ivec2(ramp_step, int(row)), 0).rgb;
}
