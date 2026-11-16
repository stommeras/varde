# Varde spec

## The game

You land on an unknown island with a blank map. Somewhere on the true summit stands an old varde, and a trail of smaller vardes marks the way up. You follow the trail, explore off it when you like, and the map fills in as you go. Reaching the summit varde ends the run.

The game is calm. There are no supplies, no combat and no way to fail. Curiosity about the next varde and the unmapped land is the only pressure. Each run is a new island from a new seed, and a run lasts about 20 to 40 minutes.

A run starts from a title screen with "Ny øy" and an optional seed field. Quitting ends the run, and there is no saving yet.

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

**The world is 3D, rendered as pixel art.** A terrain mesh built from the heightmap is drawn into a low-resolution viewport and scaled up with integer scaling. You move in 2D on the grid (left, right, forward, back), and the terrain rises and falls under you. The camera is orthographic, faces north and looks down at about 40° from vertical. The player can't rotate it, so "gå østover" in a note always points right on screen and on the map. Orthographic projection keeps every pixel the same size at any distance.

- Each material (sand, grass, forest, rock, snow, water) has a ramp of 4 to 6 colors. The terrain shader snaps lighting to the ramp steps with ordered dithering instead of blending smoothly. All ramps, including a warm ramp for the lamp, live in `world/ramps.gd`.
- A directional light is the sun. Its shadows fall across the terrain and move as the sun moves through the day.
- Steep faces use the rock ramp with horizontal strata, so cliffs read as cliffs from the tilted camera.
- Water gets its color from depth, with animated ripples and foam at the shore.
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
| Base resolution | Chosen by eye in milestone 2 from 480×270, 640×360 and 960×540 (each scales exactly to 1080p). Stretch mode `viewport`, integer scaling |
| Logic grid | 1024×1024 cells |
| World size | One world unit per cell. The summit stands about 60 units high, a value to tune in milestone 2 |
| Camera | Orthographic, facing north, about 40° from vertical, no rotation. The zoom (how many cells fit on screen, about 90 top to bottom to start) gets chosen by eye in milestone 2 |
| Shader inputs | Grid-sized textures for height (`FORMAT_RF`), material (`FORMAT_R8`) and knowledge (`FORMAT_R8`) |
| Noise | Godot's built-in `FastNoiseLite` |
| Controls | WASD or arrow keys to walk, E to survey a peak, M for the map |

The terrain shader generates detail finer than a cell from grid-sized textures. The terrain mesh comes in chunks, with fewer vertices for chunks far from the camera, because a single mesh of 1M cells is too heavy.

## Generator pipeline

Each step reads the arrays the earlier steps produced. All data lives in packed arrays of length 1024×1024.

1. **Height.** Layered noise, multiplied by a falloff from the center so the edges sink into the sea.
2. **Moisture.** A second noise layer.
3. **Material.** A lookup table from height and moisture to beach, grass, forest, marsh, rock or snow.
4. **Rivers.** Fill pits so water can flow out, then trace from springs at high points down the steepest slope to the sea.
5. **Features.** Find nameable things: peaks with their prominence, lakes, river forks, coves and the largest forest.
6. **Summit and route.** Pick the contenders and rescale them into a narrow height band, pick the true summit, place the clouds, place the landing beach, and find a walkable route between beach and summit.
7. **Points of interest and vardes.** Place ruins, caves and the shipwreck by rule, and the old vardes along the route.
8. **Notes.** Write each varde's note from the features between it and the next varde.

Generation runs on a background thread behind a short "charting the island" screen and may take at most 10 seconds on the dev machine. If a step pushes it over, profile it before moving it to C# or a GDExtension.

## Runtime systems

- **Line of sight** runs on the CPU and is recomputed only when the player enters a new cell, casting a few hundred rays across the heightmap.
- **Knowledge** is one byte per cell: unknown (0), seen (1) or surveyed (2). The terrain shader reads it to lower unknown land under the fog, and the map is drawn from it.
- **Movement** is free movement checked against the grid, with no physics shapes for terrain. Marsh and forest slow you down. Water blocks you, and so does a step between neighboring cells whose height difference is above a threshold, going up or down. The route guarantee in generator step 6 uses the same check, so the player can never walk into a valley with no way out.

## Project layout

```
generator/   pure GDScript classes: noise, rivers, features, route, vardes, notes -> IslandData
world/       terrain mesh chunks, the terrain shader, the camera, decoration scattering, the color ramps
player/      movement checked against the grid
map/         the map screen and contour drawing
notes/       one note template file per language
debug/       seed input, layer toggles, free camera, resolution, zoom, tilt and height sliders, sun angle, reveal-all
tests/       headless generator tests
```

## Milestones

1. **Generator and debug view.** Generate an island from a seed and show the height, moisture and material layers as images.
2. **The look.** It starts with a 3D view of a real island with a free camera, where you choose the base resolution, the zoom, the tilt and the summit height by eye. Then the terrain mesh, the terrain shader with materials, sun and shadows, and water. This step decides how the game feels, and it is done when 5 seeds look right.
3. **Walking.** Player, camera, walkability and the terrain fade in front of the player.
4. **Exploring.** Line of sight, the knowledge texture, fog with land rising out of it, peaks and surveying, and the map screen with contour lines.
5. **The summit.** Contenders and clouds, the summit varde, the trail with its notes, and the end screen.
6. **Polish.** Generated trees, the day cycle with moving shadows and the lamp, particles, glow and sound.

Work is tracked as GitHub issues, one GitHub milestone per milestone above. Ideas for after these milestones carry the `later` label, and values to adjust after playtesting carry `tuning`.

## Language

All in-game text is in Norwegian bokmål. Godot's translation system carries the UI text, so English can come later as one more column in the translation CSV.

Varde notes are generated, and Norwegian and English need different grammar, such as definite endings ("elva") and gendered words ("en elv", "et vann"). The note templates therefore live in one `ConfigFile` per language, for example `notes/nb.cfg`. Each noun lists its indefinite and definite forms, each feature type has a list of templates with `{placeholder}` slots, and directions are 8 compass words. Adding English means writing a new template file, not changing the generator. A test checks that every template loads as a string, because `ConfigFile` turns a malformed value into `null` without an error.

Notes use common nouns ("vannet", "elva") for now. Generated place names are a `later` idea.
