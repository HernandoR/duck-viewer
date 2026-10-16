# Releasing

Releases are automated via GitHub Actions. Pushing a version tag triggers the CI/CD pipeline which builds, packages, and publishes the extension.

## Steps

1. **Bump the version** in `package.json`:

   ```json
   "version": "0.0.19"
   ```

2. **Commit the version bump**:

   ```bash
   git add package.json
   git commit -m "version bump"
   ```

3. **Tag and push**:

   ```bash
   v=v$(git show main:package.json | jq -r .version) && git tag "$v" main && git push --atomic origin main "$v"
   ```

   This reads the version from `main`'s `package.json`, so the tag always matches it.

## What happens

The `v*` tag triggers the [CI/CD workflow](.github/workflows/ci.yml):

1. **Build** — Lint, compile, and run tests on macOS, Ubuntu, and Windows
2. **Package** — Create platform-specific `.vsix` files for `darwin-arm64`, `darwin-x64`, `linux-x64`, and `win32-x64`
3. **Publish** — Upload to both [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=hernandor.duck-viewer) and [Open VSX](https://open-vsx.org/extension/hernandor/duck-viewer)
4. **GitHub Release** — Create a release for the tag and attach all `.vsix` files (runs even if a marketplace publish fails)

## Secrets

The publish steps require these repository secrets:

- `VSCE_PAT` — VS Code Marketplace Personal Access Token
- `OVSX_PAT` — Open VSX Registry Personal Access Token
