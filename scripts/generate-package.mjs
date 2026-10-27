#!/usr/bin/env node
/**
 * Generate `package.json` from `package.json.template`.
 *
 * The version is the only field that differs between the template and the
 * generated file, and it is never committed: it is taken from, in order,
 *
 *   1. the argument / `VERSION` environment variable (`v0.1.8` or `0.1.8`),
 *   2. the tag pointing at HEAD (so `just package` in a tag checkout is right),
 *   3. the template itself (`0.0.0`, a development build).
 *
 * Print the resolved version on stdout (recipes capture it) and everything
 * else on stderr. Run from anywhere: paths are resolved from the repo root.
 */
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const TEMPLATE = join(ROOT, "package.json.template");
const OUTPUT = join(ROOT, "package.json");

const SEMVER =
  /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;

function note(message) {
  process.stderr.write(`${message}\n`);
}

/** `v0.1.8` / `refs/tags/v0.1.8` -> `0.1.8`; anything else -> undefined. */
function toVersion(value) {
  if (!value) return undefined;
  const candidate = String(value)
    .trim()
    .replace(/^refs\/tags\//, "")
    .replace(/^v/, "");
  return SEMVER.test(candidate) ? candidate : undefined;
}

function tagOnHead() {
  try {
    return execFileSync("git", ["describe", "--tags", "--exact-match", "HEAD"], {
      cwd: ROOT,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return undefined;
  }
}

function main() {
  const requested = process.argv[2] ?? process.env.VERSION ?? "";
  const template = JSON.parse(readFileSync(TEMPLATE, "utf8"));

  let version = toVersion(requested);
  let source = "argument";

  if (!version && /^v?\d/.test(requested.trim())) {
    throw new Error(
      `"${requested}" is not a valid version (expected e.g. v0.1.8 or 0.1.8)`
    );
  }

  if (!version) {
    version = toVersion(tagOnHead());
    source = "tag on HEAD";
  }

  if (!version) {
    version = toVersion(template.version);
    source = "template default";
  }

  if (!version) {
    throw new Error(
      `no version found: pass one (just generate v0.1.8), or tag HEAD, ` +
        `or set "version" in package.json.template to a semver version`
    );
  }

  template.version = version;
  writeFileSync(OUTPUT, `${JSON.stringify(template, null, 2)}\n`);

  note(`package.json: version ${version} (${source})`);
  process.stdout.write(version);
}

try {
  main();
} catch (error) {
  note(`generate-package: ${error.message}`);
  process.exit(1);
}
