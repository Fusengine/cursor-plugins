#!/bin/sh
# Fusengine hook entrypoint — shipped inside every plugin as scripts/hook.sh.
#
# Resolves the shared harness itself so the plugin works from the Cursor
# marketplace, where no installer ever runs. Order:
#   1. the vendored install under $HOME/.cursor/.fusengine-global (fast path)
#   2. a self-heal `bun install` of that same shared directory, once
#   3. `npx` on latest (last resort, network)
#
# Installs the LATEST published harness the first time (the manifest uses the
# `latest` dist-tag, and so does the npx fallback), so no wrapper needs editing
# per release. It does NOT upgrade an existing install: the fast path runs the
# vendored bin as is, and rewriting it in place while up to 62 hooks load it
# could crash a guard mid-run (hooks fail open). The upgrade path is the
# installer (`install.sh` runs `bun update @fusengine/harness` on every run) or,
# by hand: `cd ~/.cursor/.fusengine-global && bun update @fusengine/harness`.
#
# Resolution is relative to THIS file, never to the caller's cwd. Always exits 0
# on its own failures: Cursor fails hooks open, and a broken guard must never
# block the user's action.
#
# Usage (from hooks/hooks.json): ./scripts/hook.sh [scope...]

HARNESS_SPEC="latest"
CONTROL_ROOT="${HOME}/.cursor/.fusengine-global"
BIN="${CONTROL_ROOT}/node_modules/@fusengine/harness/dist/cli/bin.mjs"
STAMP="${CONTROL_ROOT}/.selfheal-attempted"

run_bin() {
  if command -v bun >/dev/null 2>&1; then exec bun "$BIN" hook cursor "$@"; fi
  exec node "$BIN" hook cursor "$@"
}

# 1. Fast path: already vendored.
[ -f "$BIN" ] && run_bin "$@"

# 2. Self-heal once. The stamp keeps 62 hooks from stampeding the registry when
#    the install is genuinely impossible (offline, no bun, no network).
if [ ! -e "$STAMP" ] && command -v bun >/dev/null 2>&1; then
  mkdir -p "$CONTROL_ROOT" 2>/dev/null && : > "$STAMP" 2>/dev/null
  printf '{"name":"@fusengine/cursor-harness","private":true,"dependencies":{"@fusengine/harness":"%s"}}\n' \
    "$HARNESS_SPEC" > "${CONTROL_ROOT}/package.json" 2>/dev/null
  (cd "$CONTROL_ROOT" && bun install --silent) >/dev/null 2>&1
  [ -f "$BIN" ] && run_bin "$@"
fi

# 3. Last resort: npx on the latest published release.
command -v npx >/dev/null 2>&1 || exit 0
exec npx -y "@fusengine/harness@${HARNESS_SPEC}" hook cursor "$@"
