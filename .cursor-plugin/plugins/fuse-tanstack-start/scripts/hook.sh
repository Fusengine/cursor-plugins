#!/bin/sh
# Fusengine hook entrypoint — shipped inside every plugin as scripts/hook.sh.
#
# Resolves the shared harness itself so the plugin works from the Cursor
# marketplace, where no installer ever runs. Layout under the control root
# ($HOME/.cursor/.fusengine-global):
#
#   versions/<ver>/node_modules/@fusengine/harness   one immutable install per version
#   current                                          text file: the live <ver>
#   node_modules/@fusengine/harness                  legacy single install (fallback)
#
# Resolution order:
#   1. the version named by `current` (fast path), else the legacy install
#   2. a self-heal install of `latest` (staged, see below), once
#   3. `npx` on latest (last resort, network)
#
# UPGRADES. A hook invoked as `hook.sh --session-start [scope...]` (only the
# sessionStart entries pass the flag) compares the installed version with
# HARNESS_MIN using shell builtins only — no process, no network. Current or
# newer: nothing else happens. Older: the new release is installed into a
# STAGING directory (`bun add` in versions/.stage-<pid>), checked (version and
# `bin.mjs --version`), moved to versions/<ver>, and only then made live by
# renaming a temp file over `current` — one atomic rename(2). The running tree
# is never modified in place and the previous version is never deleted during
# the switch, so a guard that starts, or is already running and lazily imports
# a chunk, never sees a half-replaced install. (An in-place `bun update` leaves
# bin.mjs and the hashed chunks absent for a few ms: measured, it crashes
# concurrent hooks.) Old versions are pruned only after a successful switch,
# keeping the new one, the previous one, and anything younger than ~2 days.
#
# Failure handling: a back-off stamp (.harness-update-failed) suppresses retries
# for FUSE_HARNESS_UPDATE_BACKOFF_MIN minutes (default 30); it is written before
# the attempt and removed on success, so a killed attempt is also backed off. An
# atomic mkdir lock (.harness-update.lock, reclaimed after 10 min) keeps the five
# sessionStart hooks from installing at once. Everything fails open.
#
# HARNESS_MIN is the only per-release edit.
#
# Resolution is relative to THIS file, never to the caller's cwd. Always exits 0
# on its own failures: Cursor fails hooks open, and a broken guard must never
# block the user's action.
#
# Usage (from hooks/hooks.json): ./scripts/hook.sh [--session-start] [scope...]
#        ./scripts/hook.sh --harness-check     (sessionStart of plugins that must not
#                                               run the bin there: same check/upgrade,
#                                               then exit 0, empty stdout)
#        ./scripts/hook.sh --install-harness   (installer: staged install, then exit;
#                                               prints one warning line on failure)
# The install is bounded by FUSE_HARNESS_INSTALL_TIMEOUT_SEC (default 45, under
# Cursor's 60 s default hook timeout); sessionStart entries that can upgrade
# therefore carry no timeout below 60.

HARNESS_MIN="0.1.115"
HARNESS_SPEC="latest"
CONTROL_ROOT="${FUSE_HARNESS_ROOT:-${HOME}/.cursor/.fusengine-global}"
PKG_REL="node_modules/@fusengine/harness"
BIN_REL="node_modules/@fusengine/harness/dist/cli/bin.mjs"
STAMP="${CONTROL_ROOT}/.selfheal-attempted"
FAILED="${CONTROL_ROOT}/.harness-update-failed"
LOCK="${CONTROL_ROOT}/.harness-update.lock"

MODE=""
case "$1" in
  --session-start) MODE=session; shift ;;
  --install-harness) MODE=install; shift ;;
  --harness-check) MODE=check; shift ;;
esac

BIN=""
INSTALLED=""

