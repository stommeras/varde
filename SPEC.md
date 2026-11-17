# Varde spec

Nothing here is final. Agents made most of these choices while building the game, and any of them can change when another choice gives a better result. The PR that changes one updates this file and shows why.

## The game

You land on an unknown island with a blank map. Somewhere on the true summit stands an old varde, and a trail of smaller vardes marks the way up. You follow the trail, explore off it when you like, and the map fills in as you go. Reaching the summit varde ends the run.

The game is calm. There are no supplies, no combat and no way to fail. Curiosity about the next varde and the unmapped land is the only pressure. Each run is a new island from a new seed, and a run lasts about 20 to 40 minutes.

A run starts from a title screen with "Ny øy" and an optional seed field. An empty field gives a random seed, a number is the seed itself, and any other text is hashed into one. Once the island shows, Escape pauses the run behind a menu with "Fortsett" and "Avslutt". "Avslutt" ends the run and goes back to the title screen, and there is no saving yet.

## Core mechanics

**Line of sight.** You see a radius around you, and higher terrain blocks your view. The radius is 40 cells at sea level and grows to about 120 cells at summit height, so choosing which hill to climb is the main exploration decision. Land you have seen stays revealed and never fades back into fog. All radii are starting values to tune in milestone 4.

**Automatic mapping.** The map fills in at two levels:

- Walking marks land in your line of sight as seen. Seen land gets coastlines, rivers and rough outlines on the map.
- Surveying from a peak marks land as surveyed. Surveyed land also gets contour lines.

**Peaks and surveying.** The generator stores every peak that rises at least about 15% of the summit's height above the saddle to any higher peak. That gives 8 to 14 peaks per island, a number to tune after playtesting. Each peak has a survey zone with a radius of about 6 cells. Standing in a zone shows "Kartlegg toppen", and pressing E plays a short survey animation. Surveying uses the same line of sight with twice the walking radius and marks everything it reaches as surveyed. The animation ends with your character stacking a varde on the peak, so every surveyed peak gets one of your vardes on the map. Your vardes have no other effect.

**The summit is hard to find.** Three to five contender peaks have heights within about 10 to 15% of each other, and only some of them reach snow. The generator rescales only the contenders into that band and leaves the smaller peaks and hills alone, which can be half the summit's height or lower. From below you can't tell which contender is highest. Cliffs and ridges block the direct way up, so you have to find a pass, a ridge or a valley that leads there. The generator guarantees at least one walkable route from the landing beach.

**Clouds.** Each contender has a 50% chance of a static cloud cap that covers everything above a set height on that peak. The true summit follows the same rule, so a cloud never gives it away. Inside a cloud your view radius drops to about 8 cells. Surveying a clouded peak ignores the cloud, and the cloud fades during the survey animation and stays gone for the rest of the run.

**The trail of old vardes.** Six to ten old vardes lie along the route to the summit, about 60 to 120 cells apart. Some have fallen over or are hidden in forest. Each one has a note that points to the next, written from the island's real features ("Følg elva til den deler seg, og gå østover"). A note names a feature in the direction of the next varde, and that feature does not have to be in direct line of sight. The trail passes the island's points of interest: ruins, caves and a shipwreck. Vardes you have found and notes you have read show on the map screen, where you can read the notes again.

**Day and night.** A full day lasts about 16 minutes: dawn, about 10 minutes of day, dusk and about 4 minutes of night. A run starts at dawn. When the light falls below a threshold, your character takes out an oil lamp by itself and puts it away at dawn. At night the walking line of sight shrinks to the lamp's light, about 20 cells. Surveying still reaches its full radius by moonlight, and the survey animation lifts the landscape into moonlight as it reveals it.

**The end of a run.** At the summit varde, everything visible from the top becomes surveyed at once. The end screen shows your map next to the real island, the share of land cells you saw, the share you surveyed, how many vardes you built, how many old vardes you found, and the seed. You can export your map as a PNG.

## Look

The style is detailed pixel art: individual pixels everywhere, textured materials, per-pixel lighting, glow and movement. None of it is drawn by hand.

**The world is 3D, rendered as pixel art.** A terrain mesh built from the heightmap is drawn into a low-resolution viewport and scaled up with integer scaling. You move in 2D on the grid (left, right, forward, back), and the terrain rises and falls under you. The camera is orthographic, faces north and looks down at 45° from vertical. The player can't rotate it, so "gå østover" in a note always points right on screen and on the map. Orthographic projection keeps every pixel the same size at any distance.

