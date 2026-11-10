#!/usr/bin/env bash
# Cursor cone-sparse marketplace checkout must remain a complete installer source.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ORIGIN_WORK="$TMP/origin-work"
ORIGIN_BARE="$TMP/origin.git"
CACHE="$TMP/cache"
FAKE_HOME="$TMP/home"
PROJECT="$TMP/project"
BASELINE="$TMP/baseline"
REQUIRED_PATHS="$TMP/required-paths"
IGNORED_PATHS="$TMP/ignored-paths"
FIXTURE_PATHS="$TMP/fixture-paths"
mkdir -p "$ORIGIN_WORK" "$FAKE_HOME" "$PROJECT" "$BASELINE"

# Scoped to git-TRACKED material only: a cone-sparse checkout ships exactly
# `git ls-files`, never whatever a prior `bun install` happened to leave on
# this dev machine's disk (node_modules/, .harness/, .impeccable/, .DS_Store
# are all gitignored on purpose -- `bun install` regenerates node_modules,
# see ensure-harness-deps.ts). A raw `find` over the working tree would flag
# that untracked, intentionally-ignored runtime cruft as a false failure.
if git -C "$ROOT" ls-files -s .cursor-plugin/plugins .cursor-plugin/scripts | grep -q '^120000'; then
  printf 'FAIL nested marketplace material contains a tracked symlink\n' >&2
  exit 1
fi
git -C "$ROOT" ls-files .cursor-plugin/plugins .cursor-plugin/scripts | sort > "$REQUIRED_PATHS"
if git -C "$ROOT" check-ignore --no-index --stdin < "$REQUIRED_PATHS" > "$IGNORED_PATHS"; then
  printf 'FAIL nested marketplace material is ignored:\n' >&2
  cat "$IGNORED_PATHS" >&2
  exit 1
elif [ "$?" -ne 1 ]; then
  printf 'FAIL git check-ignore could not validate nested marketplace material\n' >&2
  exit 1
fi

git -C "$ROOT" archive HEAD | tar -x -C "$BASELINE"
node - "$ROOT" "$BASELINE" <<'NODE'
const fs = require('fs');
const path = require('path');
const [root, baselineRoot] = process.argv.slice(2);
const baseline = JSON.parse(fs.readFileSync(path.join(baselineRoot, '.cursor-plugin/marketplace.json')));
const current = JSON.parse(fs.readFileSync(path.join(root, '.cursor-plugin/marketplace.json')));
if (baseline.plugins.length !== 26 || current.plugins.length !== 26) throw new Error('expected 26 marketplace plugins');

function requireRegular(file) {
  const stat = fs.lstatSync(file);
  if (stat.isSymbolicLink() || !stat.isFile()) throw new Error(`expected real file: ${file}`);
}

function filesBelow(directory, relative = '') {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const childRelative = path.join(relative, entry.name);
    const child = path.join(directory, entry.name);
    if (entry.isDirectory()) return filesBelow(child, childRelative);
    if (!entry.isFile()) throw new Error(`expected tracked regular file: ${child}`);
    return [childRelative];
  });
}

for (const entry of current.plugins) {
  const prior = baseline.plugins.find((candidate) => candidate.name === entry.name);
  if (!prior) throw new Error(`HEAD marketplace missing ${entry.name}`);
  const priorRoot = path.join(baselineRoot, prior.source);
  const priorFiles = filesBelow(priorRoot);
  if (priorFiles.length === 0) throw new Error(`HEAD has no tracked files for ${entry.name}`);
  for (const relative of priorFiles) {
    const priorFile = path.join(priorRoot, relative);
    const nestedFile = path.join(root, entry.source, relative);
    requireRegular(nestedFile);
    if (!fs.readFileSync(priorFile).equals(fs.readFileSync(nestedFile))) {
      throw new Error(`moved plugin content differs from HEAD: ${prior.source}/${relative}`);
    }
  }
  requireRegular(path.join(root, entry.source, '.cursor-plugin/plugin.json'));
}

const priorRuntimeRoot = fs.existsSync(path.join(baselineRoot, 'scripts'))
  ? path.join(baselineRoot, 'scripts')
  : path.join(baselineRoot, '.cursor-plugin/scripts');
const priorRuntime = filesBelow(priorRuntimeRoot);
if (priorRuntime.length === 0) throw new Error('HEAD has no tracked installer runtime');
for (const relative of priorRuntime) {
  const nestedFile = path.join(root, '.cursor-plugin/scripts', relative);
  requireRegular(nestedFile);
}
requireRegular(path.join(root, '.cursor-plugin/scripts/install-hooks.ts'));
NODE

