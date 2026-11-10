# fuse-security (Cursor Plugin)

Security vulnerability detection and remediation: OWASP Top 10, SAST pattern scanning, CVE
research, dependency audit, secrets detection, security headers, auth hardening, and review of
AI-agent configuration (`agentic-security`).

Ported from the Claude Code plugin `fuse-security` v1.0.22 (claude-plugins tag `v1.39.47`). The plugin name is deliberately
identical across both ecosystems so cross-plugin references (`fuse-security:<skill>`) keep
resolving.

## Contents

| Component | Count | Cursor discovery |
| :-- | :-- | :-- |
| Agents (subagents) | 1 | `agents/*.md` |
| Skills | 6 | `skills/<name>/SKILL.md` |
| Commands | 1 | `commands/*.md` |
| Hooks | 3 events | `hooks/hooks.json` |
| Rules | 2 | `rules/*.md` — discovered candidates; plain-`.md` activation runtime-unverified |

`rules/apex-workflow.md` and `rules/security-rules.md` are ported at the same relative path
(R20c); `security-rules.md` is verbatim, `apex-workflow.md` differs only by the harness scan
command (see Commands below). Cursor's plugin reference includes `rules/` in default discovery and accepts `.md`
candidates. The Rules format documentation focuses on `.mdc` files with rule frontmatter, so
native activation of these plain source-identical `.md` files remains runtime-unverified. They
were **not** translated into Cursor's `.cursor/rules/*.mdc` format: that would add different
frontmatter and invent the mapping that R17 and R19 forbid. The harness also intends to resolve
them as source content, as under Claude Code.

## Configuration

No `variables` are declared; the plugin needs no secrets. Hooks shell out to
`npx -y @fusengine/harness`, so Node's `npx` must be on `PATH`. The agent's declared tool surface
includes the `context7`, `exa`, `sequential-thinking` and `fuse-browser` MCP servers, which must be
configured on the Cursor side for CVE research and live probing to work.

## Port notes (read before editing)

### Agents

- **`model: opus` → `model: grok-4.6`** on `security-expert` — the uniform-model doctrine: every
  ported agent runs on `grok-4.6`, whose default effort is `medium`, written bare (`[effort=medium]`
  would be redundant). This agent is an executant, not an organ of control (that role belongs to
  `challenger` and `sniper` in `fuse-ai-pilot`), so it takes no `[effort=high]`. `claude-opus-*`
  remains barred by policy. The source `effort: medium` key is dropped.
- **The agent reports, it never fixes.** The source `tools:` no longer contains `Edit` (its only
  write is the audit report, via `Write`); the port follows it. Remediation is dispatched by the
  caller to the domain expert and `sniper`.
- **No `readonly:`.** R6's condition still fails: the agent keeps `Write` for the report and
  declares 23 `mcp__*` tools.
- **`tools:` follows the source with two Cursor substitutions**: `Agent` → `Task`, and the Claude
  Code-only `SendMessage` is removed. A `## Allowed tools` block mirroring the line is emitted at
  the top of the body **in addition** (R4).
- **`color:` and `skills:` are kept as-is** (R7). `skills:` mixes bare names with one
  plugin-qualified reference, `fuse-ai-pilot:fuse-browser-usage`; whether the qualified form
  resolves under Cursor is unverified.

### Skills

All 6 satisfy Cursor's hard rule that `name:` equals the parent folder name: `agentic-security`,
`auth-audit`, `cve-research`, `dependency-audit`, `security-headers`, `security-scan`.
`references/` and the nested `references/templates/` folders are natively supported and were
copied verbatim (R9).

`agentic-security` audits AI-agent configuration (workspace trust, hooks, MCP servers, prompt
injection, permissions, secrets, CI agents). Its references describe Claude Code facts
(`CLAUDE_PLUGIN_ROOT`, `.claude/` paths, CVE-2025-59536 ...) as **audit knowledge about the
audited target**, so they are kept verbatim and are not Cursor-translated.
`security-scan` runs the harness scanner as `npx -y @fusengine/harness scan <dir>` (see
Commands).

Keys preserved across all 6 skills, absent from Cursor's documented set and **not verified against
the binary**, so unknown rather than unsupported (R19): `argument-hint`, `user-invocable`.

`user-invocable` was **not** translated to `disable-model-invocation` (R8).

### Commands

`commands/scan.md` matches the source except for the harness scan command (see below). It declares no `name`; Cursor derives
`/scan` from the filename. It uses `$ARGUMENTS`, which `qxo(e,t)` substitutes with the raw argument
text — confirmed in the binary — so `/scan --deps-only src/` works as intended.