- Each material (sand, grass, forest, rock, snow, water) has a ramp of 4 to 6 colors. The terrain shader snaps lighting to the ramp steps with ordered dithering instead of blending smoothly. All ramps, including the foam ramp and a warm ramp for the lamp, live in `world/ramps.gd`.
- A directional light is the sun. Its shadows fall across the terrain and move as the sun moves through the day. The sun crosses the sky from east to west in a half circle that stands 45° above the southern horizon at noon. A cast shadow is one ramp step darker than a face turned away from the sun. Under a low sun, flat ground gets little more light than the shade side, and without the extra step its shadows barely show. The debug view has a sun-angle slider to check the shadows from morning to evening.
- Faces steeper than about 73° use the rock ramp with wide horizontal strata, about 5 world units apart, so cliffs read as cliffs from the tilted camera. With a 60° threshold and bands 1.2 units apart, the eroded mountainsides turned to rock and the strata drew rings around whole mountains.
- Water gets its color from depth, with animated ripples and foam at the shore. The sea is part of the terrain mesh, flat at sea level, and the terrain shader reads its depth from the height map. Shallow water reaches the light end of the water ramp, and water about 50 cells out reaches its darkest step. Thin ripple crests, one step lighter, drift across the whole sea. Bands of foam roll in toward the coast over the last 6 cells and thin out with depth, and an unbroken line of foam runs along the coast. Foam has its own ramp, so it shades with the sun like the land. Rivers and lakes use the water ramp at its full reach, with the same ripples. Rivers keep the slope's shading and run over cliffs as waterfalls, and lakes are flat.
- Noise distorts material boundaries so the logic grid never shows.
- Trees, rocks and grass tufts are sprites generated at startup, with 20 to 30 variants per biome, scattered using noise and drawn as billboards. 3D trees are a `later` idea if billboards look flat.
- When terrain stands between the camera and the player, the terrain in front of the player fades out with a dithered edge.
- The lamp is an `OmniLight3D` whose energy and offset flicker from noise, snapped to the lamp ramp with dithering, with a few embers from `GPUParticles3D`.
- `GPUParticles3D` adds birds, falling leaves and mist. Glow in the `WorldEnvironment` gives bloom.
- Unexplored land lies flat at sea level under a dithered fog. When you see it, it rises to its real height over about a second, so the land grows out of the mist. That way the silhouettes of unexplored peaks never give the summit away.

**The map screen** is ink on aged paper, drawn once at 1024×1024 pixels (one pixel per cell) into a `SubViewport`. You pan and zoom the resulting texture, and the PNG export uses it at full size. North is always up, and a marker shows where you are. Surveyed land gets contour lines from marching squares over the heightmap, with every fifth line thicker. The map redraws only when the player surveys new land. The art style of the map is open for later.

## Specs

| Item | Value |
|---|---|
| Engine | Godot 4.7, GDScript |
| Base resolution | 960×540, chosen by eye in milestone 2 over 480×270 and 640×360. It scales exactly to 1080p. Stretch mode `viewport`, integer scaling |
| Logic grid | 1024×1024 cells |
| World size | One world unit per cell. The summit stands 100 units high, chosen by eye in milestone 2 |
| Camera | Orthographic, facing north, 45° from vertical, no rotation. The zoom fits 80 cells of flat ground from the top to the bottom of the screen. Milestone 2 chose both by eye, and they can change once walking shows how far ahead the player needs to see |
| Shader inputs | Grid-sized textures for height (`FORMAT_RF`), material (`FORMAT_R8`), rivers and lakes (`FORMAT_R8`) and knowledge (`FORMAT_R8`) |
| Noise | Godot's built-in `FastNoiseLite` |
| Controls | WASD or arrow keys to walk, E to survey a peak, M for the map |

The terrain shader generates detail finer than a cell from grid-sized textures. The terrain mesh comes in chunks of 64×64 cells, because a single mesh of 1M cells is too heavy. The renderer skips the chunks off screen, which at the game's zoom of 80 cells leaves 6 to 12 of the 256. Each chunk also has a coarser level with every second vertex, which Godot draws when a pixel covers 2 cells or more. The camera is orthographic, so the level follows the zoom instead of the distance from the camera, and all chunks on screen draw at the same level and meet without cracks.

## Generator pipeline

Each step reads the arrays the earlier steps produced. All data lives in packed arrays of length 1024×1024.

1. **Height.** Layered noise, multiplied by a falloff from the center so the edges sink into the sea. River erosion then cuts the big mountains into branching valleys with sharp ridges between them. It runs on a 256×256 grid: water routes downhill to a random lower neighbor weighted by slope, and each cell is rebuilt from the lowland up with a slope that shrinks as more water drains through it. Crags and cliffs go onto the high ground after erosion, so the cliffs follow the valley walls.
2. **Moisture.** A second noise layer.
3. **Material.** A lookup table from height and moisture to beach, grass, forest, marsh, rock or snow. A flood fill then marks the main island, the largest connected land area. Islets off its coast stay as scenery the player can see but not reach, and stats, peaks, vardes and points of interest use only the main island.
4. **Rivers.** About 30 springs, at least 60 cells apart, lie on the main island's high ground. Each spring sends a river downhill, at each step to a random lower neighbor weighted by slope, because always taking the steepest one ran the rivers in straight lines along the grid's 8 directions. A river that runs into a pit fills it up to the lowest point on its rim and runs on from there. The filled pit stays flat in the height map as a lake. A river that meets an earlier one joins it and ends there, so the rivers form branching networks. Pits get filled only where a river finds one, because filling the whole grid first takes seconds in GDScript. The generator keeps a mask of the lake cells, because lakes block the player and rivers don't. Rivers widen downstream with the square root of the river cells above them, from 1 cell to 5.
5. **Features.** Find nameable things: peaks with their prominence, lakes, river forks, coves and the largest forest.
6. **Summit and route.** Pick the contenders and rescale them into a narrow height band, pick the true summit, place the clouds, place the landing beach, and find a walkable route between beach and summit.
7. **Points of interest and vardes.** Place ruins, caves and the shipwreck by rule, and the old vardes along the route.
8. **Notes.** Write each varde's note from the features between it and the next varde.

