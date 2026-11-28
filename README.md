# Varde

A calm exploration game made in Godot 4. Each run generates a new island from a seed. You land on a beach with a blank map and look for the true summit, climbing mountains marked with old vardes (cairns), while the map fills in as you go. There are no supplies, no combat and no way to fail.

Nothing is drawn by hand. The generator, shaders and code make the terrain, the figure and the details on the ground. All text in the game is in Norwegian bokmål.

The game is in progress. The generator and the look are done: erosion, rivers, a sea with depth and foam, and sun shadows, drawn in 3D as pixel art. You can walk the island while the fog clears where you look, survey a peak and build a varde on it, and open a map that fills in with what you have seen. Lines of old vardes mark the way up some mountains, and the note at the top of each names the direction of a higher peak and a feature beside it, such as a lake or a river. The summit varde comes next. [SPEC.md](SPEC.md) describes the whole game and lists the milestones.

You can play the latest release in the browser or download it for Windows and Linux at [varde.tommeras.no](https://varde.tommeras.no). It works best on a desktop with a keyboard.

## Controls

| Key | What it does |
| --- | --- |
| WASD or arrow keys | Walk |
| Q and E | Turn the camera |
| F | Survey a peak you stand near, or read the note on a varde or the wreck |
| M | Open the map |
| Mouse wheel or + and - | Zoom |
| Escape | Pause the run |

## Build

You need Godot 4.7.2.

| Command | What it does |
| --- | --- |
| `godot --headless --import` | Imports the project. Run it once on a fresh clone |
| `godot -e` | Opens the editor |
| `godot` | Runs the game from the title screen |
| `godot --headless -s tests/run.gd` | Runs the tests |

[docs/releasing.md](docs/releasing.md) explains how to export the web, Linux and Windows builds and how a version tag releases them.

[AGENTS.md](AGENTS.md) has the conventions for working on the code.