# Set INSTALLED to the "version" of a package.json, builtins only. Empty if absent.
pkgver() {
  INSTALLED=""
  [ -r "$1" ] || return 1
  while IFS= read -r _l || [ -n "$_l" ]; do
    case $_l in
      *'"version"'*:*)
        _l=${_l#*'"version"'}; _l=${_l#*:}; _l=${_l#*\"}
        INSTALLED=${_l%%\"*}; return 0 ;;
    esac
  done < "$1"
  return 1
}

# ver_ge A B: numeric A >= B for x.y.z (prerelease/build suffix ignored).
ver_ge() {
  _a=${1%%[-+]*}; _b=${2%%[-+]*}
  case $_a in ''|*[!0-9.]*) return 1 ;; esac
  case $_b in ''|*[!0-9.]*) return 1 ;; esac
  _o=$IFS; IFS=.
  set -- $_a; _a1=${1:-0}; _a2=${2:-0}; _a3=${3:-0}
  set -- $_b; _b1=${1:-0}; _b2=${2:-0}; _b3=${3:-0}
  IFS=$_o
  [ "$_a1" -gt "$_b1" ] && return 0; [ "$_a1" -lt "$_b1" ] && return 1
  [ "$_a2" -gt "$_b2" ] && return 0; [ "$_a2" -lt "$_b2" ] && return 1
  [ "$_a3" -ge "$_b3" ]
}

# Set BIN to the live bin ("" if none) and INSTALLED to its version ("" if unreadable).
resolve_bin() {
  BIN=""; INSTALLED=""
  if [ -r "${CONTROL_ROOT}/current" ]; then
    _c=""
    read -r _c < "${CONTROL_ROOT}/current" || :
    case $_c in ''|.*|*[!0-9A-Za-z.+-]*) _c="" ;; esac
    if [ -n "$_c" ] && [ -f "${CONTROL_ROOT}/versions/${_c}/${BIN_REL}" ]; then
      BIN="${CONTROL_ROOT}/versions/${_c}/${BIN_REL}"; INSTALLED=$_c; return 0
    fi
  fi
  if [ -f "${CONTROL_ROOT}/${BIN_REL}" ]; then
    BIN="${CONTROL_ROOT}/${BIN_REL}"
    pkgver "${CONTROL_ROOT}/${PKG_REL}/package.json" || INSTALLED=""
  fi
}

# Run `$@` with a time bound, portably (stock macOS has no `timeout`): the command
# runs in the background, a watchdog subshell kills it after the limit, `wait`
# returns its status (non-zero when killed). The watchdog's own `sleep` may
# linger until its deadline; it holds no output.
bounded() {
  _t=${FUSE_HARNESS_INSTALL_TIMEOUT_SEC:-45}; case $_t in ''|*[!0-9]*) _t=45 ;; esac
  "$@" &
  _p=$!
  ( sleep "$_t"; kill "$_p" ) >/dev/null 2>&1 &
  _wd=$!
  wait "$_p"; _r=$?
  kill "$_wd" >/dev/null 2>&1
  return "$_r"
}

run_bin() {
  if command -v bun >/dev/null 2>&1; then exec bun "$BIN" hook cursor "$@"; fi
  exec node "$BIN" hook cursor "$@"
}

# Run `<bin> --version` of a candidate bin: proves it starts before it goes live.
bin_answers() {
  if command -v bun >/dev/null 2>&1; then bun "$1" --version >/dev/null 2>&1 </dev/null; return $?; fi
  node "$1" --version >/dev/null 2>&1 </dev/null
}

# Single-flight: atomic mkdir; a lock older than 10 minutes is reclaimed.
take_lock() {
  mkdir "$LOCK" 2>/dev/null && return 0
  [ -d "$LOCK" ] || return 1
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ] || return 1
  # Reclaim through a second atomic gate so only ONE reclaimer runs the
  # check-remove-recreate sequence (two of them would delete each other's lock).
  if ! mkdir "${LOCK}.reclaim" 2>/dev/null; then
    [ -n "$(find "${LOCK}.reclaim" -maxdepth 0 -mmin +10 2>/dev/null)" ] && rmdir "${LOCK}.reclaim" 2>/dev/null
    return 1
  fi
  _got=1
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null && mkdir "$LOCK" 2>/dev/null && _got=0
  fi
  rmdir "${LOCK}.reclaim" 2>/dev/null
  return "$_got"
}

