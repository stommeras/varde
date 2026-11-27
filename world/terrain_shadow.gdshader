shader_type spatial;
// Draws the terrain into the sun's shadow map in place of the terrain shader, pushed away from the sun.
// Under a low sun, gentle slopes shaded themselves in cell-sized triangles of shadow acne at some
// zooms. The sun's own depth bias also moves the figure's shadow off its feet, so only the terrain
// gets this one. The instance only casts shadows, so the camera here is always the sun.
render_mode unshaded, skip_vertex_transform;

// World units the terrain moves away from the sun in the shadow map. At 0.5 a few triangles stayed at
// zoom 51 in the Compatibility renderer, and at 1.5 none stayed from zoom 30 to 80 in either renderer.
// Raising it pulls the shadows of ridges back from the ridge by about as many cells.
uniform float push = 1.5;

void vertex() {
	// POSITION is ignored in the Compatibility renderer's shadow pass, so the push goes on VERTEX in
	// view space.
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.z -= push;
}

void fragment() {
	ALBEDO = vec3(0.0);
}
