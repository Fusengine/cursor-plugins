# fuse-ai-pilot (Cursor Plugin)

AI Pilot workflow: APEX methodology (auto-detects Laravel/Next.js/React/Swift), sniper (7-phase
code quality + DRY detection), research-expert, explore-codebase.

Ported from the Claude Code plugin `fuse-ai-pilot` v1.2.39. The plugin name is deliberately
identical across both ecosystems so cross-plugin references (`fuse-ai-pilot:<skill>`) keep
resolving.

## Contents

| Component | Count | Cursor discovery |
| :-- | :-- | :-- |
| Agents (subagents) | 9 | `agents/*.md` |
| Skills | 19 | `skills/<name>/SKILL.md` |
| Commands | 12 | `commands/*.md` |
| Hooks | 5 events | `hooks/hooks.json` |
| Docs | 1 | `docs/*.md` — content, not a Cursor component |

`docs/cache-formats.md` is ported verbatim from the source plugin (R20c). It documents the JSON
envelope, TTL policy, LRU eviction and size limits of the `.harness/cache/*.json` files the skills
read and write. Cursor does not discover it; it is reference material for whoever maintains the
cache, and dropping it would have been a silent content loss.

## Configuration

No `variables` are declared; the plugin needs no secrets. Hooks shell out to
`npx -y @fusengine/harness`, so Node's `npx` must be on `PATH`.

## Port notes (read before editing)

### Agents

Cursor's subagent frontmatter is limited to `name`, `description`, `model`, `readonly`,
`is_background` (cursor.com/docs/subagents, "Configuration fields"). Consequences:

- **`tools:` is kept in the frontmatter, unchanged.** The 5-field table in Cursor's docs is
  incomplete. The internal protobuf `agent.v1.CustomSubagent` carries
  `1 full_path · 2 name · 3 description · 4 tools (repeated) · 5 model · 6 prompt ·
  7 permission_mode · 8 is_background · 9 plugin · 10 marketplace · 11 plugin_id ·
  12 marketplace_id · 13 force_default_model · 14 source`. `tools` is a first-class repeated field,
  and `full_path` + `prompt` confirm this is the model for local `.md` files. The
  `## Allowed tools` block at the top of each body is kept **in addition**, not instead: the field
  exists in the data model, but nothing proves the YAML frontmatter parser populates it from a
  local `.md`, nor that it is enforced as a hard restriction at runtime. Keeping both costs a few
  lines and covers either outcome.
- **`model:` is `grok-4.6` on all 9 agents** — no `inherit`, no `sonnet`; `claude-opus-*` stays
  barred by policy. The ID is verified in the binary: `{modelId:"grok-4.6",
  parameters:[{id:"effort",value:"medium"}, {id:"fast",value:"false"}],
  legacyModelName:"cursor-grok-4.6-medium", displayName:"Cursor Grok 4.6 Medium"}`. Because
  `medium` is already the model's default effort, the bare `grok-4.6` is written — `[effort=medium]`
  would be redundant.
- **The doctrine behind that uniformity: the lead is the architect, the sub-agents are the
  executants.** The lead designs and decomposes at high effort; a sub-agent applies a mandate that
  was already reasoned through in the brief, so paying for that reasoning a second time buys
  nothing. Medium effort is therefore the right default for an executant.
- **Two agents are not executants but organs of control, and carry
  `model: grok-4.6[effort=high]`: `challenger` and `sniper`.** Their function is to contradict the
  lead and find what it missed; a controller less capable than the designer validates by default,
  which annuls its reason for existing. `sniper-faster` stays at the default effort on purpose — it
  is the fast variant, applying fixes that have already been identified, not searching for them.
  The `id[param=value]` syntax is documented (`cursor.com/docs/subagents`, "Model parameters"), and
  `effort` is a parameter `grok-4.6` actually declares in the binary.
- **`permission_mode` is an enum, not a boolean.** `agent.v1.CustomSubagentPermissionMode` has
  `UNSPECIFIED | DEFAULT | READONLY | AGENT_ONLY`. The frontmatter `readonly: true` is a boolean
  projection onto it. `AGENT_ONLY` is undocumented and unused here.
