#!/usr/bin/env bash
#
# fusengine-plugins (Cursor) — verifier.
#
# Answers one binary question: is this marketplace installable and installed?
# Every check prints PASS or FAIL. One FAIL anywhere => exit code 1.
#
# What it CANNOT decide is not hidden: the four runtime questions that only
# Cursor itself can answer are printed at the end as an explicit checklist,
# with where to look and what counts as a pass.
#
# Read-only: this script never writes anything outside a temp file it deletes.
#
# Usage: ./verify.sh [--repository-only]
#
set -uo pipefail   # deliberately NOT -e: every check must run, even after a failure

REPOSITORY_ONLY=false
case "${1:-}" in
  "") ;;
  --repository-only) REPOSITORY_ONLY=true ;;
  *) printf 'Usage: %s [--repository-only]\n' "$0" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOCAL_DIR="$HOME/.cursor/plugins/local"
MARKETPLACE="$ROOT/.cursor-plugin/marketplace.json"
EXPECTED_PLUGINS=26
SOLID_MAX_LINES="${FUSE_SOLID_MAX_LINES:-200}"

PASS_N=0
FAIL_N=0
WARN_N=0

pass() { PASS_N=$((PASS_N + 1)); printf 'PASS  %s\n' "$*"; }
fail() { FAIL_N=$((FAIL_N + 1)); printf 'FAIL  %s\n' "$*"; }
warn() { WARN_N=$((WARN_N + 1)); printf 'WARN  %s\n' "$*"; }
head_() { printf '\n-- %s\n' "$*"; }

printf '== fusengine-plugins verification\n'
printf '   repo: %s\n' "$ROOT"

# --- preconditions -----------------------------------------------------------
head_ "0. Preconditions"
case "$SOLID_MAX_LINES" in
  ''|*[!0-9]*|0)
    fail "FUSE_SOLID_MAX_LINES must be a positive integer, got ${SOLID_MAX_LINES:-<empty>}"
    exit 1
    ;;
  *) pass "FUSE_SOLID_MAX_LINES resolved to $SOLID_MAX_LINES" ;;
esac
if [ -f "$MARKETPLACE" ]; then
  pass "marketplace root confirmed (.cursor-plugin/marketplace.json present)"
else
  fail "not a marketplace root — .cursor-plugin/marketplace.json missing. Everything below is void."
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  pass "node available ($(node --version)) — matchers compile in the available Node runtime"
else
  fail "node not found. The manifest checks below need it, and so do the hooks (npx @fusengine/harness)."
  exit 1
fi

# --- static checks (node does the JSON + regex work) -------------------------
NODE_OUT="$(mktemp -t fusengine-verify)"
# shellcheck disable=SC2064
trap "rm -f '$NODE_OUT'" EXIT

FUSE_ROOT="$ROOT" FUSE_EXPECTED="$EXPECTED_PLUGINS" FUSE_SOLID_MAX_LINES="$SOLID_MAX_LINES" node - > "$NODE_OUT" <<'NODEJS'
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = process.env.FUSE_ROOT;
const EXPECTED = Number(process.env.FUSE_EXPECTED);
const SOLID_MAX_LINES = Number(process.env.FUSE_SOLID_MAX_LINES);
const PLUGIN_ROOT_REL = path.join('.cursor-plugin', 'plugins');
const PLUGIN_ROOT = path.join(ROOT, PLUGIN_ROOT_REL);
const lines = [];
const P = (s) => lines.push('PASS\t' + s);
const F = (s) => lines.push('FAIL\t' + s);
const W = (s) => lines.push('WARN\t' + s);
const H = (s) => lines.push('HEAD\t' + s);
const rel = (p) => path.relative(ROOT, p) || '.';

/** Recursively collect files whose basename matches, skipping vcs/build dirs. */
function collect(dir, match, out) {
  out = out || [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === 'node_modules' || e.name === '.git') continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) collect(p, match, out);
    else if (match(e.name)) out.push(p);
  }
  return out;
}

