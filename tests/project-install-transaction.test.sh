#!/usr/bin/env bash
# Adversarial transaction and concurrency regressions.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROJECT="$TMP/project"
FAKE_HOME="$TMP/home"
mkdir -p "$PROJECT" "$FAKE_HOME"

HOME="$FAKE_HOME" "$ROOT/install.sh" --project "$PROJECT" >/dev/null
BASELINE="$(cd "$PROJECT" && node .cursor/fusengine/load-plugins.mjs)"

for point in before-old-move after-old-move after-new-move after-finalize; do
  if HOME="$FAKE_HOME" NODE_ENV=test FUSE_INSTALL_TEST_FAIL_POINT="$point" \
    "$ROOT/install.sh" --project "$PROJECT" 2>"$TMP/$point.error"; then
    printf 'expected transaction failure at %s\n' "$point" >&2
    exit 1
  fi
  grep -q "injected transaction failure at $point" "$TMP/$point.error"
  test "$BASELINE" = "$(cd "$PROJECT" && node .cursor/fusengine/load-plugins.mjs)"
  "$ROOT/verify-project.sh" "$PROJECT" >/dev/null
  test -z "$(find "$PROJECT/.cursor" -maxdepth 1 \( -name '.fusengine-stage-*' -o -name '.fusengine-backup-*' \) -print -quit)"
done
printf 'PASS every injected transaction failure restores the prior installation\n'

HOME="$FAKE_HOME" NODE_ENV=test FUSE_INSTALL_TEST_HOLD_LOCK_MS=750 \
  "$ROOT/install.sh" --project "$PROJECT" >/dev/null 2>"$TMP/first.error" &
first_pid=$!
for _ in $(seq 1 100); do
  test -d "$PROJECT/.cursor/.fusengine-install.lock" && break
  sleep 0.01
done
test -d "$PROJECT/.cursor/.fusengine-install.lock"
if HOME="$FAKE_HOME" "$ROOT/install.sh" --project "$PROJECT" 2>"$TMP/concurrent.error"; then
  printf 'expected concurrent install rejection\n' >&2
  exit 1
fi
grep -q 'another Fusengine install is active' "$TMP/concurrent.error"
wait "$first_pid"
test ! -e "$PROJECT/.cursor/.fusengine-install.lock"
"$ROOT/verify-project.sh" "$PROJECT" >/dev/null
printf 'PASS concurrent install is rejected without corrupting active installation\n'

CRASHED="$TMP/crashed-project"
mkdir -p "$CRASHED"
HOME="$FAKE_HOME" "$ROOT/install.sh" --project "$CRASHED" >/dev/null
mv "$CRASHED/.cursor/fusengine" "$CRASHED/.cursor/.fusengine-backup-777-777"
cp -R "$CRASHED/.cursor/.fusengine-backup-777-777" "$CRASHED/.cursor/.fusengine-stage-777-777"
if HOME="$FAKE_HOME" NODE_ENV=test FUSE_INSTALL_TEST_FAIL_AFTER_PLUGIN=1 \
  "$ROOT/install.sh" --project "$CRASHED" 2>"$TMP/crash-recovery.error"; then
  printf 'expected post-recovery injected copy failure\n' >&2
  exit 1
fi
test -f "$CRASHED/.cursor/fusengine/.managed-by-fusengine"
test "$(cd "$CRASHED" && node .cursor/fusengine/load-plugins.mjs | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.exit(JSON.parse(s).pluginPaths.length===26?0:1))')" = ""
printf 'PASS hard-crash recovery restores the sole owned backup before staging\n'
