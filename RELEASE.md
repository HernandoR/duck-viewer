# Releasing

Releases are automated via GitHub Actions and driven by the **tag**, not by a
committed version: `package.json` is generated from `package.json.template` at
build time and the version is taken from the tag (`v0.1.8` → `0.1.8`). A tag can
therefore never publish a version other than the one in its name.

## Steps

1. **Update the changelog** — add a `## [0.1.8] - YYYY-MM-DD` section to
   `CHANGELOG.md`.

2. **Commit and push to `main`**:

   ```bash
   git add CHANGELOG.md
   git commit -m "docs: changelog for 0.1.8"
   git push origin main
   ```

3. **Create the tag** — either:

   - **GitHub UI** (no terminal needed): repository → **Releases** →
     **Draft a new release** → type the tag `v0.1.8` and choose `main` as the
     target → **Publish release**. Creating the tag from **Tags** →
     **New tag** works too. The pipeline listens for `release` and `create`
     events as well as `push`, so a tag made in the UI publishes.
   - **CLI**:

     ```bash
     git tag v0.1.8
     git push origin v0.1.8
     ```

4. **Watch CI** — <https://github.com/HernandoR/duck-viewer/actions>. The
   publish usually finishes 2–5 minutes after the build.

## What happens

Any `v*` tag triggers the [CI/CD workflow](.github/workflows/ci.yml), which is
only glue around the [`justfile`](justfile):

1. **Build** — lint, compile, unit tests, and VS Code integration tests on
   macOS, Ubuntu, and Windows.
2. **Package** — one `.vsix` per target (`darwin-arm64`, `darwin-x64`,
   `linux-x64`, `win32-x64`) via `just package "$VERSION" "$TARGET"`.
3. **Publish** — `just publish "$VERSION"` uploads to both the
   [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=hernandor.duck-viewer)
   and [Open VSX](https://open-vsx.org/extension/hernandor/duck-viewer), then
   creates the GitHub Release and attaches the `.vsix` files.

Publishing is idempotent (`--skip-duplicate`), so a re-run, a manual
`Run workflow`, or two overlapping events for the same tag are harmless. A
failed marketplace upload does not stop Open VSX or the GitHub Release; the job
still fails at the end so the failure is visible.

## Publishing from your machine

`just publish v0.1.8` runs the same steps locally:

- generates `package.json` at version `0.1.8`,
- packages the **host** target if no `.vsix` is in the working directory (CI
  packages all four targets, locally you only get your own machine's),
- publishes to both marketplaces and updates the GitHub Release.

It needs `VSCE_PAT` and `OVSX_PAT` in the environment and an authenticated `gh`.
The GitHub Release is skipped if the tag is not on `origin` yet.

To retry a failed release without re-tagging, use **Actions → CI/CD → Run
workflow** and enter the version (`v0.1.8`).

## Local development

`package.json` is generated and not committed, so from a fresh checkout:

```bash
just setup          # generate package.json, then npm ci
just check          # lint, compile, unit tests
just package        # .vsix for this machine, at the development version
just generate       # regenerate package.json after editing package.json.template
```

Edit `package.json.template` — not `package.json` — when changing dependencies,
scripts, or extension metadata.

## Secrets

The publish steps require these repository secrets:

- `VSCE_PAT` — VS Code Marketplace Personal Access Token
- `OVSX_PAT` — Open VSX Registry Personal Access Token

See [docs/RELEASE.md](docs/RELEASE.md) for the detailed process, how to refresh
`VSCE_PAT`, and troubleshooting.
