// Ordered dithering shared by the terrain, the ground details and the figure, so they all snap light
// to their ramps with the same pattern.

// A 4×4 Bayer matrix. Each pixel in a 4×4 block gets a different threshold, so a light level between
// two steps shows as an even pattern of both.
const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

// The dither threshold, between 0 and 1, of the pixel at pixel, counted as by screen_pixel().
float dither(vec2 pixel) {
	// Float mod, because the count is negative left of and below the origin, where % on ints is undefined.
	ivec2 cell = ivec2(mod(floor(pixel), 4.0));
	return (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
}

// A dither pattern fixed to the screen stays still while the land slides under it, so panning
// shimmers. Counting pixels along the camera's right and up axes from the world origin moves the
// pattern with the land. An orthographic projection[1][1] is 2 / the view's height in world units.
// The camera moves in whole pixels, so each pixel's count stays put as it pans.
vec2 screen_pixel(vec3 world_position, mat4 inv_view, mat4 projection, vec2 viewport_size) {
	float pixel_size = 2.0 / (projection[1][1] * viewport_size.y);
	return vec2(dot(world_position, inv_view[0].xyz), dot(world_position, inv_view[1].xyz)) / pixel_size;
}
