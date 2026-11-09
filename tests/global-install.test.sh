#!/usr/bin/env bash
# Integration contract for the default user-global Cursor installation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HOME_DIR="$TMP/home"
PROJECT="$TMP/project"
SOURCE="$TMP/source"
mkdir -p "$HOME_DIR" "$PROJECT" "$SOURCE/.cursor-plugin"
cp "$ROOT/.cursor-plugin/marketplace.json" "$SOURCE/.cursor-plugin/marketplace.json"
for plugin in $(node -e 'for(const p of require(process.argv[1]).plugins)console.log(p.source)' "$ROOT/.cursor-plugin/marketplace.json"); do
  mkdir -p "$(dirname "$SOURCE/$plugin")"
  cp -R "$ROOT/$plugin" "$SOURCE/$plugin"
done

global_install() {
  HOME="$HOME_DIR" NODE_ENV=test FUSE_INSTALL_TEST_SOURCE_ROOT="$SOURCE" "$ROOT/install.sh" "$@"
}

# Bun keeps two caches under $HOME: transpiled sources (Library/Caches/bun on
# macOS, .cache/bun on Linux) and auto-installed packages ($HOME/.bun/install/
# cache, populated on a checkout with no node_modules). Both are the runtime's
# own bookkeeping, not installer state. Redirecting them out of the sandbox
# keeps the snapshot below an unscoped assertion over the whole fake HOME
# rather than a narrower one over ~/.cursor alone.
export BUN_RUNTIME_TRANSPILER_CACHE_PATH=0
export BUN_INSTALL_CACHE_DIR="$TMP/bun-install-cache"
snapshot_home() { find "$HOME_DIR" -print | sort; }
BEFORE_DRY="$(snapshot_home)"
(cd "$PROJECT" && global_install --dry-run)
test "$BEFORE_DRY" = "$(snapshot_home)"
test ! -e "$HOME_DIR/.cursor"
test ! -e "$PROJECT/.cursor"

(cd "$PROJECT" && global_install)
(cd "$PROJECT" && global_install)
test ! -e "$PROJECT/.cursor"
test -f "$HOME_DIR/.cursor/.fusengine-global/receipt.json"
test -f "$HOME_DIR/.cursor/rules/fuse-global.mdc"

node - "$SOURCE/.cursor-plugin/marketplace.json" "$HOME_DIR/.cursor/plugins/local" <<'NODE'
const fs = require('fs');
const path = require('path');
const [marketFile, localRoot] = process.argv.slice(2);
const market = JSON.parse(fs.readFileSync(marketFile, 'utf8'));
if (market.plugins.length !== 25) throw Error('expected 25 source plugins');
for (const entry of market.plugins) {
  const root = path.join(localRoot, entry.name);
  if (!fs.statSync(root).isDirectory()) throw Error(`missing immediate plugin: ${entry.name}`);
  if (!fs.statSync(path.join(root, '.cursor-plugin/plugin.json')).isFile()) throw Error(`invalid plugin root: ${entry.name}`);
}
NODE

mkdir -p "$HOME_DIR/.cursor/plugins/local/foreign-plugin"
printf 'foreign\n' > "$HOME_DIR/.cursor/plugins/local/foreign-plugin/keep.txt"
printf '\nGLOBAL_SOURCE_REFRESH\n' >> "$SOURCE/.cursor-plugin/plugins/core-guards/README.md"
printf '\nGLOBAL_RULE_REFRESH\n' >> "$SOURCE/.cursor-plugin/plugins/fuse-rules/user-rules/fuse-global.mdc"
global_install
grep -q GLOBAL_SOURCE_REFRESH "$HOME_DIR/.cursor/plugins/local/core-guards/README.md"
grep -q GLOBAL_RULE_REFRESH "$HOME_DIR/.cursor/rules/fuse-global.mdc"
test -f "$HOME_DIR/.cursor/plugins/local/foreign-plugin/keep.txt"

RECEIPT_BEFORE="$(shasum -a 256 "$HOME_DIR/.cursor/.fusengine-global/receipt.json")"
if FUSE_GLOBAL_TEST_FAIL_POINT=after-old-move global_install 2>"$TMP/transaction.error"; then
  printf 'expected injected global transaction failure\n' >&2
  exit 1
