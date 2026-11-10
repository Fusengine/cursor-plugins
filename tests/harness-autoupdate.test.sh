#!/usr/bin/env bash
# Contract for the hook.sh harness upgrade path (staged install + atomic switch).
#
# Everything runs in a throwaway HOME with a stub `bun`: no network, the real
# ~/.cursor is never read or written. Every other external tool the script could
# spawn (find, mkdir, mv, ...) is wrapped by a logger so the zero-cost path can
# be asserted as "no process at all".
#
# HOOK_SH overrides the script under test (used to prove RED against an older copy).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
HOOK="${HOOK_SH:-$ROOT/.cursor-plugin/plugins/core-guards/scripts/hook.sh}"
TMP="$(mktemp -d)"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
FAILS=0
CASES=0
REAL_PATH="$PATH"
OLD=202001010000

ok()   { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILS=$((FAILS + 1)); }
check() { # name cmd...
  local name="$1"; shift
  if "$@"; then ok "$name"; else fail "$name"; fi
}

# new_case: fresh HOME, control root, stub dir and logs.
new_case() {
  CASES=$((CASES + 1))
  T="$TMP/c$CASES"
  HOME_DIR="$T/home"; CR="$HOME_DIR/.cursor/.fusengine-global"
  STUBS="$T/stubs"; LOG="$T/bun.log"; PROCS="$T/procs.log"
  mkdir -p "$CR" "$STUBS"; : > "$LOG"; : > "$PROCS"
  cat > "$STUBS/bun" <<'STUB'
#!/bin/sh
# Records the call. `add` fabricates the staged install; anything else is a bin run.
echo "$*" >> "$STUB_LOG"
if [ "$1" = add ]; then
  [ -z "$STUB_ADD_SLEEP" ] || /bin/sleep "$STUB_ADD_SLEEP"
  [ "${STUB_ADD_RC:-0}" = 0 ] || exit "$STUB_ADD_RC"
  mkdir -p node_modules/@fusengine/harness/dist/cli
  printf '{\n  "name": "@fusengine/harness",\n  "version": "%s"\n}\n' "${STUB_NEW_VERSION:-0.1.115}" \
    > node_modules/@fusengine/harness/package.json
  echo "// bin" > node_modules/@fusengine/harness/dist/cli/bin.mjs
  exit 0
fi
case "$1" in /*) [ -f "$1" ] || exit 127 ;; esac   # a bin that does not exist cannot answer
exit "${STUB_RUN_RC:-0}"
STUB
  chmod +x "$STUBS/bun"
  for tool in find mkdir rmdir mv rm touch sleep date cat timeout curl npx wget sed awk grep cp ln; do
    real="$(PATH="$REAL_PATH" command -v "$tool" || true)"
    [ -n "$real" ] || continue
    printf '#!/bin/sh\necho %s >> "$STUB_PROCS"\nexec %s "$@"\n' "$tool" "$real" > "$STUBS/$tool"
    chmod +x "$STUBS/$tool"
  done
  # Network tools are logged but never forwarded: the suite must stay offline.
  for tool in npx curl wget; do
    printf '#!/bin/sh\necho %s >> "$STUB_PROCS"\nexit 0\n' "$tool" > "$STUBS/$tool"
    chmod +x "$STUBS/$tool"
  done
}

seed_version() { # dir-under-root version  (layout: versions/<ver> or legacy)
  local base="$1" ver="$2"
  mkdir -p "$base/node_modules/@fusengine/harness/dist/cli"
  printf '{\n  "name": "@fusengine/harness",\n  "version": "%s"\n}\n' "$ver" > "$base/node_modules/@fusengine/harness/package.json"
  echo "// bin $ver" > "$base/node_modules/@fusengine/harness/dist/cli/bin.mjs"
}
seed_current() { seed_version "$CR/versions/$1" "$1"; echo "$1" > "$CR/current"; }
seed_legacy()  { seed_version "$CR" "$1"; }
age() { touch -t "$OLD" "$@"; }

# hook ARGS... : run the script in the sandbox; stdin carries a payload.
hook() {
  printf '{"hook":"payload"}' | env -i HOME="$HOME_DIR" PATH="$STUBS:/usr/bin:/bin" \
    STUB_LOG="$LOG" STUB_PROCS="$PROCS" \
    ${STUB_ADD_RC:+STUB_ADD_RC=$STUB_ADD_RC} ${STUB_NEW_VERSION:+STUB_NEW_VERSION=$STUB_NEW_VERSION} \
    ${FUSE_HARNESS_UPDATE_BACKOFF_MIN:+FUSE_HARNESS_UPDATE_BACKOFF_MIN=$FUSE_HARNESS_UPDATE_BACKOFF_MIN} \
    ${STUB_ADD_SLEEP:+STUB_ADD_SLEEP=$STUB_ADD_SLEEP} \
    ${FUSE_HARNESS_INSTALL_TIMEOUT_SEC:+FUSE_HARNESS_INSTALL_TIMEOUT_SEC=$FUSE_HARNESS_INSTALL_TIMEOUT_SEC} \
    ${FUSE_HARNESS_LOCK_WAIT_SEC:+FUSE_HARNESS_LOCK_WAIT_SEC=$FUSE_HARNESS_LOCK_WAIT_SEC} \
    "${TEST_SH:-sh}" "$HOOK" "$@"
}
adds()  { grep -c '^add ' "$LOG" || true; }
runs()  { grep -c 'hook cursor' "$LOG" || true; }
cur()   { read -r v < "$CR/current" 2>/dev/null; printf '%s' "${v:-}"; }
reset_env() { unset STUB_ADD_SLEEP FUSE_HARNESS_INSTALL_TIMEOUT_SEC STUB_ADD_RC STUB_NEW_VERSION FUSE_HARNESS_UPDATE_BACKOFF_MIN FUSE_HARNESS_LOCK_WAIT_SEC; }

eq() { [ "$1" = "$2" ]; }

# 1. Current version at session start: zero process, zero update, scopes intact.
reset_env; new_case; seed_current 0.1.115
hook --session-start rules
check "current: bin run with scope, flag stripped" grep -q "versions/0.1.115/.*bin.mjs hook cursor rules$" "$LOG"
check "current: no bun add"                       eq "$(adds)" 0
check "current: ZERO external process"            eq "$(wc -c < "$PROCS" | tr -d ' ')" 0

# 2. Newer than the minimum: same.
reset_env; new_case; seed_current 0.1.200
hook --session-start
check "newer: no bun add"          eq "$(adds)" 0
check "newer: ZERO external process" eq "$(wc -c < "$PROCS" | tr -d ' ')" 0

# 3. Stale + no stamp: one add, new bin runs, pointer switched, old tree kept.
reset_env; new_case; seed_current 0.1.110
hook --session-start solid
check "stale: exactly one bun add"        eq "$(adds)" 1
check "stale: pointer switched"           eq "$(cur)" 0.1.115
check "stale: new bin executed with scope" grep -q "versions/0.1.115/.*bin.mjs hook cursor solid$" "$LOG"
check "stale: previous version kept"      test -f "$CR/versions/0.1.110/node_modules/@fusengine/harness/dist/cli/bin.mjs"
check "stale: no stamp after success"     test ! -e "$CR/.harness-update-failed"
check "stale: lock released"              test ! -e "$CR/.harness-update.lock"
check "stale: staging dir cleaned"        eq "$(ls -A "$CR/versions" | grep -c '^\.stage' || true)" 0

# 4. Legacy node_modules install (no pointer): upgraded, legacy left in place.
reset_env; new_case; seed_legacy 0.1.110
hook --session-start
check "legacy: one bun add"          eq "$(adds)" 1
check "legacy: pointer created"      eq "$(cur)" 0.1.115
check "legacy: legacy tree untouched" test -f "$CR/node_modules/@fusengine/harness/dist/cli/bin.mjs"

# 5. Legacy fast path without upgrade need.
reset_env; new_case; seed_legacy 0.1.115
hook --session-start
check "legacy current: legacy bin runs" grep -q "$CR/node_modules/@fusengine/harness/dist/cli/bin.mjs hook cursor" "$LOG"
check "legacy current: no add"          eq "$(adds)" 0

# 6. Non-session-start stale: never upgrades, zero process.
reset_env; new_case; seed_current 0.1.110
hook solid
check "non-session: no add"           eq "$(adds)" 0
check "non-session: old bin runs"     grep -q "versions/0.1.110/.*bin.mjs hook cursor solid$" "$LOG"
check "non-session: ZERO process"     eq "$(wc -c < "$PROCS" | tr -d ' ')" 0

# 7. Back-off window.
reset_env; new_case; seed_current 0.1.110; : > "$CR/.harness-update-failed"
hook --session-start
check "fresh stamp: no add" eq "$(adds)" 0
reset_env; new_case; seed_current 0.1.110; : > "$CR/.harness-update-failed"; age "$CR/.harness-update-failed"
hook --session-start
check "old stamp: add" eq "$(adds)" 1
reset_env; new_case; seed_current 0.1.110; : > "$CR/.harness-update-failed"
touch -t "$(date -v-10M +%Y%m%d%H%M 2>/dev/null || date -d '-10 min' +%Y%m%d%H%M)" "$CR/.harness-update-failed"
FUSE_HARNESS_UPDATE_BACKOFF_MIN=5; hook --session-start
check "env 5 min, 10-min stamp: add" eq "$(adds)" 1
reset_env; new_case; seed_current 0.1.110; : > "$CR/.harness-update-failed"
touch -t "$(date -v-10M +%Y%m%d%H%M 2>/dev/null || date -d '-10 min' +%Y%m%d%H%M)" "$CR/.harness-update-failed"
FUSE_HARNESS_UPDATE_BACKOFF_MIN=60; hook --session-start
check "env 60 min, 10-min stamp: no add" eq "$(adds)" 0
reset_env

# 8. Failure writes the stamp and leaves the live tree; success clears it.
new_case; seed_current 0.1.110
STUB_ADD_RC=1; hook --session-start
check "failed add: stamp written"      test -e "$CR/.harness-update-failed"
check "failed add: pointer unchanged"  eq "$(cur)" 0.1.110
check "failed add: old bin still ran"  grep -q "versions/0.1.110/.*bin.mjs hook cursor" "$LOG"
check "failed add: lock released"      test ! -e "$CR/.harness-update.lock"
check "failed add: staging cleaned"    eq "$(ls -A "$CR/versions" | grep -c '^\.stage' || true)" 0
reset_env; new_case; seed_current 0.1.110; : > "$CR/.harness-update-failed"; age "$CR/.harness-update-failed"
hook --session-start
check "success: stamp removed" test ! -e "$CR/.harness-update-failed"

# 9. Registry still serving a version below the minimum: switch (progress), keep stamp.
reset_env; new_case; seed_current 0.1.110
STUB_NEW_VERSION=0.1.113; hook --session-start
check "below-min: pointer moves to 0.1.113" eq "$(cur)" 0.1.113
check "below-min: stamp kept (retry later)" test -e "$CR/.harness-update-failed"
reset_env; new_case; seed_current 0.1.114
STUB_NEW_VERSION=0.1.113; hook --session-start
check "never downgrade: pointer stays"      eq "$(cur)" 0.1.114

# 10. Locks: held -> no add; stale -> reclaimed.
reset_env; new_case; seed_current 0.1.110; mkdir "$CR/.harness-update.lock"
hook --session-start
check "held lock: no add"           eq "$(adds)" 0
check "held lock: old bin still runs" grep -q "versions/0.1.110/.*bin.mjs hook cursor" "$LOG"
check "held lock: lock not stolen"   test -d "$CR/.harness-update.lock"
reset_env; new_case; seed_current 0.1.110; mkdir "$CR/.harness-update.lock"; age "$CR/.harness-update.lock"
hook --session-start
check "stale lock: reclaimed, one add" eq "$(adds)" 1
check "stale lock: released after"     test ! -e "$CR/.harness-update.lock"

# 11. No bun: stamp, old bin via node, no crash.
reset_env; new_case; seed_current 0.1.110; rm "$STUBS/bun"
printf '#!/bin/sh\necho "node $*" >> "$STUB_LOG"\n' > "$STUBS/node"; chmod +x "$STUBS/node"
hook --session-start
check "no bun: old bin ran via node" grep -q "node .*versions/0.1.110/.*bin.mjs hook cursor" "$LOG"
check "no bun: stamp written"        test -e "$CR/.harness-update-failed"

# 12. Read-only control root: fail open, old bin runs.
reset_env; new_case; seed_current 0.1.110; chmod -R a-w "$CR"
hook --session-start
chmod -R u+w "$CR"
check "read-only: no add"      eq "$(adds)" 0
check "read-only: old bin ran" grep -q "versions/0.1.110/.*bin.mjs hook cursor" "$LOG"

# 13. Pruning keeps new + previous + recent, removes old extras.
reset_env; new_case; seed_current 0.1.110
seed_version "$CR/versions/0.1.100" 0.1.100; age "$CR/versions/0.1.100"
seed_version "$CR/versions/0.1.108" 0.1.108
mkdir -p "$CR/versions/.stage-999"; age "$CR/versions/.stage-999"
hook --session-start
check "prune: old extra removed"   test ! -e "$CR/versions/0.1.100"
check "prune: dead staging removed" test ! -e "$CR/versions/.stage-999"
check "prune: previous kept"        test -d "$CR/versions/0.1.110"
check "prune: recent extra kept"    test -d "$CR/versions/0.1.108"
check "prune: new kept"             test -d "$CR/versions/0.1.115"

# 14. Hostile pointer never escapes the control root.
reset_env; new_case; seed_legacy 0.1.115; echo "../../etc" > "$CR/current"
hook --session-start
check "bad pointer: legacy bin used" grep -q "$CR/node_modules/@fusengine/harness/dist/cli/bin.mjs hook cursor" "$LOG"

# 15. Nothing installed: self-heal installs once through the staged path.
reset_env; new_case
hook solid
check "self-heal: one add"        eq "$(adds)" 1
check "self-heal: pointer set"    eq "$(cur)" 0.1.115
check "self-heal: new bin ran"    grep -q "versions/0.1.115/.*bin.mjs hook cursor solid$" "$LOG"
rm -rf "$CR/versions" "$CR/current"; : > "$LOG"
hook solid
check "self-heal: stamp stops a second attempt" eq "$(adds)" 0

# 16. --install-harness (installer entry): switches, bypasses back-off, rc reflects result.
reset_env; new_case; seed_current 0.1.110; : > "$CR/.harness-update-failed"
hook --install-harness; rc=$?
check "install-harness: rc 0"           eq "$rc" 0
check "install-harness: pointer moved"  eq "$(cur)" 0.1.115
check "install-harness: no bin run"    eq "$(runs)" 0
reset_env; new_case; seed_current 0.1.110; STUB_ADD_RC=1; hook --install-harness; rc=$?
check "install-harness failure: rc 1, pointer intact" eq "$rc.$(cur)" 1.0.1.110
reset_env

# 17. versions/<new> exists but is broken: replaced by the verified stage, never kept broken.
# (The stub bun runs every bin successfully, so "broken" is simulated by a missing bin.)
reset_env; new_case; seed_current 0.1.110
mkdir -p "$CR/versions/0.1.115/node_modules"
hook --session-start
check "broken dest: replaced and switched"  eq "$(cur)" 0.1.115
check "broken dest: bin present afterwards" test -f "$CR/versions/0.1.115/node_modules/@fusengine/harness/dist/cli/bin.mjs"
check "broken dest: old tree kept aside"    test -d "$CR/versions/0.1.115.broken.$(ls "$CR/versions" | sed -n 's/.*broken\.//p' | head -1)"

# 18. `current` is a directory: the switch is reported as failed (stamp), not as success.
reset_env; new_case; seed_current 0.1.110; rm "$CR/current"; mkdir "$CR/current"
seed_legacy 0.1.110
hook --session-start
check "current is a dir: stamp written (no success reported)" test -e "$CR/.harness-update-failed"
check "current is a dir: legacy bin still ran"                grep -q "$CR/node_modules/@fusengine/harness/dist/cli/bin.mjs hook cursor" "$LOG"
check "current is a dir: no temp file left inside"            eq "$(ls -A "$CR/current" | wc -l | tr -d ' ')" 0

# 19. A hung install is killed by the portable bound: stamp kept, live tree intact,
#     lock released, ONE warning on stderr, stdout clean.
reset_env; new_case; seed_current 0.1.110
STUB_ADD_SLEEP=30; FUSE_HARNESS_INSTALL_TIMEOUT_SEC=1
start=$SECONDS; hook --session-start solid > "$T/out" 2> "$T/err"; took=$((SECONDS - start))
check "hung install: returned within the bound"  test "$took" -lt 10
check "hung install: stamp written"              test -e "$CR/.harness-update-failed"
check "hung install: pointer unchanged"          eq "$(cur)" 0.1.110
check "hung install: old bin ran"                grep -q "versions/0.1.110/.*bin.mjs hook cursor solid$" "$LOG"
check "hung install: lock released"              test ! -e "$CR/.harness-update.lock"
check "hung install: staging cleaned"            eq "$(ls -A "$CR/versions" | grep -c '^\.stage' || true)" 0
check "hung install: exactly one stderr warning" eq "$(wc -l < "$T/err" | tr -d ' ')" 1
check "hung install: warning names versions"     grep -q "installed 0.1.110, target >= 0.1.115" "$T/err"
check "hung install: stdout clean"               test ! -s "$T/out"
reset_env

# 20. Failed add: warning once, nothing on stdout; success: silent.
new_case; seed_current 0.1.110; STUB_ADD_RC=1
hook --session-start > "$T/out" 2> "$T/err"
check "failed add: one warning"  eq "$(wc -l < "$T/err" | tr -d ' ')" 1
check "failed add: stdout clean" test ! -s "$T/out"
check "failed add: default 30 min" grep -q "retry in 30 min" "$T/err"
reset_env; new_case; seed_current 0.1.110; : > "$CR/.harness-update-failed"
touch -t "$(date -v-10M +%Y%m%d%H%M 2>/dev/null || date -d '-10 min' +%Y%m%d%H%M)" "$CR/.harness-update-failed"
STUB_ADD_RC=1; FUSE_HARNESS_UPDATE_BACKOFF_MIN=7; hook --session-start > "$T/out" 2> "$T/err"
check "failed add: warning shows configured 7 min" grep -q "retry in 7 min" "$T/err"
reset_env; new_case; seed_current 0.1.110
hook --session-start > "$T/out" 2> "$T/err"
check "success: silent stderr"   test ! -s "$T/err"
reset_env

# 21. Every shipped copy of the wrapper is byte-identical (22 plugins + plugin-runtime).
if [ -z "${HOOK_SH:-}" ]; then
  copies="$(cd "$ROOT/.cursor-plugin" && cat plugins/*/scripts/hook.sh >/dev/null && ls plugins/*/scripts/hook.sh plugin-runtime/hook.sh | wc -l | tr -d ' ')"
  distinct="$(cd "$ROOT/.cursor-plugin" && cksum plugins/*/scripts/hook.sh plugin-runtime/hook.sh | awk '{print $1" "$2}' | sort -u | wc -l | tr -d ' ')"
  check "hook.sh copies: 23 found" eq "$copies" 23
  check "hook.sh copies: all byte-identical" eq "$distinct" 1
