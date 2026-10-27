# Release Process

This document describes how to release a new version of the Duck Viewer
extension, in detail. [RELEASE.md](../RELEASE.md) at the repository root is the
short version.

## How versions work

The version is **never committed**. `package.json` is generated from
[`package.json.template`](../package.json.template) by
[`scripts/generate-package.mjs`](../scripts/generate-package.mjs), and the
version comes from, in order:

1. the version passed to a recipe (`just publish v0.1.8`),
2. the tag pointing at `HEAD`,
3. the template's development version (`0.0.0`).

`just` never writes a version anywhere else, and `package.json` is gitignored.
The generated `package.json` is exactly the file that `vsce` packs into the
`.vsix`, so the published extension carries the tag's version.

This replaced the old "bump `package.json`, commit, then tag" flow, which
pointed v0.1.6 at a `package.json` that still said 0.1.5.

## Prerequisites

- Push access to the GitHub repository (or permission to create releases/tags).
- [just](https://github.com/casey/just) installed locally, for the optional
  local publish (`brew install just`, `mise use -g just`, …).
- Repository secrets configured (see [Secrets](#secrets)):

  - `VSCE_PAT` — VS Code Marketplace token
  - `OVSX_PAT` — Open VSX token

## Release Steps

### 1. Update the Changelog

Add a new section to [`CHANGELOG.md`](../CHANGELOG.md) using the version you are
about to release:

```markdown
## [0.1.8] - 2026-10-27

### Added
- New feature X

### Changed
- Improved Y

### Fixed
- Bug Z
```

Follow [semantic versioning](https://semver.org/):

- **MAJOR** (1.0.0): breaking changes
- **MINOR** (0.1.0): new features, backward compatible
- **PATCH** (0.0.1): bug fixes, backward compatible

### 2. Commit and Push

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for 0.1.8"
git push origin main
```

### 3. Create the Tag

Pick whichever is convenient — the pipeline treats them the same:

- **GitHub UI, no terminal:** repository → **Releases** → **Draft a new
  release** → enter `v0.1.8` as a new tag on `main` → **Publish release**. A tag
  created from **Tags** → **New tag** works as well.
- **CLI:**

  ```bash
  git tag -a v0.1.8 -m "v0.1.8"
  git push origin v0.1.8
  ```

The tag must be `v` + a valid semver version. That is the only place the
version comes from.

### 4. Monitor the Release

- **GitHub Actions**: <https://github.com/HernandoR/duck-viewer/actions>
- **Marketplace**: <https://marketplace.visualstudio.com/items?itemName=hernandor.duck-viewer>
- **Open VSX**: <https://open-vsx.org/extension/hernandor/duck-viewer>

The publish typically finishes 2–5 minutes after the build completes.

## What the Pipeline Does

The workflow ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) only
calls recipes from the [`justfile`](../justfile):

1. **Build** — `just generate "$VERSION"`, `npm ci`, then `just check` (lint,
   compile, unit tests) and `just integration-test` on macOS, Ubuntu, and
   Windows.
2. **Package** — `just package "$VERSION" "$TARGET"` once per target
   (`darwin-arm64`, `darwin-x64`, `linux-x64`, `win32-x64`); each `.vsix` is
   uploaded as an artifact.
3. **Publish** — the artifacts are downloaded and `just publish "$VERSION"`:

   - `vsce publish --skip-duplicate` → VS Code Marketplace
   - `ovsx publish --skip-duplicate` → Open VSX
   - `gh release create` / `gh release upload` → GitHub Release with the four
     `.vsix` files

Publishing is idempotent, so re-running a release is safe: a version that is
already on a marketplace is skipped. The three publishers are attempted even if
one fails, and the workflow fails at the end if any of them did.

### Tags created from the UI

The workflow listens for `push` (tags pushed with git), `create` and `release`
(published), because a tag created through the GitHub UI does not always emit a
`push` event. It also has a `workflow_dispatch` input, for retrying a release
without deleting and re-creating the tag: **Actions → CI/CD → Run workflow**,
version `v0.1.8`.

## Publishing From Your Machine

`just publish v0.1.8` runs the same steps locally:

```bash
just setup                          # once, from a fresh checkout
export VSCE_PAT=... OVSX_PAT=...    # or keep them in your shell profile
gh auth status                      # for the GitHub Release
just publish v0.1.8
```

It generates `package.json` at that version, packages the host target if no
`.vsix` is present, publishes to both marketplaces, and updates the GitHub
Release. CI still publishes all four targets; a local run only produces the
target of the machine it runs on. The GitHub Release step is skipped when the
tag is not on `origin` yet.

## Secrets

The publish steps require these repository secrets:

- `VSCE_PAT` — VS Code Marketplace Personal Access Token
- `OVSX_PAT` — Open VSX Registry Personal Access Token

## Refreshing the VSCE_PAT

The Personal Access Token (PAT) expires periodically. If publishing fails with an authentication error, follow these steps:

### 1. Create a New Token

1. Go to https://dev.azure.com
2. Click your profile icon (top right) → **Personal access tokens**
3. Click **+ New Token**
4. Configure:
   - **Name**: `vsce-publish` (or any name)
   - **Organization**: Select **All accessible organizations**
   - **Expiration**: Up to 1 year (choose based on preference)
   - **Scopes**: Click **Custom defined**, then:
     - Find **Marketplace** → check **Manage**
5. Click **Create**
6. **Copy the token immediately** (you won't see it again)

### 2. Update the GitHub Secret

1. Go to https://github.com/HernandoR/duck-viewer/settings/secrets/actions
2. Click on `VSCE_PAT`
3. Click **Update**
4. Paste the new token
5. Click **Update secret**

### 3. Re-run the Failed Workflow (if needed)

1. Go to the failed workflow run in GitHub Actions
2. Click **Re-run all jobs** — publishing is idempotent, so already-published
   targets are skipped.

## Quick Release Checklist

- [ ] `CHANGELOG.md` updated
- [ ] Changes committed and pushed to `main`
- [ ] Tag created matching the changelog version (e.g. `v0.1.8`), from the UI or CLI
- [ ] CI/CD pipeline passed
- [ ] Extension version visible on the marketplace and on Open VSX
- [ ] GitHub Release has the four `.vsix` files

## Troubleshooting

### `npm ci` fails with a missing `package.json`

The file is generated. Run `just generate` (or `just setup`) first.

### `refusing to publish the development version 0.0.0`

The version was not passed and no tag points at `HEAD`. Pass it explicitly
(`just publish v0.1.8`) or run from a tag checkout.

### `"v0.1" is not a valid version`

The version must be full semver, e.g. `v0.1.8` or `v1.0.0-beta.1`.

### Publishing Fails with 401/403

The `VSCE_PAT` has likely expired. See
[Refreshing the VSCE_PAT](#refreshing-the-vsce_pat).

### Publishing "did nothing" / "version already exists"

The version in the tag is already published, and `--skip-duplicate` turned the
publish into a no-op. Delete and re-push the tag does **not** help: marketplaces
refuse to overwrite a published version. Release a new version instead (e.g.
`v0.1.9`).

### A tag created in the UI did not start the workflow

Check that the tag starts with `v` and is valid semver, then use **Actions →
CI/CD → Run workflow** with that version. The `create` and `release` events are
both subscribed, so a published release and a tag created from the Tags page are
covered.

### "engines.vscode mismatch" Error

Ensure `engines.vscode` in `package.json.template` matches or exceeds the
`@types/vscode` version in `devDependencies`.
