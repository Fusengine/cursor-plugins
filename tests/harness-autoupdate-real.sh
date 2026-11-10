#!/usr/bin/env bash
# OPT-IN network check of the real upgrade: 0.1.110 (exact) -> latest through
# `hook.sh --session-start`, then the guards run against the new version.
#
# Not named *.test.sh on purpose: CI globs tests/*.test.sh and must stay
# deterministic and offline. Run with:  FUSE_NETWORK_TESTS=1 bash tests/harness-autoupdate-real.sh
# Throwaway HOME and bun cache: the real ~/.cursor and ~/.bun are never touched.
set -uo pipefail

if [ "${FUSE_NETWORK_TESTS:-}" != 1 ]; then
  echo "skipped (set FUSE_NETWORK_TESTS=1 to run; needs the npm registry)"
  exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
HOOK="${HOOK_SH:-$ROOT/.cursor-plugin/plugins/core-guards/scripts/hook.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HOME_DIR="$TMP/home"; CR="$HOME_DIR/.cursor/.fusengine-global"
export BUN_INSTALL_CACHE_DIR="$TMP/bun-cache"   # no stale cached copy can satisfy the install
FAILS=0
ok()   { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILS=$((FAILS + 1)); }
hook() { printf '%s' "$1" | env HOME="$HOME_DIR" BUN_INSTALL_CACHE_DIR="$BUN_INSTALL_CACHE_DIR" sh "$HOOK" "${@:2}"; }

LATEST="$(npm view @fusengine/harness version 2>/dev/null)"
[ -n "$LATEST" ] || { echo "cannot reach the npm registry" >&2; exit 1; }
printf 'registry latest: %s\n' "$LATEST"

# Vendor 0.1.110 the way the layout expects: versions/<ver>/node_modules + current.
OLDV=0.1.110
mkdir -p "$CR/versions/$OLDV"
printf '{"name":"stage","private":true}\n' > "$CR/versions/$OLDV/package.json"
(cd "$CR/versions/$OLDV" && bun add "@fusengine/harness@$OLDV" --silent >/dev/null 2>&1)
echo "$OLDV" > "$CR/current"
before="$(bun "$CR/versions/$OLDV/node_modules/@fusengine/harness/dist/cli/bin.mjs" --version 2>&1)"
case "$before" in *"$OLDV"*) true ;; *) false ;; esac && ok "seeded $before" || fail "seed is '$before'"

SESSION='{"hook_event_name":"sessionStart","session_id":"s","composer_mode":"agent","is_background_agent":false,"workspace_roots":["/tmp"]}'
hook "$SESSION" --session-start rules >/dev/null 2>&1
read -r now < "$CR/current"
printf 'installed after session start: %s\n' "$now"
[ "$now" = "$LATEST" ] && ok "current == registry latest ($now)" || fail "current is $now, expected $LATEST"
answer="$(bun "$CR/versions/$now/node_modules/@fusengine/harness/dist/cli/bin.mjs" --version 2>&1 | tail -1)"
[ "$answer" = "$now" ] && ok "bin answers $answer" || fail "bin answers '$answer'"
[ -d "$CR/versions/$OLDV" ] && ok "previous version kept" || fail "previous version missing"

DENY="$(cd /tmp && hook '{"hook_event_name":"beforeShellExecution","command":"rm -rf /","cwd":"/tmp","workspace_roots":["/tmp"]}')"
case "$DENY" in *'"permission":"deny"'*) ok "guard denies destructive command on $now" ;; *) fail "destructive not denied: $DENY" ;; esac
ALLOW="$(cd /tmp && hook '{"hook_event_name":"beforeShellExecution","command":"ls -la","cwd":"/tmp","workspace_roots":["/tmp"]}')"
case "$ALLOW" in *'"permission":"allow"'*) ok "guard allows benign command on $now" ;; *) fail "benign not allowed: $ALLOW" ;; esac

printf '\n%s failures\n' "$FAILS"
[ "$FAILS" -eq 0 ]