fi

# 22. --harness-check (upgrade-only mode for plugins whose sessionStart must not run the bin).
reset_env; new_case; seed_current 0.1.110
hook --harness-check > "$T/out" 2> "$T/err"; rc=$?
check "check/stale: rc 0"               eq "$rc" 0
check "check/stale: one bun add"        eq "$(adds)" 1
check "check/stale: pointer switched"   eq "$(cur)" 0.1.115
check "check/stale: bin never executed" eq "$(runs)" 0
check "check/stale: stdout empty"       test ! -s "$T/out"
reset_env; new_case; seed_current 0.1.115
hook --harness-check > "$T/out" 2> "$T/err"; rc=$?
check "check/current: rc 0, nothing run" eq "$rc.$(adds).$(runs)" 0.0.0
check "check/current: ZERO process"      eq "$(wc -c < "$PROCS" | tr -d ' ')" 0
check "check/current: stdout+stderr empty" test ! -s "$T/out$T/err"
reset_env; new_case
hook --harness-check; rc=$?
check "check/nothing installed: rc 0, no add, no bin" eq "$rc.$(adds).$(runs)" 0.0.0
reset_env; new_case; seed_current 0.1.110; : > "$CR/.harness-update-failed"
hook --harness-check
check "check: back-off honoured" eq "$(adds)" 0
reset_env; new_case; seed_current 0.1.110; STUB_ADD_RC=1
hook --harness-check > "$T/out" 2> "$T/err"
check "check/failure: one stderr warning, stdout empty" eq "$(wc -l < "$T/err" | tr -d ' ').$(wc -c < "$T/out" | tr -d ' ')" 1.0
reset_env