- **`readonly: true` on `explore-codebase` only.** Rule: set it when the source `tools:` contains
  neither `Write` nor `Edit` **and** no `mcp__*` tool. `explore-codebase` (`Read, Glob, Grep, Bash`)
  is the only agent in this plugin that qualifies — in Claude Code it structurally could not write,
  and `readonly` reproduces that at runtime. The MCP half of the condition is not caution for its
  own sake: `readonly`×MCP is undocumented, and an agent that silently lost MCP would stop behaving
  like its Claude Code counterpart.
- **`color:` and `skills:` are kept as-is.** Absence from the docs proves nothing (see R19), but
  `color` is the one key whose absence is *confirmed* in the `agent.v1.CustomSubagent` message —
  it has no field there. `skills` was not checked against the binary. Both are harmless to keep.
- `skills:` values use Claude Code's plugin-qualified form (`fuse-ai-pilot:fuse-browser-usage`,
  `fuse-commit-pro:git-flow`). Cursor identifies skills by bare folder name; whether the qualified
  form resolves is unverified.

### Skills

All 19 satisfy Cursor's hard rule that `name:` equals the parent folder name. `references/`,
`steps/` and nested per-stack folders are natively supported and were copied verbatim.

`user-invocable` was **not** translated to `disable-model-invocation`. They are not inverses:
Cursor's `disable-model-invocation: true` means "only reachable via `/skill-name`, the agent will
never auto-apply it", whereas Claude Code's `user-invocable: false` means "the user cannot type
`/skill`, but the model may still auto-invoke". Mapping one to the other would have inverted the
intent of 15 skills. Both keys are kept as-is.

Keys preserved across the skills — absent from the docs, **not verified against the binary**, so
their status is unknown rather than unsupported (R19): `user-invocable` (16), `argument-hint` (11),
`references` (6), `related-skills` (6), `context` (4), `agent` (4), `versions` (2), `keywords` (2).

One exception: `hooks` appeared in 1 skill (`apex-methodology`) and was **not** preserved — see below.

`skills/apex-methodology/SKILL.md` carried an embedded `hooks:` block (Claude Code nested format,
`PostToolUse` + `Edit`/`Write` matchers) that echoed a `{"decision":"block"}` payload to force a
sniper pass after every write. **It was removed, not rewritten.**

