shader_type canvas_item;
// Draws the map screen as ink on paper, one pixel per cell, from the island's grids and the
// player's knowledge. Unknown cells stay blank paper. Seen cells get the coast, rivers, lakes, a
// wash over the sea and faint outlines of forest and snow. Surveyed land also gets contour lines.
//
// The colors come from Ramps.MAP as plain vec4 uniforms. The 2D renderer works in sRGB with HDR 2D
// off, so the values go out as they are, with no source_color decoding.

uniform sampler2D height_map : filter_nearest;
uniform sampler2D material_map : filter_nearest;
uniform sampler2D fresh_water_map : filter_nearest;
uniform sampler2D knowledge_map : filter_nearest;

uniform vec4 paper_stain;
uniform vec4 paper;
uniform vec4 paper_land;
uniform vec4 ink;
uniform vec4 ink_faded;
uniform vec4 water_ink;
uniform vec4 sea_wash;

// Height-map units between two contour lines, where the summit is 1.0. Lowering it draws more lines.
// At 0.02 a line runs every 2 world units and every fifth, the thick one, every 10.
uniform float contour_interval = 0.02;
// Share of paper cells stained one step darker, the grain of the aged paper. 0 gives a clean sheet.
uniform float grain = 0.06;
// Distance from the middle of the sheet, in halves of its width, at which the edges start to yellow.
// Raising it pushes the stained edge outward.
uniform float stain_start = 0.85;

// The Ramps.Terrain values the shader outlines, kept in step with world/ramps.gd.
const int FOREST = 3;
const int SNOW = 6;
const int SIZE = 1024;

// Each cell's value at the far edge of the grid repeats, so the edge draws no coast or contour.
ivec2 clamped(ivec2 cell) {
	return clamp(cell, ivec2(0), ivec2(SIZE - 1));
}

float height_at(ivec2 cell) {
	return texelFetch(height_map, clamped(cell), 0).r;
}

int material_at(ivec2 cell) {
	return int(round(texelFetch(material_map, clamped(cell), 0).r * 255.0));
}

bool water_at(ivec2 cell) {
	return texelFetch(fresh_water_map, clamped(cell), 0).r > 0.0;
}

int level_at(ivec2 cell) {
	return int(round(texelFetch(knowledge_map, clamped(cell), 0).r * 255.0));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	ivec2 cell = ivec2(UV * float(SIZE));
	vec2 from_middle = abs(UV - 0.5) * 2.0;
	bool stained = hash(vec2(cell)) < grain
		|| hash(vec2(cell) + 17.0) < smoothstep(stain_start, 1.0, max(from_middle.x, from_middle.y));
	COLOR = stained ? paper_stain : paper;
	int level = level_at(cell);
	if (level > 0) {
		float h = height_at(cell);
		ivec2 sides[4] = ivec2[](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
		if (h <= 0.0) {
			// The sea the player has seen under a pale wash, so the coast reads from both sides. A
			// checkered wash blended back into the paper at zoom 1 and below.
			COLOR = sea_wash;
		} else {
			COLOR = paper_land;
			int band = int(floor(h / contour_interval));
			int terrain = material_at(cell);
			bool coast = false;
			bool outline = false;
			bool thin = false;
			bool thick = false;
			for (int i = 0; i < 4; i++) {
				ivec2 next = cell + sides[i];
				float other = height_at(next);
				coast = coast || other <= 0.0;
				int next_terrain = material_at(next);
				outline = outline || ((terrain == FOREST || terrain == SNOW) && next_terrain != terrain && other > 0.0);
				int next_band = int(floor(other / contour_interval));
				// A line lies on the upper side of each step between bands, so it is one cell wide. A
				// line every fifth band also takes the lower side, two cells wide.
				thin = thin || next_band < band;
				thick = thick || (next_band < band && band / 5 > next_band / 5) || (next_band > band && next_band / 5 > band / 5);
			}
			if (outline && (cell.x + cell.y) % 2 == 0) {
				COLOR = ink_faded;
			}
			if (level > 1 && !water_at(cell)) {
				if (thick) {
					COLOR = ink;
				} else if (thin) {
					COLOR = ink_faded;
				}
			}
			if (water_at(cell)) {
				COLOR = water_ink;
			}
			if (coast) {
				COLOR = ink;
			}
		}
	}
}
