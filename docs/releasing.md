# Releasing

A release is a version tag on `main`. Pushing the tag starts `.github/workflows/release.yml`, which:

1. runs the tests,
2. writes the tag into `application/config/version` in `project.godot`, which the title screen and the pause menu show,
3. exports the `Linux`, `Windows` and `Web` presets in `export_presets.cfg` with the release templates,
4. publishes a GitHub Release with `varde-linux.zip`, `varde-windows.zip` and `varde-web.zip` and notes generated from the merged PRs,
5. runs `.github/workflows/site.yml`, which deploys [varde.tommeras.no](https://varde.tommeras.no) with the new web build.

If the tests fail, nothing is published. A release build leaves out debug-only code such as god mode.

## Versions

Versions are `v0.<milestone>.<patch>`. The release that closes milestone 4 is `v0.4.0`, and a fix to it is `v0.4.1`. Milestone 6 done is `v1.0.0`. AGENTS.md says when a release is due.

The site and the download buttons follow the release GitHub marks as latest. The workflow marks a new release latest only when its version is higher than the current latest, so a patch to an older version, such as `v0.3.1` after `v0.4.0`, is published without moving the site or the downloads back.

## Make a release

```console
$ git switch main && git pull
$ git tag v0.4.0
$ git push origin v0.4.0
```

The workflow takes a few minutes. Check the Actions tab, then the release page and the site.

If a release fails halfway, delete the release on GitHub if it got that far, delete the tag, fix the problem on `main` and tag again:

```console
$ gh release delete v0.4.0 --yes
$ git push --delete origin v0.4.0 && git tag -d v0.4.0
```

## The site

The version number belongs to the game, so the page deploys apart from it. `.github/workflows/site.yml` takes the page from `main` and the game from the latest release, and puts together `build/site/` like this:

```
index.html     site/index.html, in bokmål, with __VERSION__ replaced by the latest tag
vercel.json    the headers
fonts/         site/fonts, Literata and its license
backdrop.png   game/backdrop.png, the title screen's backdrop
spill/         varde-web.zip from the latest release, unpacked
```

It runs after every release, and on every push to `main` that changes `site/` or `game/backdrop.png`. A fix to the page goes live when it merges, with no tag. The page follows `main` and the game follows the latest tag, so describe a new key or feature on the page only once it is released. To deploy by hand, run the `site` workflow from the Actions tab.

The download buttons point at `releases/latest/download/varde-linux.zip` and `varde-windows.zip`, so they always fetch the newest release without changing the page. The page takes its colors from the `MAP` ramps in `world/ramps.gd`. When the ramps change, change the page to match.

The web build uses threads, so every page sends `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. Without them the browser gives the page no `SharedArrayBuffer` and the game doesn't start. GitHub Pages can't send these headers, which is why the site is on Vercel.

## Build it locally

You need Godot 4.7.2 and its export templates (Editor → Manage Export Templates).

```console
$ mkdir -p build/linux build/windows build/site/spill
$ godot --headless --export-release Linux build/linux/varde.x86_64
$ godot --headless --export-release Windows build/windows/varde.exe
$ godot --headless --export-release Web build/site/spill/index.html
$ cp -r site/index.html site/vercel.json site/fonts game/backdrop.png build/site/
$ python3 site/serve.py
```

A local copy of the page shows `__VERSION__` where the site shows the tag. `site/serve.py` serves `build/site/` at http://localhost:8000 with the two headers the game needs. After changing only `site/index.html`, copy it again and reload. The exports don't need to run again.

The desktop builds carry the game data inside the executable, so each one is a single file of about 75 MB (Linux) or 110 MB (Windows). They use Forward+, and the web build uses Compatibility. SPEC.md describes how the two renderers are kept alike.

## One-time setup

These steps are done once. Steps 1 to 4 were done on 2026-11-26.

1. `vercel project create varde --scope stommeras-projects` creates the project. It isn't connected to the Git repository, since the workflow deploys it.
2. `vercel link --project varde --scope stommeras-projects` in an empty folder writes the org and project ids to `.vercel/project.json`. The CLI isn't allowed to create tokens, so create the token in the browser at Account Settings → Tokens, with the scope stommeras' projects.
3. `gh secret set` stores the three repository secrets: `VERCEL_TOKEN`, `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`.
4. `vercel domains add varde.tommeras.no varde --scope stommeras-projects` adds the domain, and `vercel domains verify varde.tommeras.no --scope stommeras-projects` prints the record it needs. DNS for tommeras.no is at Domeneshop (ns1.hyp.net), so add the `CNAME` there by hand. Vercel recommends `16cb7a88c0b11380.vercel-dns-017.com` for this project.
5. In the lab repo, delete `public/varde/` and the `/varde` header rule in `vercel.json`, so lab.tommeras.no stops serving an old build. This is [lab.tommeras.no#32](https://github.com/stommeras/lab.tommeras.no/pull/32), not merged yet.

## Unsigned builds

The builds aren't signed. Windows SmartScreen warns on the first launch, and the player has to choose "More info" and "Run anyway". The landing page says so. Signing needs a code signing certificate. macOS isn't built, because an unsigned app there is blocked unless the player knows the workaround, and notarizing needs a paid Apple developer account.
