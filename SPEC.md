# Varde spec

## The game

You land on an unknown island with a blank map. Somewhere on the true summit stands an old varde, and a trail of smaller vardes marks the way up. You follow the trail, explore off it when you like, and the map fills in as you go. Reaching the summit varde ends the run.

The game is calm. There are no supplies, no combat and no way to fail. Curiosity about the next varde and the unmapped land is the only pressure. Each run is a new island from a new seed, and a run lasts about 20 to 40 minutes.

## Core mechanics

**Line of sight.** You see a radius around you, and higher terrain blocks your view. Standing higher increases the radius, so choosing which hill to climb is the main exploration decision.

**Automatic mapping.** The map fills in by itself, at two levels:

- Land you have seen gets coastlines, rivers and rough outlines.
- Land you have surveyed from a peak gets full detail, including hachures.

**The summit is hard to find.** Islands have three to five peaks of similar height, and from below you can't tell which is highest. The tallest peaks are often hidden in cloud. Cliffs and ridges block the direct way up, so you have to find a pass, a ridge or a valley that leads there. The generator guarantees at least one walkable route from the landing beach.

**The trail of old vardes.** Smaller vardes lie along the route to the summit. Some have fallen over or are hidden in forest. Each one has a note that points to the next, written from the island's real features ("Follow the river to where it splits, then climb east"). The trail passes the island's points of interest: ruins, caves and a shipwreck.

**Your own vardes.** You can build a varde on any peak you have surveyed. It appears on your map as a landmark and has no other effect.

**The end of a run.** At the summit varde, everything visible from the top becomes surveyed at once. The end screen shows your map next to the real island and how much of it you mapped. You can export your map as a PNG.

## Look

The style is detailed pixel art: individual pixels everywhere, textured materials, per-pixel lighting, glow and movement. None of it is drawn by hand.

- Each material (sand, grass, forest, rock, snow, water) has a ramp of 4 to 6 colors. Lighting snaps to the ramp steps with ordered dithering instead of blending smoothly.
- Hillshading comes from the heightmap, lit from a sun direction. Cast shadows come from stepping across the heightmap toward the sun, and they move as the sun moves through the day.
- Water gets its color from depth, with animated ripples and foam at the shore.
- Noise distorts material boundaries so the logic grid never shows.
- Trees, rocks and grass tufts are sprites generated at startup, with 20 to 30 variants per biome, scattered using noise.
- `GPUParticles2D` adds birds, falling leaves and mist. 2D HDR and glow give bloom.
- Unexplored land is fog with a dithered edge.

**The map screen** is ink on aged paper. Hachures show slopes: short strokes pointing downhill, longer and thicker where the slope is steeper. Draw them on the CPU in the map's `_draw()` with a jittered grid of about 6 pixels, and redraw only when the player surveys new land.

## Specs

| Item | Value |
|---|---|
| Engine | Godot 4 (latest stable), GDScript |
| Base resolution | 640×360, stretch mode `viewport`, integer scaling |
| Logic grid | 1024×1024 cells |
| World size | 4096×4096 pixels (4 pixels per cell) |
| Shader inputs | Grid-sized textures for height (`FORMAT_RF`), material (`FORMAT_R8`) and knowledge (`FORMAT_R8`) |
| Noise | Godot's built-in `FastNoiseLite` |
| Controls | WASD or arrow keys, M for the map |

The shader generates fine detail from grid-sized textures. A 4096×4096 texture per layer would cost 64 MB each.

## Generator pipeline

Each step reads the arrays the earlier steps produced. All data lives in packed arrays of length 1024×1024.

1. **Height.** Layered noise, multiplied by a falloff from the center so the edges sink into the sea.
2. **Moisture.** A second noise layer.
3. **Material.** A lookup table from height and moisture to beach, grass, forest, marsh, rock or snow.
4. **Rivers.** Fill pits so water can flow out, then trace from springs at high points down the steepest slope to the sea.
5. **Features.** Find nameable things: peaks, lakes, river forks, coves and the largest forest.
6. **Summit and route.** Pick the true summit, place the landing beach, and find a walkable route between them.
7. **Points of interest and vardes.** Place ruins, caves and the shipwreck by rule, and the old vardes along the route.
8. **Notes.** Write each varde's note from the features between it and the next varde.

Generation runs on a background thread behind a short "charting the island" screen.

## Runtime systems

- **Line of sight** runs on the CPU and is recomputed only when the player enters a new cell, casting a few hundred rays across the heightmap.
- **Knowledge** is one byte per cell: unknown (0), seen (1) or surveyed (2). The fog and the map are drawn from it.
- **Movement** is free movement checked against the grid, with no physics shapes for terrain. Marsh and forest slow you down. Water and steep cliffs block you.

## Project layout

```
generator/   pure GDScript classes: noise, rivers, features, route, vardes, notes -> IslandData
world/       the island shader, a Sprite2D sized to the world, decoration scattering
player/      movement checked against the grid
map/         the map screen and hachure drawing
debug/       seed input, layer toggles, reveal-all
tests/       headless generator tests
```

## Milestones

1. **Generator and debug view.** Generate an island from a seed and show the height, moisture and material layers as images.
2. **The look.** The world shader with materials, hillshading and water. This step decides how the game feels.
3. **Walking.** Player, camera and walkability.
4. **Exploring.** Line of sight, the knowledge texture, fog, and the map screen with hachures.
5. **The summit.** The summit varde, the trail with its notes, building your own vardes, and the end screen.
6. **Polish.** Generated trees, a day cycle with moving shadows, particles, glow and sound.

## Language

All in-game text is in Norwegian bokmål. Godot's translation system carries the UI text, so English can come later as one more column in the translation CSV.

Varde notes are generated, and Norwegian and English need different grammar, such as definite endings ("elva") and gendered words ("en elv", "et vann"). The note templates therefore live in one file per language. Adding English means writing a new template file, not changing the generator.
