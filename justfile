# Build, package, and publish the Duck Viewer VS Code extension.
#
# `package.json` is generated, never committed: `package.json.template` holds
# everything except the version, and the version comes from the release tag.
# That is why a tag created anywhere (git, the GitHub UI, a release) always
# publishes exactly the version in its name.
#
#   just setup                 # generate package.json + install dependencies
#   just check                 # lint, compile, unit tests
#   just package               # VSIX for this machine (development version)
#   just package v0.1.8        # VSIX for this machine, version 0.1.8
#   just package v0.1.8 linux-x64
#   just publish v0.1.8        # publish VSIXs + GitHub Release (this machine)
#
# CI runs the same recipes; it does not contain any release logic of its own.

set shell := ["bash", "-euo", "pipefail", "-c"]

# `vsce --target` name of the machine running just (e.g. darwin-arm64).
host_target := `node -p "process.platform + '-' + process.arch"`

# `ref` is a version (v0.1.8 or 0.1.8), a tag, or a ref such as a branch name;
# anything that is not a version falls back to the tag on HEAD, then to the
# template's development version (0.0.0).
# Generate package.json from package.json.template.
generate ref="":
    node scripts/generate-package.mjs "{{ref}}"

# Install dependencies (requires `just generate` to have run).
deps:
    npm ci

# Generate package.json and install dependencies from a fresh checkout.
setup:
    just generate
    npm ci

# Lint, compile, and run the unit tests.
check:
    npm run lint
    npm run compile
    npm run test:unit

# Needs a display; on headless Linux run `xvfb-run -a just integration-test`.
# Run the VS Code integration tests.
integration-test:
    npm test

# Build the extension and webview bundles for production.
build:
    npm run package

# Without a target, packages the machine running just.
# Package a VSIX at `ref`'s version for `target` (default: this machine).
package ref="" target=host_target:
    node scripts/generate-package.mjs "{{ref}}"
    @test -d node_modules || npm ci
    npx @vscode/vsce package --target "{{target}}"

# Publishes every .vsix in the working directory, packaging this machine's
# target first when there is none, so it also works from a clean checkout.
# Needs VSCE_PAT and OVSX_PAT; the GitHub Release step needs an authenticated
# `gh`. An already-published version is skipped, so re-runs and overlapping CI
# runs are harmless.
# Publish the VSIXs to both marketplaces and a GitHub Release.
publish ref:
    #!/usr/bin/env bash
    set -euo pipefail

    version="$(node scripts/generate-package.mjs "{{ref}}")"

    if [ "$version" = "0.0.0" ]; then
      echo "::error::refusing to publish the development version 0.0.0" >&2
      echo "Pass the release version, e.g. \`just publish v0.1.8\`." >&2
      exit 1
    fi

    if [ ! -d node_modules ]; then
      npm ci
    fi

    if ! ls ./*.vsix >/dev/null 2>&1; then
      echo "No VSIX in the working directory; packaging the host target."
      just package "$version"
    fi

    # Never publish a stale package that was built for another version.
    for vsix in ./*.vsix; do
      case "$vsix" in
        *"$version"*) ;;
        *)
          echo "::error::$vsix does not look like a $version package" >&2
          exit 1
          ;;
      esac
    done

    status=0

    echo "==> VS Code Marketplace"
    if ! npx @vscode/vsce publish --packagePath ./*.vsix --skip-duplicate; then
      echo "::error::VS Code Marketplace publish failed" >&2
      status=1
    fi

    echo "==> Open VSX"
    if ! npx --yes ovsx publish --packagePath ./*.vsix --skip-duplicate -p "${OVSX_PAT:?OVSX_PAT is not set}"; then
      echo "::error::Open VSX publish failed" >&2
      status=1
    fi

    echo "==> GitHub Release"
    tag="v$version"
    # Locally, only touch the release when the tag actually exists. In CI the
    # workflow knows a tag (or an explicit version) was requested, so attempt
    # it and fail loudly if it cannot be created.
    if [ -n "${GITHUB_ACTIONS:-}" ] ||
      git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null 2>&1 ||
      git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
      gh release view "$tag" >/dev/null 2>&1 ||
        gh release create "$tag" --verify-tag --generate-notes --title "$tag"
      gh release upload "$tag" ./*.vsix --clobber
    else
      echo "note: tag $tag is not on origin yet; skipping the GitHub Release."
      echo "      Push the tag and let CI create the release."
    fi

    exit "$status"