Reason: `hooks` is not a field in Cursor's skill frontmatter schema at all — the documented set is
`name`, `description`, `paths`, `disable-model-invocation`, `icon`, `color`, `metadata`. No amount
of reformatting makes that block execute. Translating it into Cursor's flat shape would have
produced code that looks live and is not, which is worse than deleting it. The payload schema also
differs (`{"decision":"block"}` vs Cursor's `permission: deny` / exit code 2), and collapsing
`Edit` and `Write` into Cursor's single `Write` matcher would have merged its two distinct messages.

The intended behaviour has a plugin-level structural replacement: `hooks/hooks.json` carries a
`postToolUse` / `Write` entry, and the source manifest delegates APEX gate enforcement to the
harness via `core-guards`. Actual Cursor hook execution and reminder delivery remain
runtime-unverified with the unpinned harness and without an authentic lifecycle replay. The skill's
objective paragraph was corrected so it no longer claims an enforcement mechanism it does not own.
If a skill-scoped gate is wanted back, it belongs in `hooks/hooks.json` — with the caveat that the
plugin-level entry has no skill-loaded scope, whereas the Claude Code skill-level hook fired only
while the skill was loaded. The mandatory sniper workflow remains an instruction-level requirement
independent of automatic hook delivery.

### Commands

Cursor documents exactly two command frontmatter fields: `name` and `description`
(cursor.com/docs/reference/plugins, "Command frontmatter fields"). None of the 12 commands declares
`name`; Cursor derives it from the filename, which yields the intended identifiers.

Kept: `disable-model-invocation` (6 files — documented for skills only) and `argument-hint`
(2 files). `argument_hint` exists at protobuf level (`aiserver.v1.GlobalCommand` field 5), so the
concept is native; the exact casing expected in local frontmatter could not be confirmed (the YAML
parser was not located). Kept as `argument-hint`, casing unconfirmed.

**`$ARGUMENTS` is supported — confirmed, not a risk.** The substitution function `qxo(e,t)` in the
Cursor bundle is applied to file content loaded via `_cursorCommandsService.getCommand()` with `.md`
extension matching:

- `$ARGUMENTS` → the raw argument text (empty string when no arguments are passed);
- `$1`, `$2`, … → substituted positionally;
- **undocumented behaviour worth knowing**: if the body contains *no* placeholder at all but the
  user passes arguments, Cursor **appends** `\n\n<args>` to the end of the content.

All 10 argument-consuming commands work, `run-tasks` included. The append behaviour is the one
surprise: `cleanup-context` and `prisma-optimize` have no placeholder, so invoking either with
arguments will silently tack them onto the end of the prompt.

### Hooks

Rewritten from Claude Code's nested shape to Cursor's flat shape.

| Claude Code | Cursor | Matcher before | Matcher after |
| :-- | :-- | :-- | :-- |
| `SubagentStart` | `subagentStart` | `""` | *omitted* |
| `SubagentStop` | `subagentStop` | `""` | *omitted* |
| `SessionEnd` | `sessionEnd` | `""` | *omitted* |
| `PreToolUse` | `preToolUse` | `Task` | `Task` |
| `PostToolUse` | `postToolUse` | `TaskCreate\|TaskUpdate\|Write\|Edit` | `Write` |

- `Edit` collapses into Cursor's `Write`; `Write` is unchanged.
- **`TaskCreate` and `TaskUpdate` have no Cursor tool matcher.** They were dropped, so the
  harness's `syncTaskTracking` path no longer has a trigger.
- On `subagentStart`/`subagentStop` the matcher filters by *subagent type*, not tool type. The
  source used `""` (match everything); omitting the field is the Cursor-correct way to say that.
- The `_description` keys from the source were removed. They are not schema fields and JSON has no
  comments; their content is reproduced in this file instead.

### Command path

Source: `bun $HOME/.claude/plugins/marketplaces/fusengine-plugins/plugins/node_modules/@fusengine/harness/dist/cli/bin.mjs hook claude-code aipilot`

Target: `npx -y @fusengine/harness hook cursor aipilot`

Two things forced the change. The submission checklist requires that all manifest paths be relative
and valid — `$HOME/...` is absolute — and the path itself points into a Claude Code install tree
that does not exist for a Cursor user. `npx` removes the path dependency entirely. The npm registry
confirms `@fusengine/harness` declares `"bin": {"harness": "dist/cli/bin.mjs"}`; the bin name equals
the package's unscoped name, so `npx -y @fusengine/harness` resolves it directly with no ambiguity.
`hook claude-code` becomes `hook cursor` on every entry.

Harness-side Cursor support is being fixed separately. This wiring is the target state per Cursor's
docs, not a workaround for current harness behaviour.

## Runtime paths

Native APEX instructions use `.cursor/apex/`; harness-owned project caches use
`.harness/cache/`. Documented compatibility inputs under `.claude/settings.json`,
`.claude/skills/`, and `.claude/agents/` remain unchanged where Cursor intentionally consumes
them. Executable Claude marketplace paths are not compatibility inputs and were removed or made
explicitly non-executable.

The hook manifests are structurally ported, but runtime parity is not claimed while the published
`@fusengine/harness@0.1.90` tarball differs from the corrected local source contracts. The harness
repair is isolated in `../docs/harness-cursor-fix-prompt.md`.

## Not portable

- Claude Code's `Notification` and `PermissionRequest` events are `NOT PORTABLE`, proven in the
  binary: Cursor's compatibility table maps both to `null` and lists them as "not supported in
  Cursor and will be ignored" (R12). This plugin uses neither, so nothing is lost here.
- `Glob` is the only tool matcher with no Cursor equivalent (mapped to `null` in the binary).
  `WebFetch` and `WebSearch`, which the public docs omitted, **are** supported and map to
  themselves (R13). None appeared in this plugin's hook matchers.
- `"type": "prompt"` hooks are **not** a loss — Cursor supports them natively as
  `{type: "prompt", prompt: "…", timeout: N}`, returning `{ok, reason?}`. This plugin has none, but
  `core-guards` does, and they port directly.

## Install locally

Clone the repository and point Cursor at the plugin directory, or install the whole repository as a
marketplace via its root `.cursor-plugin/marketplace.json`.