# Wait (bounded) while another process holds the lock.
wait_lock() {
  _w=${FUSE_HARNESS_LOCK_WAIT_SEC:-20}; case $_w in ''|*[!0-9]*) _w=20 ;; esac
  _i=0
  while [ -d "$LOCK" ] && [ "$_i" -lt "$_w" ]; do sleep 1; _i=$((_i + 1)); done
}

# Staged install of HARNESS_SPEC. Sets NEWV. Returns 0 only when `current` was
# switched to NEWV; the live tree is untouched on any failure. Caller holds LOCK.
install_swap() {
  NEWV=""
  command -v bun >/dev/null 2>&1 || return 1
  mkdir -p "${CONTROL_ROOT}/versions" 2>/dev/null || return 1
  _stage="${CONTROL_ROOT}/versions/.stage-$$"
  trap 'rm -rf "$_stage"; rmdir "$LOCK" 2>/dev/null; exit 0' HUP INT TERM
  rm -rf "$_stage"
  mkdir "$_stage" 2>/dev/null || return 1
  printf '{"name":"@fusengine/cursor-harness-stage","private":true}\n' > "${_stage}/package.json"
  (cd "$_stage" && bounded bun add "@fusengine/harness@${HARNESS_SPEC}" --force --silent) \
    >/dev/null 2>&1 </dev/null || { rm -rf "$_stage"; return 1; }
  pkgver "${_stage}/${PKG_REL}/package.json"; NEWV=$INSTALLED
  case $NEWV in ''|.*|*[!0-9A-Za-z.+-]*) rm -rf "$_stage"; NEWV=""; return 1 ;; esac
  bin_answers "${_stage}/${BIN_REL}" || { rm -rf "$_stage"; return 1; }
  _dest="${CONTROL_ROOT}/versions/${NEWV}"
  if [ -e "$_dest" ] && bin_answers "${_dest}/${BIN_REL}"; then
    rm -rf "$_stage"
  else
    # Absent, or present but broken: the verified stage replaces it (the broken
    # tree is renamed aside and pruned later, never deleted here).
    if [ -e "$_dest" ]; then mv "$_dest" "${_dest}.broken.$$" 2>/dev/null || { rm -rf "$_stage"; return 1; }; fi
    mv "$_stage" "$_dest" 2>/dev/null || { rm -rf "$_stage"; return 1; }
    rm -rf "${_dest}/.stage-$$"   # mv nests the stage if $_dest appeared meanwhile
    bin_answers "${_dest}/${BIN_REL}" || return 1
  fi
  # Never downgrade: keep the live version when it is already newer.
  resolve_bin
  if [ -n "$INSTALLED" ] && ! ver_ge "$NEWV" "$INSTALLED"; then return 1; fi
  PREV=$INSTALLED
  printf '%s\n' "$NEWV" > "${CONTROL_ROOT}/current.tmp.$$" 2>/dev/null \
    && mv -f "${CONTROL_ROOT}/current.tmp.$$" "${CONTROL_ROOT}/current" 2>/dev/null \
    || { rm -f "${CONTROL_ROOT}/current.tmp.$$"; return 1; }
  # mv into a `current` that is a directory succeeds silently: verify the pointer.
  _c=""; read -r _c < "${CONTROL_ROOT}/current" 2>/dev/null
  if [ "$_c" != "$NEWV" ]; then rm -f "${CONTROL_ROOT}/current/current.tmp.$$"; return 1; fi
  trap - HUP INT TERM
  prune_versions
  return 0
}

# Remove versions other than the new and previous one, and stale staging dirs,
# when older than ~2 days (`find -mtime +1`; a long-lived session may still hold an older tree).
prune_versions() {
  for _d in "${CONTROL_ROOT}"/versions/* "${CONTROL_ROOT}"/versions/.stage-*; do
    [ -d "$_d" ] || continue
    _n=${_d##*/}
    [ "$_n" = "$NEWV" ] || [ "$_n" = "$PREV" ] && continue
    [ -n "$(find "$_d" -maxdepth 0 -mtime +1 2>/dev/null)" ] && rm -rf "$_d"
  done
}

