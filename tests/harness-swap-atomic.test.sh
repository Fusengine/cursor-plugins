#!/usr/bin/env bash
# Atomicity contract for the hook.sh harness upgrade.
#
# (a) While hook.sh swaps the live harness version, thousands of concurrent hook
#     launches and a few long-running processes that import a hashed chunk AFTER
#     the swap must all succeed: 0 failures.
# (b) kill -9 in the middle of the staging install leaves a fully working live
#     tree (same version, bin runs) and the next attempt recovers.
#
# Real bun, fake local harness package (no network, throwaway HOME). Tunables:
#   N=<launches per run> (default 300; the acceptance run uses N=2000 RUNS=5)
#   RUNS=<repetitions>    (default 1)
#   DEADLINE_SEC=<hard limit per run> (default 600; exceeded = loud failure)
#   WINDOW_MS=<overlap window around the rename to report> (default 100)
# Speed-independent: workers launch continuously, the swap waits for N/10 launches
# to have completed, and the run goes on until N launches in total AND N/10 after
# the swap, so every run spans the swap whatever the runner speed.
#   HOOK_SH=<script>      script under test
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
HOOK="${HOOK_SH:-$ROOT/.cursor-plugin/plugins/core-guards/scripts/hook.sh}"
N="${N:-300}"; RUNS="${RUNS:-1}"; WORKERS=4
REAL_BUN="$(command -v bun)"; export REAL_BUN
TMP="$(mktemp -d)"
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$TMP"' EXIT
FAILS=0
ok()   { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; FAILS=$((FAILS + 1)); }

# fake_version VER : fixture for a harness release. The bin lazily imports a chunk
# whose name is version-specific, like the real hashed chunks.
FAKE="$TMP/fake"
fake_version() {
  local v="$1" d="$FAKE/$1"
  mkdir -p "$d/dist/cli"
  printf '{\n  "name": "@fusengine/harness",\n  "version": "%s"\n}\n' "$v" > "$d/package.json"
  printf 'export default "%s";\n' "$v" > "$d/dist/hook-entry-$v.mjs"
  cat > "$d/dist/cli/bin.mjs" <<JS
if (process.argv.includes("--version")) { console.log("$v"); process.exit(0); }
if (process.argv.includes("long")) {
  // Loaded, then parked until the swap is over: the chunk import below happens AFTER it.
  const fs = await import("node:fs");
  fs.writeFileSync(process.env.GO_FILE + ".ready." + process.pid, "");
  const deadline = Date.now() + 180000;
  while (!fs.existsSync(process.env.GO_FILE) && Date.now() < deadline) await new Promise((r) => setTimeout(r, 20));
}
const m = await import("../hook-entry-$v.mjs");
console.log(m.default);
JS
}
fake_version 0.1.100
fake_version 0.1.200

# Sandbox with a stub bun: `add` fabricates the install (slowly), all else is real bun.
sandbox() {
  S="$TMP/s$1"; HOME_DIR="$S/home"; CR="$HOME_DIR/.cursor/.fusengine-global"; STUBS="$S/stubs"
  mkdir -p "$STUBS" "$CR/versions"
  cat > "$STUBS/bun" <<'STUB'
#!/bin/sh
if [ "$1" = add ]; then
  [ -z "$ADD_LOG" ] || echo add >> "$ADD_LOG"
  [ -z "$ADD_SLEEP" ] || /bin/sleep "$ADD_SLEEP"
  mkdir -p node_modules/@fusengine/harness
  cp -R "$FAKE_DIR/$FAKE_VERSION/." node_modules/@fusengine/harness/
  exit 0
fi
exec "$REAL_BUN" "$@"
STUB
  chmod +x "$STUBS/bun"
  mkdir -p "$CR/versions/0.1.100/node_modules/@fusengine/harness"
  cp -R "$FAKE/0.1.100/." "$CR/versions/0.1.100/node_modules/@fusengine/harness/"
  echo 0.1.100 > "$CR/current"
}
hook() { # args... ; stdin payload
  printf '{}' | env -i HOME="$HOME_DIR" PATH="$STUBS:/usr/bin:/bin" REAL_BUN="$REAL_BUN" \
    FAKE_DIR="$FAKE" FAKE_VERSION=0.1.200 ADD_SLEEP="${ADD_SLEEP:-}" ADD_LOG="${ADD_LOG:-}" GO_FILE="${GO_FILE:-}" "${TEST_SH:-sh}" "$HOOK" "$@"
}
cur() { read -r v < "$CR/current"; printf '%s' "$v"; }

