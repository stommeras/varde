# Releasing

A release is a version tag on `main`. Pushing the tag starts `.github/workflows/release.yml`, which:

1. runs the tests,
2. exports the `Linux`, `Windows` and `Web` presets in `export_presets.cfg` with the release templates,
3. publishes a GitHub Release with `varde-linux.zip` and `varde-windows.zip` and notes generated from the merged PRs,
4. deploys the site to [varde.tommeras.no](https://varde.tommeras.no) on Vercel.

If the tests fail, nothing is published. A release build leaves out debug-only code such as god mode.

## Versions

Versions are `v0.<milestone>.<patch>`. The release that closes milestone 4 is `v0.4.0`, and a fix to it is `v0.4.1`. Milestone 6 done is `v1.0.0`. AGENTS.md says when a release is due.

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

`site/` holds the landing page and its `vercel.json`. The workflow puts together `build/site/` like this:

```
index.html     site/index.html, in bokmål
vercel.json    the headers
backdrop.png   game/backdrop.png, the title screen's backdrop
spill/         the web export
```

The download buttons point at `releases/latest/download/varde-linux.zip` and `varde-windows.zip`, so they always fetch the newest release without changing the page. The page takes its colors from the `MAP` ramps in `world/ramps.gd`. When the ramps change, change the page to match.

The web build uses threads, so every page sends `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. Without them the browser gives the page no `SharedArrayBuffer` and the game doesn't start. GitHub Pages can't send these headers, which is why the site is on Vercel.

## Build it locally

You need Godot 4.7.2 and its export templates (Editor → Manage Export Templates).

```console
$ mkdir -p build/linux build/windows build/site/spill
$ godot --headless --export-release Linux build/linux/varde.x86_64
$ godot --headless --export-release Windows build/windows/varde.exe
$ godot --headless --export-release Web build/site/spill/index.html
$ cp site/index.html site/vercel.json game/backdrop.png build/site/
```

The desktop builds carry the game data inside the executable, so each one is a single file of about 75 MB (Linux) or 110 MB (Windows). They use Forward+, and the web build uses Compatibility. SPEC.md describes how the two renderers are kept alike.

## One-time setup

These steps are done once, by hand.

1. In Vercel, create a project named `varde` with the framework preset Other and no build command. Don't connect it to the Git repository, since the workflow deploys it.
2. Create a Vercel token (Account Settings → Tokens). Run `vercel link` in an empty folder to get the org and project ids from `.vercel/project.json`.
3. Add three repository secrets on GitHub: `VERCEL_TOKEN`, `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`.
4. In the Vercel project, add the domain `varde.tommeras.no`. At the DNS host for tommeras.no, add a `CNAME` record from `varde` to `cname.vercel-dns.com`.
5. In the lab repo, remove `public/varde/` and the `/varde` header rule in `vercel.json`, and point the Varde experiment at varde.tommeras.no.

## Unsigned builds

The builds aren't signed. Windows SmartScreen warns on the first launch, and the player has to choose "More info" and "Run anyway". The landing page says so. Signing needs a code signing certificate. macOS isn't built, because an unsigned app there is blocked unless the player knows the workaround, and notarizing needs a paid Apple developer account.
