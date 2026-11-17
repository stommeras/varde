shader_type spatial;
// Draws the parts of the figure that terrain hides as a flat silhouette. It is the next pass of every
// part's material, so it draws each part again after the opaque pass, over everything. Every part
// writes 1 to the stencil buffer where it shows, and this pass draws only where the stencil isn't 1.
// So a part hidden behind another part of the figure, such as the pack behind the torso, draws
// nothing, and only terrain or ground details in front leave the silhouette.
render_mode unshaded, depth_test_disabled, depth_draw_never, shadows_disabled;
stencil_mode read, compare_not_equal, 1;

// Figure sets it from Ramps.FIGURE.
uniform vec3 color : source_color;

void fragment() {
	ALBEDO = color;
}