# Microsecond clock into $NOW without a subshell when bash provides EPOCHREALTIME.
if [ -n "${EPOCHREALTIME:-}" ]; then now_us() { NOW=${EPOCHREALTIME/[.,]/}; }
else now_us() { NOW=$(( $(date +%s%N) / 1000 )); }; fi

# worker OUT : launch until OUT.stop appears; one log line per launch:
# "<start_us> <end_us> <version-or-ERR>"; failing output goes to OUT.err.
worker() {
  local r s e
  while [ ! -e "$1.stop" ]; do
    now_us; s=$NOW
    r="$(hook solid 2>&1)"
    now_us; e=$NOW
    case "$r" in
      0.1.100|0.1.200) printf '%s %s %s\n' "$s" "$e" "$r" >> "$1.log" ;;
      *) printf '%s %s ERR\n' "$s" "$e" >> "$1.log"; printf '%s\n' "$r" | head -2 >> "$1.err" ;;
    esac
  done
}
launches() { cat "$S"/w*.log 2>/dev/null | wc -l | tr -d ' '; }
# Fail loudly instead of hanging: $1 = condition description, rest = test command.
wait_until() { # deadline_epoch description cmd...
  local dl="$1" what="$2"; shift 2
  until "$@"; do
    if [ "$SECONDS" -ge "$dl" ]; then fail "deadline: $what"; return 1; fi
    sleep 0.1
  done
}