It keeps `argument-hint` and `disable-model-invocation: false` verbatim (R7 / R19).
`argument_hint` exists at protobuf level (`aiserver.v1.GlobalCommand` field 5), so the concept is
native; the exact casing expected in local frontmatter could not be confirmed.

One body construct does not execute under Cursor and is rewritten. The source tells the model to
run `bun ${CLAUDE_PLUGIN_ROOT}/../node_modules/@fusengine/harness/dist/cli/bin.mjs scan <dir>`.
`${CLAUDE_PLUGIN_ROOT}` **is** substituted by Cursor, but only inside a hook's `command` string and
only when the hook's source is a `claude-plugin` — never inside markdown prose handed to the model.
The port therefore uses `npx -y @fusengine/harness scan <dir>` in `commands/scan.md`,
`skills/security-scan/SKILL.md`, `agents/security-expert.md`, `rules/apex-workflow.md` and
`skills/security-scan/references/templates/scan-report.md`; the first three add the sentence "This standalone CLI verb does not depend on Cursor hook normalization."
(`verify.sh` fails any `${CLAUDE_PLUGIN_ROOT}` in the two native command files).

### Hooks

Rewritten from Claude Code's nested shape to Cursor's flat shape (R11). The source `_description`
keys were stripped (R16); their content is reproduced here:

- `preToolUse`: harness advisory (allow + additionalContext, **non-blocking**) to read a security
  skill before code edits when unread. Ports `check-security-skill.py`.
- `postToolUse` / `afterMCPExecution`: source intent is for the harness to track security-skill
  Reads and Context7/Exa research into the `~/.claude/logs/00-security` state. Actual Cursor
  execution remains runtime-unverified with the unpinned harness and without an authentic hook
  replay. Ports `track-skill-read.py` + `track-mcp-research.py`.

**One source entry became two Cursor entries.** The source `PostToolUse` matcher
`Read|mcp__.*context7|mcp__.*exa` mixes a plain tool name with two MCP regexes, and under Cursor
those two halves live on different events — see the R13 table below.

#### R12 — events declared by this plugin

| Claude Code event | Cursor event | Status | Evidence / consequence |
| :-- | :-- | :-- | :-- |
| `PreToolUse` | `preToolUse` | `MAPPED` | `_Ni` @19775968. Matcher tests `tool_name` (`aYg` @19779089). Carries `permission`. |
| `PostToolUse` | `postToolUse` | `MAPPED` | `_Ni`. Matcher tests `tool_name`. Carries `additional_context`. |
| `PostToolUse` (MCP half) | `afterMCPExecution` | `CURSOR-NATIVE ONLY` | In `Wu` @19775205, **absent from `_Ni`**. Declared in `.claude/settings.json` it would be silently skipped by `nYg` @19777846; here it is statically declared in the plugin's native `hooks/hooks.json`, which preserves native-schema reachability, while actual event delivery remains runtime-unverified. It is the only event whose matcher is tested against `` `MCP:${tool_name}` `` (`aYg`), which is why the MCP half of the source matcher had to move onto it. |

100 % of this plugin's own events. No `UNKNOWN`, no `NOT PORTABLE`, nothing dropped.

#### R13 — tool matchers declared by this plugin

| Source matcher | Cursor matcher | Status | Evidence / consequence |
| :-- | :-- | :-- | :-- |
| `Write` (in `Write\|Edit`) | `Write` | `MAPPED` | `tKu` @19776314 maps it to itself. |
| `Edit` (in `Write\|Edit`) | `Write` | `MAPPED` | `tKu` maps `Edit` → `Write`. **Collapses** with the entry above: `Write\|Edit` becomes the single matcher `Write`. Both source tools shared one command and one message, so nothing had to be merged by hand. |
| `Read` (in `Read\|mcp__.*context7\|mcp__.*exa`) | `Read` | `MAPPED` | `tKu` maps it to itself. Stays on `postToolUse`, whose matcher target is `tool_name`. |
| `mcp__.*context7` | `MCP:(resolve-library-id\|query-docs)` | `MAPPED` | `tKu` / `JQg` @~19776502 rewrite `mcp__<server>__<tool>` into `` `MCP:${tool}` ``, and `aYg` confirms `` `MCP:${tool_name}` `` is the matcher target of the MCP events. **The server segment is lost**, so a matcher written against the *server* (`context7`) cannot survive as-is: it was re-expressed by enumerating the context7 tools this plugin's agent actually declares. See the caveat below. |
| `mcp__.*exa` | `MCP:(web_search_exa\|get_code_context_exa\|deep_researcher_start\|deep_researcher_check)` | `MAPPED` | Same mechanism, same caveat. Enumerated from the four exa tools in the agent's `tools:` list. |