/** Walk every string value of a JSON tree, reporting its JSON pointer. */
function eachString(v, ptr, cb) {
  if (typeof v === 'string') cb(v, ptr);
  else if (Array.isArray(v)) v.forEach((x, i) => eachString(x, ptr + '[' + i + ']', cb));
  else if (v && typeof v === 'object') for (const k of Object.keys(v)) eachString(v[k], ptr + '.' + k, cb);
}

/** Walk every key of a JSON tree. */
function eachKey(v, ptr, cb) {
  if (Array.isArray(v)) v.forEach((x, i) => eachKey(x, ptr + '[' + i + ']', cb));
  else if (v && typeof v === 'object') for (const k of Object.keys(v)) { cb(k, ptr + '.' + k); eachKey(v[k], ptr + '.' + k, cb); }
}

/** Extract the YAML frontmatter block of a markdown file, or ''. */
function frontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  return m ? m[1] : '';
}

// ---------------------------------------------------------------- 1. manifest
H('1. Marketplace manifest and plugin folders');
let mk = null;
const mkPath = path.join(ROOT, '.cursor-plugin', 'marketplace.json');
try {
  mk = JSON.parse(fs.readFileSync(mkPath, 'utf8'));
  P('marketplace.json parses as JSON');
} catch (e) {
  F('marketplace.json does not parse: ' + e.message);
}

let sources = [];
if (mk) {
  const plugins = Array.isArray(mk.plugins) ? mk.plugins : null;
  if (!plugins) {
    F('marketplace.json has no plugins[] array');
  } else {
    if (plugins.length === EXPECTED) P('plugins[] holds exactly ' + EXPECTED + ' entries');
    else F('plugins[] holds ' + plugins.length + ' entries, expected ' + EXPECTED);
    sources = plugins.map((p) => p.source);
  }

  // Bijection entries <-> deterministic marketplace plugin folders.
  const dirs = fs.readdirSync(PLUGIN_ROOT, { withFileTypes: true })
    .filter((e) => e.isDirectory() && fs.existsSync(path.join(PLUGIN_ROOT, e.name, '.cursor-plugin', 'plugin.json')))
    .map((e) => e.name);
  const names = plugins.map((p) => p.name);
  const missing = names.filter((name) => dirs.indexOf(name) === -1);
  const extra = dirs.filter((d) => names.indexOf(d) === -1);
  if (missing.length === 0 && extra.length === 0 && sources.length === dirs.length) {
    P('entries <-> folders is a strict bijection (' + dirs.length + ' each way)');
  } else {
    if (missing.length) F('entries whose source folder does not exist: ' + missing.join(', '));
    if (extra.length) F('plugin folders absent from plugins[]: ' + extra.join(', '));
    if (!missing.length && !extra.length) F('entry/folder counts differ: ' + sources.length + ' vs ' + dirs.length);
  }

  // Each entry: source shape, plugin.json presence, name/version agreement.
  let manifestOk = 0;
  for (const entry of (Array.isArray(mk.plugins) ? mk.plugins : [])) {
    const src = String(entry.source || '');
    const expectedSource = path.join(PLUGIN_ROOT_REL, entry.name);
    if (src !== expectedSource) { F(entry.name + ': source "' + src + '" differs from deterministic path "' + expectedSource + '"'); continue; }
    const pjPath = path.join(ROOT, src, '.cursor-plugin', 'plugin.json');
    if (!fs.existsSync(pjPath)) { F(entry.name + ': missing ' + rel(pjPath)); continue; }
    let pj;
    try { pj = JSON.parse(fs.readFileSync(pjPath, 'utf8')); }
    catch (e) { F(entry.name + ': plugin.json does not parse: ' + e.message); continue; }
    if (pj.name !== entry.name) { F(entry.name + ': plugin.json name is "' + pj.name + '"'); continue; }
    if (pj.version !== entry.version) { F(entry.name + ': version ' + pj.version + ' vs marketplace ' + entry.version); continue; }
    manifestOk++;
  }
  if (manifestOk === (Array.isArray(mk.plugins) ? mk.plugins.length : -1)) {
    P('all ' + manifestOk + ' plugins carry a valid .cursor-plugin/plugin.json with matching name and version');
  }
}

