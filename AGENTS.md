# Varde

A calm, run-based exploration game made in Godot 4. Each run generates an island, and the player follows a trail of old vardes (cairns) to the one on the true summit while the map fills in. `SPEC.md` holds the design and the plan. Read it before changing gameplay.

## Conventions

- Write all code in GDScript with static types. Use C# or a GDExtension only for a step that GDScript makes too slow, and say which step and how slow.
- Nothing is drawn by hand. The generator, shaders and code produce terrain, sprites and effects. Add an image file only when code can't produce it, and say why.
- The same seed must always give the same island. Pass a seeded `RandomNumberGenerator` or seed value through the generator. Never call the global `randi()` or `randf()` there.
- Keep `generator/` free of nodes and scenes. It takes a seed and returns `IslandData`, so it runs in tests and on a background thread.
- Generator tests live in `tests/` and run headless with `godot --headless -s tests/run.gd`. On a fresh clone, run `godot --headless --import` once first, so Godot registers the `class_name` classes and imports the translations. A change is done when the tests pass and the project opens without errors.
- Write all in-game text in Norwegian bokmål. UI text goes through `tr()` with a key and lives in the translation CSV, never as a literal in a script or scene. Varde note templates live in one file per language.
- Every color comes from the ramps in `world/ramps.gd`. When the look needs a new color, add it to a ramp or change a ramp, so shaders and scripts never hold a color of their own.
- Work on a branch named `<type>/<short-description>` (for example `feat/river-tracing`) and merge to `main` through a pull request. Write commit messages as [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`), using the same types as the branch names.
- Track work in GitHub issues. Name the issue a PR finishes with `Closes #<number>` in the PR body, or `Part of #<number>` if it finishes only part.
- Comment the why, not the what. Give every class and public function a `##` doc comment. Explain each tuning constant (what raising or lowering it does), non-obvious math, and workarounds for engine quirks. Don't write comments that restate the code.

## Workflow

1. Start from an issue. Read it and the parts of `SPEC.md` it touches, then branch from an up-to-date `main`.
2. Treat `SPEC.md`, the ramps, the tuning values and the code as working choices. Agents made most of them, and none is final. When a different choice gives a better result, including one the issue asks for, make it. Show the result in the PR with frames, test output or timings, and update `SPEC.md` in the same PR. Ask first when the choice changes how the game plays, or when the result is a matter of taste that frames can't settle.
3. Run the tests while you work and before you open the PR. CI runs them again on every PR.
4. Look at anything visual before calling it done. Record a few frames of a scene with `godot <scene.tscn> --write-movie <dir>/f.png --fixed-fps 10 --quit-after 5`, read the last frame, and put the image path or a description in the PR.
5. Open the PR with what changed, what you checked, and anything left for the user to judge, such as how a tuning value looks.

## Gotchas

- `Material` is a built-in Godot class. Don't name an enum or class after a built-in, and don't name a variable `seed`, which shadows the global `seed()`.
- A typed `const` dictionary of `PackedColorArray` values loads wrong colors, and `PackedColorArray(...)` isn't a constant expression. Use a `static var`.
- Each script has a `.uid` file next to it. Commit it, and delete it with the script.
- Godot rewrites `project.godot` while the editor is open. Change project settings in the editor, not in the file, unless the editor is closed.
- Leave throwaway debug scripts in `tests/` only while you use them, and delete them with their `.uid` file.