fi
grep -q 'injected global transaction failure at after-old-move' "$TMP/transaction.error"
test "$RECEIPT_BEFORE" = "$(shasum -a 256 "$HOME_DIR/.cursor/.fusengine-global/receipt.json")"
test -f "$HOME_DIR/.cursor/plugins/local/core-guards/.cursor-plugin/plugin.json"

for point in after-old-rename-before-journal after-new-rename-before-journal; do
  if FUSE_GLOBAL_TEST_FAIL_POINT="$point" global_install 2>"$TMP/$point.error"; then
    printf 'expected injected global crash-window failure: %s\n' "$point" >&2
    exit 1
  fi
  grep -q "injected global transaction failure at $point" "$TMP/$point.error"
  test -f "$HOME_DIR/.cursor/plugins/local/foreign-plugin/keep.txt"
  test "$RECEIPT_BEFORE" = "$(shasum -a 256 "$HOME_DIR/.cursor/.fusengine-global/receipt.json")"
done

printf '\nUSER_PLUGIN_EDIT\n' >> "$HOME_DIR/.cursor/plugins/local/core-guards/README.md"
printf '\nUSER_RULE_EDIT\n' >> "$HOME_DIR/.cursor/rules/fuse-global.mdc"
if global_install 2>"$TMP/modified.error"; then
  printf 'expected modified global artifact refusal\n' >&2
  exit 1
fi
grep -q 'refusing to overwrite modified owned' "$TMP/modified.error"
# Guard the guard: the removal assertion below is only meaningful if the
# configuration stage actually deployed the loader tree here first. Without
# this, `test ! -e .fusengine-global` could pass on a directory that was never
# populated.
test -d "$HOME_DIR/.cursor/.fusengine-global/scripts"
global_install --uninstall
grep -q USER_PLUGIN_EDIT "$HOME_DIR/.cursor/plugins/local/core-guards/README.md"
grep -q USER_RULE_EDIT "$HOME_DIR/.cursor/rules/fuse-global.mdc"
test -f "$HOME_DIR/.cursor/plugins/local/foreign-plugin/keep.txt"
test ! -e "$HOME_DIR/.cursor/plugins/local/fuse-ai-pilot"
# The control root belongs to the installer in full, so uninstall takes all of
# it: the receipt, the ownership marker, and the vendored hook runtime the
# configuration stage writes under scripts/. Asserting on the whole directory
# rather than on receipt.json alone is deliberate -- the narrower assertion used
# to pass while ~50 loader files stayed behind for good.
test ! -e "$HOME_DIR/.cursor/.fusengine-global"

COLLISION_HOME="$TMP/collision-home"
mkdir -p "$COLLISION_HOME/.cursor/plugins/local/core-guards"
printf 'foreign collision\n' > "$COLLISION_HOME/.cursor/plugins/local/core-guards/keep.txt"
if HOME="$COLLISION_HOME" NODE_ENV=test FUSE_INSTALL_TEST_SOURCE_ROOT="$SOURCE" "$ROOT/install.sh" 2>"$TMP/collision.error"; then
  printf 'expected foreign plugin collision refusal\n' >&2
  exit 1
fi
test -f "$COLLISION_HOME/.cursor/plugins/local/core-guards/keep.txt"
test ! -e "$COLLISION_HOME/.cursor/plugins/local/fuse-ai-pilot"

SYMLINK_HOME="$TMP/symlink-home"
EXTERNAL="$TMP/external-local"
mkdir -p "$SYMLINK_HOME/.cursor/plugins" "$EXTERNAL"
ln -s "$EXTERNAL" "$SYMLINK_HOME/.cursor/plugins/local"
if HOME="$SYMLINK_HOME" NODE_ENV=test FUSE_INSTALL_TEST_SOURCE_ROOT="$SOURCE" "$ROOT/install.sh" 2>"$TMP/symlink.error"; then
  printf 'expected global symlink refusal\n' >&2
  exit 1
fi
test -z "$(find "$EXTERNAL" -mindepth 1 -print -quit)"

grep -q '.cursor-plugin/scripts/install-hooks.ts' "$ROOT/install.ps1"
grep -Fq "if (\$Project)" "$ROOT/install.ps1"
printf 'PASS default global install, refresh, rollback, refusal, and uninstall\n'