// ------------------------------------------------------------------- 2. hooks
H('2. Hook manifests');
const hookFiles = collect(ROOT, (n) => n === 'hooks.json');
if (hookFiles.length === 0) F('no hooks.json found at all — suspicious for this marketplace');
else P(hookFiles.length + ' hooks.json files found');

let parseOk = 0, versionOk = 0, cleanKeys = 0;
const matchers = [];   // { file, event, matcher }
for (const f of hookFiles) {
  const raw = fs.readFileSync(f, 'utf8');
  let j;
  try { j = JSON.parse(raw); parseOk++; }
  catch (e) { F(rel(f) + ': does not parse: ' + e.message); continue; }

  // "version": 1 — a real JSON integer, not "1" and not 1.0.
  const quoted = /"version"\s*:\s*"/.test(raw);
  const floaty = /"version"\s*:\s*1\.0/.test(raw);
  if (typeof j.version === 'number' && Number.isInteger(j.version) && j.version === 1 && !quoted && !floaty) versionOk++;
  else F(rel(f) + ': "version" must be the integer 1, found ' + JSON.stringify(j.version) + (quoted ? ' (quoted string)' : '') + (floaty ? ' (written as 1.0)' : ''));

  let underscore = null;
  eachKey(j, '$', (k, ptr) => { if (k[0] === '_' && underscore === null) underscore = ptr; });
  if (underscore === null) cleanKeys++;
  else F(rel(f) + ': underscore-prefixed key at ' + underscore + ' (R16 — JSON has no comments)');

  const hooks = j.hooks && typeof j.hooks === 'object' ? j.hooks : {};
  for (const event of Object.keys(hooks)) {
    const arr = Array.isArray(hooks[event]) ? hooks[event] : [];
    for (const h of arr) if (h && typeof h.matcher === 'string') matchers.push({ file: f, event: event, matcher: h.matcher });
  }
}
if (parseOk === hookFiles.length && hookFiles.length) P('all ' + parseOk + ' hooks.json parse');
if (versionOk === hookFiles.length && hookFiles.length) P('all ' + versionOk + ' declare "version": 1 as a JSON integer');
if (cleanKeys === hookFiles.length && hookFiles.length) P('no underscore-prefixed key in any hooks.json');

// ---------------------------------------------------------------- 3. matchers
H('3. Hook matchers');
// A matcher is a regex. An INVALID one is not inert: Cursor catches the error and
// returns true, so a broken matcher silently matches EVERYTHING. Hence a hard FAIL.
let regexOk = 0, mcpOk = 0;
for (const m of matchers) {
  try { new RegExp(m.matcher); regexOk++; }
  catch (e) { F(rel(m.file) + ' [' + m.event + ']: matcher does not compile as a regex: ' + JSON.stringify(m.matcher) + ' — Cursor would match EVERY call'); }
  if (/^mcp__/.test(m.matcher)) F(rel(m.file) + ' [' + m.event + ']: matcher starts with "mcp__" — Cursor syntax is "MCP:<tool>": ' + JSON.stringify(m.matcher));
  else mcpOk++;
  if (m.matcher === '') W(rel(m.file) + ' [' + m.event + ']: empty matcher — R14 says omit the field instead');
}
if (matchers.length === 0) W('no matcher declared anywhere — nothing to compile');
if (matchers.length && regexOk === matchers.length) P('all ' + matchers.length + ' matchers compile as JavaScript regexes');
if (matchers.length && mcpOk === matchers.length) P('no matcher uses the Claude Code "mcp__" prefix');