# Session-start upgrade: back-off, single flight, staged install.
upgrade_stale() {
  if [ -e "$FAILED" ]; then
    _bo=${FUSE_HARNESS_UPDATE_BACKOFF_MIN:-30}; case $_bo in ''|*[!0-9]*) _bo=30 ;; esac
    [ -n "$(find "$FAILED" -mmin "-${_bo}" 2>/dev/null)" ] && return 0
  fi
  take_lock || return 0
  # `true`, not `:` — a redirection error on a special built-in exits sh/dash.
  true 2>/dev/null > "$FAILED"
  _from=$INSTALLED
  if install_swap && ver_ge "$NEWV" "$HARNESS_MIN"; then rm -f "$FAILED"
  else warn_failed "$_from" "${_bo:-30}"; fi
  trap - HUP INT TERM
  rmdir "$LOCK" 2>/dev/null
  return 0
}

# One line on stderr (stdout is the hook's JSON), shown in Cursor's Hooks panel;
# the back-off stamp keeps it to one per window.
warn_failed() { # installed-version retry-minutes ("-" = no automatic retry, installer path)
  _rt="retry in $2 min"; [ "$2" = "-" ] && _rt="re-run the installer to retry"
  printf 'fusengine harness: upgrade failed (installed %s, target >= %s, staged %s); keeping the installed version, %s\n' \
    "${1:-unknown}" "$HARNESS_MIN" "${NEWV:-none}" "$_rt" >&2
}

# --install-harness: installer entry. Staged install, bypassing back-off.
if [ "$MODE" = install ]; then
  mkdir -p "$CONTROL_ROOT" 2>/dev/null || exit 1
  resolve_bin; _from=$INSTALLED
  wait_lock
  take_lock || { warn_failed "$_from" "-"; exit 1; }
  install_swap; _rc=$?
  trap - HUP INT TERM
  rmdir "$LOCK" 2>/dev/null
  [ "$_rc" -eq 0 ] || warn_failed "$_from" "-"
  exit "$_rc"
fi

resolve_bin

# --harness-check: the sessionStart entry of plugins that must NOT run the bin
# there. Same version check and upgrade as --session-start, then exit 0 with
# empty stdout; the bin is never executed.
if [ "$MODE" = check ]; then
  if [ -n "$BIN" ] && { [ -z "$INSTALLED" ] || ! ver_ge "$INSTALLED" "$HARNESS_MIN"; }; then
    upgrade_stale
  fi
  exit 0
fi

# 1. Fast path: already vendored. Session start checks the version first.
if [ -n "$BIN" ]; then
  if [ "$MODE" = session ] && { [ -z "$INSTALLED" ] || ! ver_ge "$INSTALLED" "$HARNESS_MIN"; }; then
    upgrade_stale
    resolve_bin
  fi
  run_bin "$@"
fi

# 2. Self-heal once (staged, same routine). An install in flight is awaited; the
#    stamp keeps 62 hooks from stampeding the registry when it is impossible.
wait_lock
resolve_bin
[ -n "$BIN" ] && run_bin "$@"
if [ ! -e "$STAMP" ] && command -v bun >/dev/null 2>&1; then
  mkdir -p "$CONTROL_ROOT" 2>/dev/null && true 2>/dev/null > "$STAMP"
  if take_lock; then
    install_swap
    trap - HUP INT TERM
    rmdir "$LOCK" 2>/dev/null
  fi
  resolve_bin
  [ -n "$BIN" ] && run_bin "$@"
fi

# 3. Last resort: npx on the latest published release.
command -v npx >/dev/null 2>&1 || exit 0
exec npx -y "@fusengine/harness@${HARNESS_SPEC}" hook cursor "$@"
