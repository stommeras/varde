# Varde

A calm, run-based exploration game made in Godot 4. Each run generates an island, and the player follows a trail of old vardes (cairns) to the one on the true summit while the map fills in. `SPEC.md` holds the design and the plan. Read it before changing gameplay.

## Conventions

- Write all code in GDScript with static types. Use C# or a GDExtension only for a step that GDScript makes too slow, and say which step and how slow.
- Nothing is drawn by hand. The generator, shaders and code produce terrain, sprites and effects. Add an image file only when code can't produce it, and say why.
- The same seed must always give the same island. Pass a seeded `RandomNumberGenerator` or seed value through the generator. Never call the global `randi()` or `randf()` there.
- Keep `generator/` free of nodes and scenes. It takes a seed and returns `IslandData`, so it runs in tests and on a background thread.
- Generator tests live in `tests/` and run headless with `godot --headless -s tests/run.gd`. A change is done when the tests pass and the project opens without errors.
- Every color comes from the ramps defined in one place (see `SPEC.md`). Don't add one-off colors in shaders or scripts.
- Work on a branch named `<type>/<short-description>` (for example `feat/river-tracing`) and merge to `main` through a pull request. Write commit messages as [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`), using the same types as the branch names.