cp -R "$ROOT/.cursor-plugin" "$ORIGIN_WORK/.cursor-plugin"
cp "$ROOT/AGENTS.md" "$ROOT/install.sh" "$ROOT/install.ps1" \
  "$ROOT/verify-project.sh" "$ORIGIN_WORK/"
if test -f "$ROOT/.gitignore"; then cp "$ROOT/.gitignore" "$ORIGIN_WORK/.gitignore"; fi

git -C "$ORIGIN_WORK" init -q
git -C "$ORIGIN_WORK" config user.name "Sparse Installer Test"
git -C "$ORIGIN_WORK" config user.email "sparse-installer@example.invalid"
git -C "$ORIGIN_WORK" add .
git -C "$ORIGIN_WORK" ls-files .cursor-plugin/plugins .cursor-plugin/scripts | sort > "$FIXTURE_PATHS"
if ! cmp -s "$REQUIRED_PATHS" "$FIXTURE_PATHS"; then
  printf 'FAIL fixture omits eligible nested marketplace material\n' >&2
  exit 1
fi
git -C "$ORIGIN_WORK" commit -qm "test fixture"
git clone -q --bare "$ORIGIN_WORK" "$ORIGIN_BARE"
git clone -q --no-checkout "file://$ORIGIN_BARE" "$CACHE"
git -C "$CACHE" sparse-checkout init --cone
git -C "$CACHE" sparse-checkout set .cursor-plugin
git -C "$CACHE" checkout -q --detach HEAD

test ! -e "$CACHE/scripts"
if ! test -f "$CACHE/.cursor-plugin/scripts/install-hooks.ts"; then
  printf 'FAIL sparse checkout omits .cursor-plugin/scripts/install-hooks.ts\n' >&2
  exit 1
fi

node - "$CACHE" <<'NODE'
const fs = require('fs');
const path = require('path');
const root = process.argv[2];
const market = JSON.parse(fs.readFileSync(path.join(root, '.cursor-plugin/marketplace.json'), 'utf8'));
if (market.plugins.length !== 26) throw new Error('expected 26 marketplace plugins');
for (const entry of market.plugins) {
  const manifest = path.join(root, entry.source, '.cursor-plugin', 'plugin.json');
  if (!fs.existsSync(manifest)) throw new Error(`sparse checkout missing ${entry.name}: ${manifest}`);
}
NODE

CACHE_STATUS="$(git -C "$CACHE" status --porcelain=v1)"
HOME="$FAKE_HOME" "$CACHE/install.sh" --dry-run >/dev/null
test ! -e "$FAKE_HOME/.cursor"
HOME="$FAKE_HOME" "$CACHE/install.sh" >/dev/null

HOME="$FAKE_HOME" "$CACHE/install.sh" --project "$PROJECT" --dry-run >/dev/null
test ! -e "$PROJECT/.cursor"
HOME="$FAKE_HOME" "$CACHE/install.sh" --project "$PROJECT" >/dev/null
"$CACHE/verify-project.sh" "$PROJECT" >/dev/null

node - "$CACHE/.cursor-plugin/marketplace.json" "$FAKE_HOME/.cursor/plugins/local" "$PROJECT" <<'NODE'
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const [marketFile, globalRoot, project] = process.argv.slice(2);
const market = JSON.parse(fs.readFileSync(marketFile, 'utf8'));
for (const entry of market.plugins) {
  const globalPlugin = path.join(globalRoot, entry.name);
  if (!fs.existsSync(path.join(globalPlugin, '.cursor-plugin/plugin.json'))) {
    throw new Error(`global install missing flat plugin ${entry.name}`);
  }
}
const managedPlugins = path.join(fs.realpathSync(project), '.cursor/fusengine/plugins');
const loaded = JSON.parse(execFileSync(process.execPath, ['.cursor/fusengine/load-plugins.mjs'], {
  cwd: project,
  encoding: 'utf8',
}));
if (loaded.pluginPaths.length !== 26) throw new Error('project loader did not return 26 plugins');
for (const [index, pluginPath] of loaded.pluginPaths.entries()) {
  const expected = path.join(managedPlugins, market.plugins[index].name);
  if (pluginPath !== expected) throw new Error(`project plugin is not flat: ${pluginPath}`);
}
NODE

test "$CACHE_STATUS" = "$(git -C "$CACHE" status --porcelain=v1)"
test ! -e "$CACHE/scripts"
printf 'PASS cone-sparse marketplace installs 26 flat plugins globally and per project\n'