# 23. --install-harness failure prints the one-line warning on stderr.
new_case; seed_current 0.1.110; STUB_ADD_RC=1
hook --install-harness > "$T/out" 2> "$T/err"; rc=$?
check "install-harness failure: rc 1" eq "$rc" 1
check "install-harness failure: one warning line, stdout empty" eq "$(wc -l < "$T/err" | tr -d ' ').$(wc -c < "$T/out" | tr -d ' ')" 1.0
reset_env

# 24. Install bound stays under Cursor's 60 s default hook timeout.
check "install bound default < 60 s" grep -q 'FUSE_HARNESS_INSTALL_TIMEOUT_SEC:-45' "$HOOK"

# 25. Every plugin hooks.json triggers the check at sessionStart, with a timeout that
#     is not capped below the install bound (solid used to carry 5 s).
if [ -z "${HOOK_SH:-}" ]; then
  bad="$(node - "$ROOT/.cursor-plugin/plugins" <<'NODE'
const fs = require('fs'), path = require('path');
const dir = process.argv[2];
const bad = [];
for (const name of fs.readdirSync(dir)) {
  const f = path.join(dir, name, 'hooks/hooks.json');
  if (!fs.existsSync(f)) continue;
  const entries = (JSON.parse(fs.readFileSync(f, 'utf8')).hooks || {}).sessionStart || [];
  const e = entries.find((x) => /^\.\/scripts\/hook\.sh --(session-start|harness-check)\b/.test(x.command || ''));
  if (!e) { bad.push(`${name}: no upgrade-capable sessionStart`); continue; }
  if (e.timeout !== undefined && e.timeout < 60) bad.push(`${name}: timeout ${e.timeout} < 60`);
  if (entries.some((x) => x !== e && /^\.\/scripts\/hook\.sh --(session-start|harness-check)\b/.test(x.command || ''))) bad.push(`${name}: duplicate`);
}
console.log(bad.join('\n'));
NODE
)"
  check "all hooks.json: sessionStart upgrade entry, timeout >= 60 ($bad)" test -z "$bad"
fi

printf '\n%s cases, %s failures\n' "$CASES" "$FAILS"
[ "$FAILS" -eq 0 ]
