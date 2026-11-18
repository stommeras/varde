# Varde

A calm exploration game made in Godot 4. Each run generates a new island from a seed. You land on a beach with a blank map and follow a trail of old vardes (cairns) to the one on the true summit, while the map fills in as you go. There are no supplies, no combat and no way to fail.

Nothing is drawn by hand. The generator, shaders and code make the terrain, the figure and the details on the ground. All text in the game is in Norwegian bokmål.

The game is in progress. The generator and the look are done: erosion, rivers, a sea with depth and foam, and sun shadows, drawn in 3D as pixel art. You can walk the island now. Line of sight, the map, the vardes and the summit come next. [SPEC.md](SPEC.md) describes the whole game and lists the milestones.

You can play the current build in the browser at [lab.tommeras.no/varde](https://lab.tommeras.no/varde/). It works best on a desktop with a keyboard.

## Controls

| Key | What it does |
| --- | --- |
| WASD or arrow keys | Walk |
| Escape | Pause the run |

## Build

You need Godot 4.7.2.

| Command | What it does |
| --- | --- |
| `godot --headless --import` | Imports the project. Run it once on a fresh clone |
| `godot -e` | Opens the editor |
| `godot` | Runs the game from the title screen |
| `godot --headless -s tests/run.gd` | Runs the tests |
| `godot --headless --export-release Web build/web/index.html` | Exports the web build. Needs the 4.7.2 export templates |

The web build uses threads, so the server has to send `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.

[AGENTS.md](AGENTS.md) has the conventions for working on the code.