# ---- (a) atomic swap under load -------------------------------------------------
DEADLINE_SEC="${DEADLINE_SEC:-600}"; WINDOW_MS="${WINDOW_MS:-100}"
MIN_SIDE=$((N / 10))
for run in $(seq 1 "$RUNS"); do
  sandbox "a$run"
  GO_FILE="$S/go"; export GO_FILE
  dl=$((SECONDS + DEADLINE_SEC))
  for l in 1 2 3; do
    ( hook long > "$S/long$l.out" 2>&1; echo $? > "$S/long$l.rc" ) &
  done
  for w in $(seq 1 "$WORKERS"); do worker "$S/w$w" & done
  pre_ok() { [ "$(launches)" -ge "$MIN_SIDE" ] && [ "$(ls "$S"/go.ready.* 2>/dev/null | wc -l | tr -d ' ')" -ge 3 ]; }
  wait_until "$dl" "run $run: $MIN_SIDE launches and 3 parked processes before the swap" pre_ok

  # Watcher: the instant `current` names the new version (rename(2) just happened).
  ( while :; do read -r v < "$CR/current" 2>/dev/null; if [ "$v" = 0.1.200 ]; then now_us; echo "$NOW" > "$S/t_sw"; exit 0; fi; done ) &
  WATCH=$!
  ADD_SLEEP=0.5 hook --session-start >/dev/null 2>&1
  swap_rc=$?
  wait_until "$dl" "run $run: swap observed" test -s "$S/t_sw"
  kill "$WATCH" 2>/dev/null
  t_sw="$(cat "$S/t_sw" 2>/dev/null || echo 0)"
  post_ok() { [ "$(launches)" -ge "$N" ] && [ "$(cat "$S"/w*.log | awk -v t="$t_sw" '$1 > t' | wc -l | tr -d ' ')" -ge "$MIN_SIDE" ]; }
  wait_until "$dl" "run $run: $N launches, $MIN_SIDE of them after the swap" post_ok
  : > "$S/go"                          # parked processes now import their chunk, after the swap
  for w in $(seq 1 "$WORKERS"); do : > "$S/w$w.stop"; done
  wait

  # launches ok/bad, version seen, overlap with the rename (+-WINDOW_MS) from the logs.
  read -r tot tot_bad tot_old tot_new before after straddle near < <(cat "$S"/w*.log | awk -v t="$t_sw" -v wnd=$((WINDOW_MS * 1000)) '
    { n++; if ($3 == "ERR") bad++; else if ($3 == "0.1.100") old++; else new++
      if ($2 < t) before++; else if ($1 > t) after++; else straddle++
      d = $1 - t; if (d < 0) d = -d; if (d <= wnd) near++ }
    END { print n+0, bad+0, old+0, new+0, before+0, after+0, straddle+0, near+0 }')
  longbad=0
  for l in 1 2 3; do
    [ "$(cat "$S/long$l.out")" = "0.1.100" ] && [ "$(cat "$S/long$l.rc")" = 0 ] || longbad=$((longbad + 1))
  done
  printf 'run %s: launches=%s failed=%s sawOld=%s sawNew=%s | before=%s after=%s inFlightAtRename=%s startedWithin%sms=%s | longProcFailures=%s\n' \
    "$run" "$tot" "$tot_bad" "$tot_old" "$tot_new" "$before" "$after" "$straddle" "$WINDOW_MS" "$near" "$longbad"
  [ "$tot" -ge "$N" ] && ok "run $run: $tot launches (>= $N)" || fail "run $run: only $tot launches"
  [ "$tot_bad" -eq 0 ] && ok "run $run: 0 failed launches" || { fail "run $run: $tot_bad failed launches"; cat "$S"/w*.err 2>/dev/null | sort | uniq -c | head -3 >&2; }
  [ "$before" -ge "$MIN_SIDE" ] && [ "$after" -ge "$MIN_SIDE" ] && [ "$tot_old" -gt 0 ] && [ "$tot_new" -gt 0 ] \
    && ok "run $run: loop spanned the swap ($before before, $after after)" || fail "run $run: loop did not span the swap (before=$before after=$after old=$tot_old new=$tot_new)"
  [ "$longbad" -eq 0 ] && ok "run $run: pre-swap processes lazily imported after the swap" || fail "run $run: $longbad long processes broke"
  # Evidence that the swap really happened on THIS platform: pointer value and what the live bin reports.
  live="$(bun "$CR/versions/$(cur)/node_modules/@fusengine/harness/dist/cli/bin.mjs" --version 2>&1)"
  printf 'run %s: current=%s liveBinReports=%s previousKept=%s\n' "$run" "$(cur)" "$live" "$(ls "$CR/versions" | tr '\n' ' ')"
  [ "$swap_rc" -eq 0 ] && [ "$(cur)" = 0.1.200 ] && [ "$live" = 0.1.200 ] && ok "run $run: pointer switched, live bin reports 0.1.200" || fail "run $run: pointer is $(cur), bin reports $live"
done
unset GO_FILE

# ---- (b) kill -9 mid-install -----------------------------------------------------
descendants() { local p; for p in $(pgrep -P "$1" 2>/dev/null); do descendants "$p"; echo "$p"; done; }
sandbox b
ADD_SLEEP=30 hook --session-start >/dev/null 2>&1 &
HP=$!
for _ in $(seq 1 100); do ls "$CR"/versions/.stage-* >/dev/null 2>&1 && break; sleep 0.1; done
ls "$CR"/versions/.stage-* >/dev/null 2>&1 && ok "staging started" || fail "staging never started"
# shellcheck disable=SC2046
kill -9 $(descendants "$HP") "$HP" 2>/dev/null
wait "$HP" 2>/dev/null
[ "$(cur)" = 0.1.100 ] && ok "kill -9: pointer unchanged" || fail "kill -9: pointer is $(cur)"
[ "$(hook solid 2>&1)" = 0.1.100 ] && ok "kill -9: live tree still works" || fail "kill -9: live tree broken"
[ -d "$CR/.harness-update.lock" ] && ok "kill -9: lock left behind (expected)" || fail "kill -9: no lock left"
before="$(cur)"
hook --session-start >/dev/null 2>&1
[ "$(cur)" = "$before" ] && ok "kill -9: immediate retry suppressed (lock + back-off)" || fail "kill -9: retried too early"
touch -t 202001010000 "$CR/.harness-update.lock" "$CR/.harness-update-failed"
hook --session-start >/dev/null 2>&1
[ "$(cur)" = 0.1.200 ] && [ "$(hook solid 2>&1)" = 0.1.200 ] && ok "kill -9: next attempt recovers to 0.1.200" || fail "kill -9: no recovery (pointer $(cur))"
[ ! -e "$CR/.harness-update-failed" ] && [ ! -e "$CR/.harness-update.lock" ] && ok "kill -9: stamp and lock cleared after recovery" || fail "kill -9: leftovers after recovery"

# ---- (c) five racing sessionStart hooks: exactly one installer --------------------
sandbox c
ADD_LOG="$S/adds.log"; : > "$ADD_LOG"
for _ in 1 2 3 4 5; do ADD_SLEEP=0.5 hook --session-start >/dev/null 2>&1 & done
wait
[ "$(wc -l < "$ADD_LOG" | tr -d ' ')" = 1 ] && ok "5 racing sessionStart hooks: exactly one install" || fail "racing hooks installed $(wc -l < "$ADD_LOG") times"
[ "$(cur)" = 0.1.200 ] && ok "race: pointer switched" || fail "race: pointer is $(cur)"
unset ADD_LOG

# ---- (e) 22 plugins fire sessionStart at once (mixed modes): exactly one installer --
for trial in 1 2 3; do
  sandbox "e$trial"
  ADD_LOG="$S/adds.log"; : > "$ADD_LOG"
  for i in $(seq 1 22); do
    if [ $((i % 2)) = 0 ]; then ADD_SLEEP=0.3 hook --session-start rules >/dev/null 2>&1 &
    else ADD_SLEEP=0.3 hook --harness-check >/dev/null 2>&1 &
    fi
  done
  wait
  n="$(wc -l < "$ADD_LOG" | tr -d ' ')"
  [ "$n" = 1 ] && [ "$(cur)" = 0.1.200 ] || { fail "22-way race trial $trial: $n installs, pointer $(cur)"; break; }
  [ "$trial" = 3 ] && ok "22-way sessionStart race: exactly one install, pointer switched (3 trials)"
done
unset ADD_LOG

# ---- (d) five racing hooks against a STALE lock: still exactly one installer -------
for trial in $(seq 1 15); do
  sandbox "d$trial"
  mkdir "$CR/.harness-update.lock"; touch -t 202001010000 "$CR/.harness-update.lock"
  ADD_LOG="$S/adds.log"; : > "$ADD_LOG"
  for _ in 1 2 3 4 5; do ADD_SLEEP=0.3 hook --session-start >/dev/null 2>&1 & done
  wait
  n="$(wc -l < "$ADD_LOG" | tr -d ' ')"
  nested="$(ls -A "$CR/versions/0.1.200" 2>/dev/null | grep -c '^\.stage' || true)"
  [ "$n" = 1 ] && [ "$nested" = 0 ] || { fail "stale-lock race trial $trial: $n installs, $nested nested stages"; break; }
  [ "$trial" = 15 ] && ok "stale-lock race: exactly one install in 15 trials, no nested stage"
done
unset ADD_LOG

printf '\n%s failures\n' "$FAILS"
[ "$FAILS" -eq 0 ]