**Caveat on the two MCP rows — read before editing the matcher.** R13 rates the regex forms
`mcp__.*context7` / `mcp__.*exa` as `MAPPED` onto `MCP:<tool>`, but the mapping is not
information-preserving in this direction: those source matchers select on the **server** name, and
the server segment does not exist on the Cursor side. `MCP:.*context7` would match nothing —
context7's tools are named `resolve-library-id` and `query-docs`, neither of which contains the
string "context7" — and the failure would be silent, since a matcher that never fires raises
nothing. Enumerating the tools is the closest faithful expression, and it is **not exhaustive**: if
either MCP server gains a tool, or the agent's `tools:` list grows, the matcher must be extended by
hand or the new tool stops being tracked. The final regex compiles
(`new RegExp("MCP:(resolve-library-id|query-docs|…)")`), verified before shipping.

**Never write `mcp__` as a Cursor matcher.** Neither ported matcher contains it.

| Claude Code | Cursor | Matcher before | Matcher after |
| :-- | :-- | :-- | :-- |
| `PreToolUse` | `preToolUse` | `Write\|Edit` | `Write` |
| `PostToolUse` | `postToolUse` | `Read\|mcp__.*context7\|mcp__.*exa` | `Read` |
| `PostToolUse` | `afterMCPExecution` | *(MCP half of the same matcher)* | `MCP:(resolve-library-id\|query-docs\|web_search_exa\|get_code_context_exa\|deep_researcher_start\|deep_researcher_check)` |

### Command path

Source: `bun $HOME/.claude/plugins/marketplaces/fusengine-plugins/plugins/node_modules/@fusengine/harness/dist/cli/bin.mjs hook claude-code security`

Target: `npx -y @fusengine/harness hook cursor security`

R15. `$HOME/…` is absolute and points into a Claude Code install tree that does not exist for a
Cursor user; `npx` removes the path dependency. The scope argument `security` is preserved exactly
on all three entries.

## Runtime paths

No skill, agent, command or rules file instructs the model to read or write a `.claude/…` state
file of this plugin; nothing to resolve harness-side. The `.claude/…`, `.claude-plugin/` and
`CLAUDE.md` mentions in `agents/security-expert.md`, `commands/scan.md`, `rules/security-rules.md`
and `skills/agentic-security/**` are audit targets (the agent-configuration files that the audit
inspects), kept verbatim, not runtime paths of this plugin. The R21 clause is deliberately not
reproduced here.

The harness's own `~/.claude/logs/00-security` state directory is mentioned nowhere in the ported
content — it appeared only in the source `hooks.json` `_description`, which R16 removed and this
README reproduces above. Where that state actually lands under Cursor is the harness's decision,
not the port's.

The only install-tree path this plugin carried was the hook command's
`$HOME/.claude/plugins/marketplaces/…`, an install path rather than a state path — R15's territory,
rewritten above.

## Not portable

- **Nothing is dropped**: all three events map, all matchers have a row.
- **Degraded, not lost — the two MCP matchers.** Their server segment is gone, so the ported
  matchers are enumerations that must be maintained by hand (see the caveat above). A tool added to
  either MCP server stops being tracked without any error.
- `${CLAUDE_PLUGIN_ROOT}` is not substituted in markdown prose — under Cursor **or** Claude Code —
  so the harness scan command was rewritten to `npx -y @fusengine/harness scan <dir>` (see
  Commands). The remaining `CLAUDE_PLUGIN_ROOT` mentions in
  `skills/agentic-security/references/hooks-plugins.md` are audit knowledge about audited plugins.
- `Glob` and `MultiEdit` are `NOT PORTABLE` matchers (R13), `Notification` and `PermissionRequest`
  are `NOT PORTABLE` events (R12); this plugin uses none of them.
- `rules/*.md` are default-discovery candidates, but native activation of the verbatim plain `.md`
  files remains runtime-unverified; the harness also treats them as source content.

## Install locally

Clone the repository and point Cursor at this plugin directory, or install the whole repository as
a marketplace via its root `.cursor-plugin/marketplace.json`. Node's `npx` must be on `PATH` for
the hooks.