// ------------------------------------------------------- 4. JSON path hygiene
H('4. JSON hygiene (portability)');
const jsonFiles = collect(ROOT, (n) => n.endsWith('.json'));
const hits = [];
const HOOK_SET = {};
for (const f of hookFiles) HOOK_SET[f] = true;
for (const f of jsonFiles) {
  let j;
  try { j = JSON.parse(fs.readFileSync(f, 'utf8')); }
  catch (e) { F(rel(f) + ': does not parse: ' + e.message); continue; }
  eachString(j, '$', (v, ptr) => {
    if (/(^|[\s"(=:])\/(Users|home|Applications|opt|usr|var|etc|private|tmp)\//.test(v)) hits.push(['absolute path', f, ptr, v]);
    if (/\$HOME|\$\{HOME\}|(^|[\s"(=:])~\//.test(v)) hits.push(['home reference', f, ptr, v]);
    if (/(^|[^\w.])\.\.\//.test(v)) hits.push(['parent traversal', f, ptr, v]);
    if (/claude-code/i.test(v)) hits.push(['claude-code', f, ptr, v]);
  });
  // Underscore keys outside hooks.json are out of R16 scope: reported, not failed.
  if (!HOOK_SET[f]) {
    eachKey(j, '$', (k, ptr) => { if (k[0] === '_') W(rel(f) + ': underscore key ' + ptr + ' (outside R16 scope — hooks manifests only — reported, not a failure)'); });
  }
}
if (hits.length === 0) P('no absolute path, "..", $HOME or "claude-code" in any of the ' + jsonFiles.length + ' JSON files');
for (const h of hits) F(rel(h[1]) + ' ' + h[2] + ': ' + h[0] + ' -> ' + JSON.stringify(h[3].slice(0, 100)));

// ------------------------------------------------------------- 5. model values
H('5. Model identifiers');
// Scope: YAML frontmatter of markdown + string values of JSON. NOT README prose,
// where "claude-opus-*" legitimately appears as the name of a barred policy.
const mdFiles = collect(ROOT, (n) => n.endsWith('.md'));
let opus = 0;
for (const f of mdFiles) {
  const fm = frontmatter(fs.readFileSync(f, 'utf8'));
  if (!fm) continue;
  // [ \t] not \s: \s matches the newline, which would let an empty value swallow the next line.
  const re = /^[ \t]*model[ \t]*:[ \t]*(.+)$/gm;
  let m;
  while ((m = re.exec(fm)) !== null) {
    if (/claude-opus/i.test(m[1])) { opus++; F(rel(f) + ': frontmatter model: ' + m[1].trim()); }
  }
}
for (const f of jsonFiles) {
  let j;
  try { j = JSON.parse(fs.readFileSync(f, 'utf8')); } catch (e) { continue; }
  eachString(j, '$', (v, ptr) => { if (/claude-opus/i.test(v)) { opus++; F(rel(f) + ' ' + ptr + ': claude-opus value'); } });
}
if (opus === 0) P('no claude-opus-* model value in any frontmatter or manifest (' + mdFiles.length + ' md, ' + jsonFiles.length + ' json)');

// -------------------------------------------------------------- 6. skill names
H('6. Skills');
const skills = collect(ROOT, (n) => n === 'SKILL.md');
let named = 0;
for (const f of skills) {
  const fm = frontmatter(fs.readFileSync(f, 'utf8'));
  const m = fm.match(/^[ \t]*name[ \t]*:[ \t]*(.+)$/m);
  const declared = m ? m[1].trim().replace(/^["']|["']$/g, '') : null;
  const folder = path.basename(path.dirname(f));
  if (declared === folder) named++;
  else F(rel(f) + ': name "' + (declared === null ? '<absent>' : declared) + '" != parent folder "' + folder + '" (R9)');
}
if (skills.length && named === skills.length) P('all ' + skills.length + ' skills declare name == parent folder');
if (skills.length === 0) W('no SKILL.md found');

// -------------------------------------------------- 7. global user rule source
H('7. Global user rule (source file in the repo)');
const RULE_REL = path.join(PLUGIN_ROOT_REL, 'fuse-rules', 'user-rules', 'fuse-global.mdc');
const rulePath = path.join(ROOT, RULE_REL);
if (!fs.existsSync(rulePath)) {
  W(RULE_REL + ' is not in the repo — global-rule checks skipped. The marketplace does not depend on it.');
} else {
  const text = fs.readFileSync(rulePath, 'utf8');
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) {
    F(RULE_REL + ': no YAML frontmatter block delimited by --- at the top of the file');
  } else {
    // Shallow YAML check, not a full parser: every non-blank, non-indented,
    // non-list line of the block must be a "key: value" pair.
    const bad = [];
    m[1].split(/\r?\n/).forEach((ln, i) => {
      if (ln.trim() === '' || /^\s/.test(ln) || /^-\s/.test(ln) || /^\s*#/.test(ln)) return;
      if (!/^[A-Za-z0-9_.-]+\s*:/.test(ln)) bad.push('line ' + (i + 1) + ': ' + JSON.stringify(ln.slice(0, 60)));
    });
    if (bad.length) F(RULE_REL + ': frontmatter is not key: value YAML — ' + bad.join('; '));
    else P(RULE_REL + ': frontmatter parses as key: value YAML (shallow check)');

    const always = m[1].match(/^alwaysApply[ \t]*:[ \t]*(.+)$/m);
    if (!always) F(RULE_REL + ': no alwaysApply key — the rule would not be applied globally');
    else if (/^true$/.test(always[1].trim())) P(RULE_REL + ': alwaysApply is the boolean true');
    else F(RULE_REL + ': alwaysApply is ' + JSON.stringify(always[1].trim()) + ' — it must be the boolean true, not a string');

    const desc = m[1].match(/^description[ \t]*:[ \t]*(.+)$/m);
    if (desc && desc[1].trim().replace(/^["']|["']$/g, '') !== '') P(RULE_REL + ': description key present and non-empty');
    else F(RULE_REL + ': description key missing or empty');
  }
}

// -------------------------------------------- 8. Cursor migration contracts
H('8. Cursor migration contracts');
const read = (p) => fs.readFileSync(path.join(ROOT, p), 'utf8');
const filesUnder = (p) => collect(path.join(ROOT, p), (n) => n.endsWith('.md'));

const nativeApexFiles = [
  ...filesUnder(path.join(PLUGIN_ROOT_REL, 'fuse-ai-pilot', 'skills', 'apex-methodology')),
  ...filesUnder(path.join(PLUGIN_ROOT_REL, 'fuse-ai-pilot', 'skills', 'elicitation')),
  ...filesUnder(path.join(PLUGIN_ROOT_REL, 'fuse-ai-pilot', 'skills', 'verification')),
];
const claudeApex = nativeApexFiles.filter((f) => /\.claude\/apex/.test(fs.readFileSync(f, 'utf8')));
if (claudeApex.length === 0) P('native Cursor APEX, elicitation, and verification instructions use .cursor/apex');
else claudeApex.forEach((f) => F(rel(f) + ': native Cursor state still references .claude/apex'));

const cacheDoc = path.join(PLUGIN_ROOT_REL, 'fuse-ai-pilot', 'docs', 'cache-formats.md');
if (!/\.claude\/cache/.test(read(cacheDoc)) && /\.harness\/cache/.test(read(cacheDoc))) {
  P('harness cache documentation uses .harness/cache');
} else {
  F(cacheDoc + ': harness cache documentation must use .harness/cache, not .claude/cache');
}

const nativeCommandFiles = [
  path.join(PLUGIN_ROOT_REL, 'fuse-security', 'commands', 'scan.md'),
  path.join(PLUGIN_ROOT_REL, 'fuse-security', 'skills', 'security-scan', 'SKILL.md'),
  path.join(PLUGIN_ROOT_REL, 'fuse-changelog', 'skills', 'changelog-scan', 'SKILL.md'),
  path.join(PLUGIN_ROOT_REL, 'fuse-cartographer', 'commands', 'map.md'),
  path.join(PLUGIN_ROOT_REL, 'fuse-cartographer', 'skills', 'map-ecosystem', 'SKILL.md'),
  path.join(PLUGIN_ROOT_REL, 'fuse-ai-pilot', 'commands', 'update-harness.md'),
  path.join(PLUGIN_ROOT_REL, 'fuse-ai-pilot', 'commands', 'cleanup-context.md'),
];
const claudeExecutable = /\$\{?CLAUDE_PLUGIN_ROOT\}?|\.claude\/plugins\/marketplaces|~\/\.claude\/scripts/;
let nativeCommandsOk = 0;
for (const f of nativeCommandFiles) {
  if (claudeExecutable.test(read(f))) F(f + ': unresolved Claude-only executable or plugin-root path');
  else nativeCommandsOk++;
}
if (nativeCommandsOk === nativeCommandFiles.length) P('native Cursor commands contain no unresolved Claude-only executable path');

const agentCreatorFiles = collect(
  path.join(PLUGIN_ROOT, 'fuse-ai-pilot', 'skills', 'agent-creator'),
  (n) => /\.(md|mdc|markdown|txt)$/.test(n),
);
const claudeRootGuidance = agentCreatorFiles.filter((f) => /CLAUDE_PLUGIN_ROOT/.test(fs.readFileSync(f, 'utf8')));
if (claudeRootGuidance.length === 0) {
  P('active agent-creator guidance contains no CLAUDE_PLUGIN_ROOT');
} else {
  claudeRootGuidance.forEach((f) => F(rel(f) + ': active Cursor guidance still teaches CLAUDE_PLUGIN_ROOT'));
}

const promptRel = path.join('docs', 'harness-cursor-fix-prompt.md');
const promptPath = path.join(ROOT, promptRel);
const promptText = fs.existsSync(promptPath) ? fs.readFileSync(promptPath, 'utf8') : '';
if (promptText) P(promptRel + ' exists');
else F(promptRel + ': standalone harness repair prompt is missing');

const promptContracts = [
  [/## Implemented in local source[\s\S]*## Remaining implementation/i, 'separates implemented local regressions from remaining implementation'],
  [/beforeReadFile native allow\/deny permission enforcement/i, 'requires native beforeReadFile allow/deny permission enforcement'],
  [/~\/\.fuse-harness\/state\/<project-hash>\/[\s\S]*track-\*\.json/i, 'uses ~/.fuse-harness/state/<project-hash>/ for session tracks'],
  [/\.harness\/track\/solid-notice\.json[\s\S]{0,240}sidecar[\s\S]{0,240}not (?:the )?session (?:tracking )?root/i, 'preserves solid-notice.json as a sidecar, not the session root'],
  [/source \+ clean dist \+ local packed-tarball parity/i, 'requires source + clean dist + local packed-tarball parity'],
  [/version >0\.1\.90[\s\S]{0,240}(?:publishing|pinning|publish|pin)/i, 'requires a version above 0.1.90 before publishing or pinning'],
  [/event,\s*matcher,\s*command,\s*timeout,\s*and any direct prompt hook/i, 'enumerates every hook-manifest trigger/configuration field'],
  [/hook manifests are trigger and configuration surfaces[\s\S]{0,400}62 command entries live[\s\S]{0,300}stdin normalization[\s\S]{0,200}exit\s+status `2`/i, 'preserves the hook-manifest versus harness-mechanics boundary'],
];
for (const contract of promptContracts) {
  if (contract[0].test(promptText)) P('harness prompt ' + contract[1]);
  else F(promptRel + ': prompt violates contract — it must ' + contract[1].replace(/s\b/, ''));
}
const ownerCorrections = [
  'tu regarde comment fonctionne le harness pour adapté',
  'on est d\'accord il ne touche pas au harness si il veulent faire des correction il me donne le prompt',
  'on a notre harness corriger sur l\'ordinateur tu peux regarder mais pas toucher',
  'les mécaniques sont dans les hooks',
];
const taskRel = path.join('.codex', 'apex', 'docs', 'task-task-1788018121.md');
const taskText = read(taskRel);
if (ownerCorrections.every((correction) => promptText.includes(correction))) P('harness prompt preserves all four owner corrections verbatim');
else F(promptRel + ': prompt must preserve all four owner corrections verbatim');
if (ownerCorrections.every((correction) => taskText.includes(correction))) P('APEX task preserves all four owner corrections verbatim');
else F(taskRel + ': task must preserve all four owner corrections verbatim');
const normalizedPrompt = promptText.replace(/\r\n/g, '\n');
const promptLines = normalizedPrompt === '' ? 0 : normalizedPrompt.split('\n').length - (normalizedPrompt.endsWith('\n') ? 1 : 0);
if (promptLines <= SOLID_MAX_LINES) P('harness prompt stays within FUSE_SOLID_MAX_LINES=' + SOLID_MAX_LINES);
else F(promptRel + ': prompt has ' + promptLines + ' lines, exceeding FUSE_SOLID_MAX_LINES=' + SOLID_MAX_LINES);

const designChecklist = path.join(PLUGIN_ROOT_REL, 'fuse-design', 'skills', 'design-review', 'references', 'pre-flight-checklist.md');
const designText = read(designChecklist);
if (!/cd "\$CLAUDE_PLUGIN_ROOT\/scripts\/layout-check"|bun run layout-check\.ts/.test(designText)) {
  P('missing fuse-design layout-check is not presented as an executable mandatory step');
} else {
  F(designChecklist + ': missing layout-check is still presented as executable and mandatory');
}

const postCommitFiles = filesUnder(path.join(PLUGIN_ROOT_REL, 'fuse-commit-pro', 'skills', 'post-commit'));
const claudeManifest = postCommitFiles.filter((f) => /\.claude-plugin/.test(fs.readFileSync(f, 'utf8')));
if (claudeManifest.length === 0) P('post-commit marketplace instructions use the Cursor manifest layout');
else claudeManifest.forEach((f) => F(rel(f) + ': executable marketplace instructions still use .claude-plugin'));

const projectDetection = read(path.join(PLUGIN_ROOT_REL, 'fuse-rules', 'rules', '01-project-detection.md'));
if (!/~\/\.claude\/agents/.test(projectDetection) && /~\/\.cursor\/agents/.test(projectDetection)) {
  P('native custom-agent discovery uses ~/.cursor/agents');
} else {
  F('fuse-rules/rules/01-project-detection.md: native custom-agent discovery must use ~/.cursor/agents');
}

process.stdout.write(lines.join('\n') + '\n');
NODEJS

node_status=$?
if [ "$node_status" -ne 0 ]; then
  fail "the static checker crashed (node exit $node_status). Output so far:"
  cat "$NODE_OUT"
fi

while IFS=$'\t' read -r status message; do
  case "$status" in
    PASS) pass "$message" ;;
    FAIL) fail "$message" ;;
    WARN) warn "$message" ;;
    HEAD) head_ "$message" ;;
    *)    [ -n "${status:-}" ] && printf '      %s\n' "$status" ;;
  esac
done < "$NODE_OUT"

# --- 9. installation ---------------------------------------------------------
head_ "9. Installation"

if [ "$REPOSITORY_ONLY" = true ]; then
  pass "repository-only mode — installed Cursor configuration checks skipped"
else

# install.sh's deployment engine (.cursor-plugin/scripts/src/services/global-install.ts)
# lays each marketplace plugin out as an immediate flat child of $LOCAL_DIR — it never
# symlinks the repo in. Check that layout instead of a symlink.
if [ ! -d "$LOCAL_DIR" ]; then
  fail "$LOCAL_DIR does not exist — the marketplace is not installed. Run ./install.sh"
elif command -v node >/dev/null 2>&1; then
  missing="$(FUSE_MARKETPLACE="$MARKETPLACE" FUSE_LOCAL="$LOCAL_DIR" node -e '
    const fs = require("fs");
    const path = require("path");
    const market = JSON.parse(fs.readFileSync(process.env.FUSE_MARKETPLACE, "utf8"));
    const missing = market.plugins
      .map((p) => p.name)
      .filter((name) => !fs.existsSync(path.join(process.env.FUSE_LOCAL, name, ".cursor-plugin", "plugin.json")));
    process.stdout.write(missing.join(" "));
  ')"
  if [ -z "$missing" ]; then
    pass "$LOCAL_DIR holds a flat copy of every marketplace plugin"
  else
    fail "$LOCAL_DIR is missing plugin copies: $missing — Run ./install.sh"
  fi
else
  warn "node not on PATH — skipped the flat plugin-copy check under $LOCAL_DIR"
fi

if command -v npx >/dev/null 2>&1; then
  pass "npx on PATH — the hook.sh wrapper can fall back to 'npx -y @fusengine/harness hook cursor'"
else
  fail "npx not on PATH — the hook.sh fallback would fail if the vendored harness is missing"
fi

RULE_SRC="$ROOT/.cursor-plugin/plugins/fuse-rules/user-rules/fuse-global.mdc"
RULE_DST="$HOME/.cursor/rules/fuse-global.mdc"
if [ ! -f "$RULE_SRC" ]; then
  warn "no global rule in the repo ($RULE_SRC) — deployment check skipped, not failed."
elif [ ! -e "$RULE_DST" ]; then
  fail "$RULE_DST is absent — the global rule is not deployed. Run ./install.sh"
elif diff -q "$RULE_SRC" "$RULE_DST" >/dev/null 2>&1; then
  pass "$RULE_DST is identical to the repo copy"
else
  fail "$RULE_DST differs from $RULE_SRC — stale or hand-edited."
  printf '      global-install.ts refuses to overwrite a modified owned rule; run\n'
  printf '      ./install.sh --uninstall then ./install.sh to replace it.\n'
  diff "$RULE_SRC" "$RULE_DST" | head -20 | sed 's/^/      /'
fi
fi

# --- summary -----------------------------------------------------------------
printf '\n== Result: %d PASS, %d FAIL, %d WARN\n' "$PASS_N" "$FAIL_N" "$WARN_N"

# --- what a shell cannot decide ----------------------------------------------
cat <<'CHECKLIST'

== Manual checks — these four cannot be automated from a shell
   No process outside Cursor can read Cursor's plugin registry, its subagent tool
   gate, or its rules panel; they exist only inside the running editor. They are
   listed here so they are not mistaken for "verified".

   [ ] 1. Do all 26 plugins appear in Customize?
          Where: Cursor Settings -> Plugins / Customize, after 'Developer: Reload Window'.
          PASS:  the list shows 26 entries under "fusengine-plugins" (core-guards,
                 fuse-ai-pilot ... fuse-typescript). 25 means one entry was rejected;
                 0 means the marketplace root was not loaded at all.
          If it fails: the JSON is provably well-formed (checks 1-6 above), so look at
          Help -> Toggle Developer Tools -> Console for the load error.

   [ ] 2. Is a subagent's "tools:" frontmatter enforced at runtime?
          Where: open any agent that declares a restricted tool list (e.g.
                 fuse-ai-pilot/agents/explore-codebase.md, which has no Write), invoke it,
                 and ask it to write a file.
          PASS:  the write is DENIED by the runtime, not merely declined by the model.
          Known: the field exists in agent.v1.CustomSubagent and is read by the binary;
                 enforcement as a hard restriction has never been observed. This is why
                 every ported agent also carries an "## Allowed tools" block in its body.
          A refusal that reads like a model choice is NOT a pass — it is inconclusive.

   [ ] 3. Do the 9 fuse-rules rules appear in Settings -> Rules?
          Where: Cursor Settings -> Rules, with the fuse-rules plugin enabled.
          PASS:  the 9 files of fuse-rules/rules/ (00-critical-rules ... 08-subagent-conduct)
                 are listed.
          NOT BLOCKING: the files carry no frontmatter, so native discovery is unproven.
          The plugin's hooks are configured to inject them, but end-to-end lifecycle execution
          remains pending a corrected @fusengine/harness release. Panel absence or presence does
          not prove hook injection.

   [ ] 4. Is the global rule loaded, and always on?
          Where: Cursor Settings -> Rules, User Rules section.
          PASS:  an entry named "fuse-global" is listed AND marked "Always".
          Listed but not Always => alwaysApply did not survive; listed nowhere => the
          rules scanner did not pick the file up. A file present on disk (checked above)
          proves the copy, not the load — only this panel does.
CHECKLIST

if [ "$FAIL_N" -gt 0 ]; then
  printf '\nVERDICT: NOT VERIFIED — %d failing check(s) above.\n' "$FAIL_N"
  exit 1
fi
printf '\nVERDICT: every automated check passed. The four manual items above remain open by nature.\n'
exit 0