Generation runs on a background thread behind a short "charting the island" screen and may take at most 10 seconds on the dev machine. If a step pushes it over, profile it before moving it to C# or a GDExtension.

## Runtime systems

- **Line of sight** runs on the CPU and is recomputed only when the player enters a new cell, casting a few hundred rays across the heightmap.
- **Knowledge** is one byte per cell: unknown (0), seen (1) or surveyed (2). The terrain shader reads it to lower unknown land under the fog, and the map is drawn from it.
- **Movement** is free movement checked against the grid, with no physics shapes for terrain. `generator/walkability.gd` holds the step check, and the route guarantee in generator step 6 uses the same check, so the player can never walk into a valley with no way out.
  - The sea and lakes block. Rivers can be waded at half speed. Blocking rivers too left 90 to 97% of the land reachable on seeds 0 to 4, but meant a detour round a spring every hundred cells or so along the coast.
  - A step between neighboring cells blocks, going up or down, where its slope is steeper than the one at which the terrain shader draws cliff rock (`cliff_normal_y = 0.3`, about 3.2 world units per cell at a summit of 100), so every wall the player meets looks like one. On seeds 0 to 4, 99% of the blocked edge steps start or end on a cell whose own slope the shader draws as rock. A corner step also needs the edge steps to both cells beside it open, so the player can't slip between two cliff corners. If the summit turns out too easy to reach, milestone 5 adds cliffs in the generator rather than invisible walls.
  - The player walks 6 cells per second on open ground, in 8 directions with diagonals as fast as straight lines. A move into a step the check refuses keeps only its east-west or north-south part, so the player slides along walls. The figure stands on the terrain mesh's triangles, not a smoothed height, so its feet meet the ground on steep slopes.
  - The figure is a 6×10 pixel billboard that code draws at startup, with front, back and side views and a walk cycle of standing and two steps, one frame per half cell walked. It draws over the terrain, because a camera-facing quad leans back with the camera and a slope up to the north would cut off its head. The camera centers on the figure, and both snap to the same pixel grid, so the figure holds still on screen while the ground moves under it in whole pixels.
  - Forest walks at 0.75 of full speed, marsh at 0.6 and a river at 0.5, values to tune after playtesting.
  - The player starts on a random beach cell of the main island that reaches at least 20,000 cells, so a cove walled in by cliffs can't trap them. From there 93 to 98% of the main island is reachable on seeds 0 to 4, and lakes take most of the rest. Milestone 5 replaces this start with the landing beach.

## Project layout

```
generator/   pure GDScript classes: noise, rivers, features, route, vardes, notes -> IslandData
game/        the title screen, which is the main scene, and the game scene for one run
world/       terrain mesh chunks, the terrain shader, the camera, the sun, the island loader, decoration scattering, the color ramps
player/      movement checked against the grid
map/         the map screen and contour drawing
notes/       one note template file per language
debug/       seed input, layer toggles, free camera, resolution, zoom, tilt and height sliders, sun angle, reveal-all
tests/       headless generator tests
```

## Milestones

1. **Generator and debug view.** Generate an island from a seed and show the height, moisture and material layers as images.
2. **The look.** It starts with a 3D view of a real island with a free camera, where you choose the base resolution, the zoom, the tilt and the summit height by eye. Then the terrain mesh, the terrain shader with materials, sun and shadows, and water. This step decides how the game feels, and it is done when 5 seeds look right.
3. **Walking.** The title screen and the game scene, then the player, camera, walkability and the terrain fade in front of the player.
4. **Exploring.** Line of sight, the knowledge texture, fog with land rising out of it, peaks and surveying, and the map screen with contour lines.
5. **The summit.** Contenders and clouds, the summit varde, the trail with its notes, and the end screen.
6. **Polish.** Generated trees, the day cycle with moving shadows and the lamp, particles, glow and sound.

Work is tracked as GitHub issues, one GitHub milestone per milestone above. Ideas for after these milestones carry the `later` label, and values to adjust after playtesting carry `tuning`.

## Language

All in-game text is in Norwegian bokmål. Godot's translation system carries the UI text, so English can come later as one more column in the translation CSV.

Varde notes are generated, and Norwegian and English need different grammar, such as definite endings ("elva") and gendered words ("en elv", "et vann"). The note templates therefore live in one `ConfigFile` per language, for example `notes/nb.cfg`. Each noun lists its indefinite and definite forms, each feature type has a list of templates with `{placeholder}` slots, and directions are 8 compass words. Adding English means writing a new template file, not changing the generator. A test checks that every template loads as a string, because `ConfigFile` turns a malformed value into `null` without an error.

Notes use common nouns ("vannet", "elva") for now. Generated place names are a `later` idea.
