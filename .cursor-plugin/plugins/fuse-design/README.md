# fuse-design (Cursor Plugin)

UI/UX design director covering four targets: **marketing websites, web apps, iOS and Android**.
Generates production-ready HTML/CSS directly — Gemini Design MCP, Magic (21st.dev) and shadcn MCP
are optional tools of convenience, never a requirement. Mobile targets never produce SwiftUI or
Compose code: they produce tokens, an HTML device-framed mockup, and a handoff spec for
`swift-expert` or an Android developer.

**Zero tolerance for generic "AI slop" aesthetics** — see the anti-slop clusters in
`skills/design-method/SKILL.md`.

Ported from the Claude Code plugin `fuse-design` v2.3.0 (source folder `plugins/design-expert/`).
The plugin name is deliberately identical across both ecosystems so cross-plugin references
(`fuse-design:<skill>`, and the agent's own `fuse-ai-pilot:fuse-browser-usage`) keep resolving.

Port note 2026-11-14: the source change `fd4f8c5e..a6a25857` was ported for `design-ios` only: six new
references (`app-icons`, `app-store-assets`, `apple-design-tools`, `bars-menus-scroll`,
`generative-ai`, `system-surfaces`) plus the updated `SKILL.md`, `dynamic-type`, `ipados-iphone-duo`,
`macos` and `watch-tv-vision` references, all byte-identical to the source, and the README's
`design-ios` row now reads "Apple-platform mockup + handoff".

## Contents

| Component | Count | Cursor discovery |
| :-- | :-- | :-- |
| Agents (subagents) | 1 | `agents/*.md` |
| Skills | 9 | `skills/<name>/SKILL.md` |
| Commands | 5 | `commands/*.md` |
| Hooks | 4 events | `hooks/hooks.json` |
| Rules | 3 | `rules/*.md` — discovered candidates; plain-`.md` activation runtime-unverified |
| Out-of-corpus reference | 1 set | `_artistic/` — content, not a Cursor component |

**Nine skills, not ten.** The batch brief expected 10; the source `skills/` folder holds 9, and the
source plugin's own README lists exactly those 9. Nothing was dropped in the port — `diff -rq`
against the source `skills/` is clean.

### Method (read this first)

All design work starts in `skills/design-method/SKILL.md`:

1. **Brief** — 4 questions (purpose, tone, constraints, differentiation) before any code.
2. **Signature element** — name the one memorable thing this design will be remembered for.
3. **Two-pass process** — a compact plan, then a critical re-read against the brief, before the
   first line of markup.
4. **Anti-slop clusters** — three named default-AI-look clusters to avoid on sight.
5. **Routing** — which skill runs next, by target (web/webapp/iOS/Android) and scope
   (FULL/PAGE/COMPONENT/MOBILE).

### Skills

| Skill | Covers |
| :-- | :-- |
| `design-method` | The core method above — read first |
| `design-system` | OKLCH tokens, typography, spacing, motion profile, the canonical forbidden-fonts list, the mechanical contrast-check step |
| `design-web` | Marketing sites and landing pages — inspiration browsing (FULL/PAGE scope only), component generation, premium layout patterns, hard layout-discipline rules |
| `design-webapp` | Dashboards, auth, settings, onboarding, data tables, command palettes — density and state coverage over marketing polish |
| `design-ios` | Apple-platform mockup + handoff — Dynamic Type, semantic colors, device viewports, Liquid Glass, touch on Mac, bars/menus/scroll, system surfaces, app icons, App Store assets, generative AI, Apple design tools, SwiftUI-ready spec |
| `design-android` | Android mockup + handoff — Material 3 Expressive type/shape/color scales, window size classes, Compose-ready spec |
| `design-motion` | Motion gated by the `MOTION_INTENSITY` dial — most animation ideas die at the gate; mandatory hover/focus/disabled states and `prefers-reduced-motion` regardless |
| `ux-copy` | Voice/tone, CTAs, error messages, empty states, the copy self-audit (em-dash crutch check, production-tell catalogue) |
| `design-review` | The final gate — deterministic checks (contrast, fonts, colors, em-dash) then a bounded screenshot loop (max 2 fix cycles) |

### Commands

| File | Declared `name` | Purpose |
| :-- | :-- | :-- |
| `commands/design.md` | `design` | Full pipeline (web/webapp), no `design-system.md` yet |
| `commands/design-page.md` | `design-page` | New page/screen, reuses the existing `design-system.md` |
| `commands/design-component.md` | `design-component` | Single component, no browsing |
| `commands/design-mobile.md` | `design-mobile` | Mockup + handoff spec, never app code |
| `commands/audit-design.md` | `design-audit` | Audit only, no generation |

### Rules (`rules/`)

Ported verbatim under R20c. Trimmed on the source side to what isn't already covered by a skill:
reusable component-pattern snippets (`design-rules.md`), the stack-detection →
framework-expert delegation table (`framework-integration.md`), and the optional Gemini Design MCP
quick-reference (`gemini-design.md`).

They are not orphaned prose: `skills/design-system/references/typography.md` links to
`../../../rules/design-rules.md`, so dropping the folder would have broken a live reference from a
ported component. Cursor's plugin reference includes `rules/` in default discovery and accepts
`.md` candidates, while the Rules format documentation focuses on `.mdc` with rule frontmatter.
Native activation of these verbatim plain `.md` files therefore remains runtime-unverified; they
also remain reference material that the skills use directly.

### `_artistic/` — out of corpus, kept

Ported verbatim under R20c (2.8 MB: HTML, CSS, WOFF2 fonts, WebP images). Quoting its own README:

> `elysian/` — a fictional neoclassical maison built from supplied plates. **It is not part of the
> reference corpus** (`skills/design-web/references/refs-design/`) and nothing in the plugin points
> here. […] **This folder is not a source of taste, and never a place to go looking for a
> procedure.**

It is deliberately unreferenced, but it is content, not an artefact: it carries no build output,
no cache, no dated snapshot of a file that exists elsewhere. R20c's default is to port, and the
`_` prefix is not what makes `_archive/` an artefact — being a dated snapshot is.

## Configuration

No `variables` are declared; the plugin needs no secrets. Hooks shell out to
`npx -y @fusengine/harness`, so Node's `npx` must be on `PATH`.

**Gemini Design MCP, Magic and shadcn MCP are optional.** Direct HTML/CSS generation is the default
and the fallback if any of them is unavailable — unchanged from the source.

## Port notes (read before editing)

### Agent

`agents/design-expert.md`, one agent — a thin router that reads `design-method` first, always.

- **`model: opus` → `model: grok-4.6`** (R5). This is the one agent in this batch with a deliberate
  escalation in the source, and the escalation is preserved rather than flattened to `inherit`:
  `claude-opus-*` is barred by policy, and `grok-4.6` is verified in the Cursor binary
  (`modelId:"grok-4.6"`, `displayName:"Cursor Grok 4.6 Medium"`). No `[effort=…]` parameters.
- **No `readonly`** (R6): the source `tools:` carries `Edit`, `Write` and 27 `mcp__*` tools — it
  fails both halves of the condition, and `readonly` would strip the MCP surface the whole design
  pipeline runs on.
- **`tools:` kept verbatim, plus an `## Allowed tools` block** at the top of the body (R4). This is
  the longest such block in the marketplace (37 entries) and the one where it matters most: the
  agent's tool list *is* its capability contract across four MCP servers.
- `color: pink` and `skills:` kept as-is (R7).

### Skills

All 9 satisfy `name:` == parent folder name (R9, verified on disk). `references/`, and the deep
nesting under `design-web/references/` (`premium-patterns/01…10/`, `layouts/navigation/`,
`refs-design/<n>-recode/img/`, `templates/`, `gemini/`) copied verbatim — `diff -rq` against the
source `skills/` is clean, 274 files.

Frontmatter keys kept verbatim on all 9 (R7/R19): `when-to-use`, `related`, `priority`, `keywords`.
Note that **three of those four are not in R7's enumeration** — see "Rules that needed a ruling"
below. None was translated, relocated or dropped; R19's default is keep.

This plugin uses neither `user-invocable` nor an embedded `hooks:` block in any skill, so R8 and
the pilot's skill-level-hook problem do not arise here.

### Commands

Five commands, copied **verbatim** — `diff -rq` against the source `commands/` is clean, bodies
untouched (R10).

- **None of the five contains `$ARGUMENTS`, `$1` or any other placeholder.** The batch brief
  expected `$ARGUMENTS` to be preserved; there is none to preserve. Cursor's substitution function
  `qxo(e,t)` therefore has nothing to substitute, and its documented fallback applies: with no
  placeholder in the body and arguments passed, Cursor **appends** `\n\n<args>` to the end of the
  content. That is how `design-mobile` receives its `ios|android` argument — by append, not by
  substitution. Behaviour is equivalent to Claude Code's; it is worth knowing before someone
  "fixes" it by adding a placeholder.
- `argument-hint: "ios|android <screen description>"` on `design-mobile.md` is kept. The concept is
  native (`argument_hint`, `aiserver.v1.GlobalCommand` field 5) but the casing expected in local
  frontmatter is unconfirmed — same status as the pilot.
- **`commands/audit-design.md` declares `name: design-audit`** — the one file where the declared
  name and the filename disagree. Kept verbatim per R10, but note the consequence: R10's rationale
  is "Cursor derives `name` from the filename — do not add one", and here a `name` was already
  present in the source. Whether the command surfaces as `/audit-design` (filename) or
  `/design-audit` (frontmatter) is **not settled**. The other four agree, so only this one is at
  risk. Flagged rather than edited: correcting it would be a behaviour change the port is not
  entitled to make unilaterally.

### Hooks

Rewritten from Claude Code's nested shape to Cursor's flat shape (R11). This is the most exposed
hook surface in the batch — its `PreToolUse` matcher is the only one that mixes plain tool names
with MCP tool names.

#### R12 — events declared by *this* plugin

| Claude Code event | Cursor event | Status | Consequence |
| :-- | :-- | :-- | :-- |
| `PreToolUse` | `preToolUse` | `MAPPED` | `_Ni` @19775968. Carries `permission`. Matcher tests `tool_name`. |
| `PostToolUse` | `postToolUse` | `MAPPED` | `_Ni`. Carries `additional_context`. Matcher tests `tool_name`. |
| `SubagentStart` | `subagentStart` | `CURSOR-NATIVE ONLY` | In `Wu` @19775205, **absent from `_Ni`**. Declared in a `.claude/settings.json`-shaped file it is silently skipped by `nYg` @19777846. It survives here **only because this is a native `hooks/hooks.json`**. Matcher tests `subagent_type`. |
| `SubagentStop` | `subagentStop` | `MAPPED` | `_Ni`. Carries `followup_message`. Matcher tests `subagent_type` (R14). |
| *(none — split out of `PreToolUse`)* | `beforeMCPExecution` | `CURSOR-NATIVE ONLY` | In `Wu` @19775205, **absent from `_Ni`**. Added by this port, not present in the source: it is the only event whose matcher target is the `` `MCP:${tool_name}` `` form (`aYg` @19779089). Reachable only from this native hooks file. |

Five events, five rows — 100 % coverage. No `UNKNOWN`, no `NOT PORTABLE` event. Four come from
the source; `beforeMCPExecution` is a **split**, not an addition of behaviour — see below.

The native-only subagentStart row is the one not to lose. Its source intent is to initialise the design pipeline state machine and raise the active-design flag. The inspected harness currently excludes Cursor from designLifecycle and expects non-Cursor payload fields, so actual Cursor state/flag activation remains runtime-unverified; compatibility routing would also drop the event.

#### R13 — matchers declared by *this* plugin

Source `PreToolUse` matcher, in full:

```
Write|Edit|mcp__fuse-browser__browser_navigate|mcp__fuse-browser__browser_screenshot|mcp__gemini-design__create_frontend

→  preToolUse          matcher: Write
   beforeMCPExecution  matcher: MCP:(browser_navigate|browser_screenshot|create_frontend)
```

**One source entry becomes two Cursor entries**, on two different events, with the same command.

| Event | Source matcher | Cursor matcher | Status | Consequence |
| :-- | :-- | :-- | :-- | :-- |
| `preToolUse` | `Write` | `Write` | `MAPPED` | `tKu` @19776314. This event tests `tool_name`, so a plain tool name belongs here. |
| `preToolUse` | `Edit` | *(merged into `Write`)* | `MAPPED` | `tKu` maps `Edit → Write`. Two source names collapse to one. Lossless here: both routed to the same command with the same (absent) scope and carried no per-tool message. |
| `beforeMCPExecution` | `mcp__fuse-browser__browser_navigate` | `MCP:browser_navigate` | `MAPPED` | `mcp__<server>__<tool>` → `` `MCP:${tool}` ``. **The `fuse-browser` server segment is lost**: this now matches a `browser_navigate` tool on *any* MCP server. |
| `beforeMCPExecution` | `mcp__fuse-browser__browser_screenshot` | `MCP:browser_screenshot` | `MAPPED` | Same rewrite, same server-segment loss. |
| `beforeMCPExecution` | `mcp__gemini-design__create_frontend` | `MCP:create_frontend` | `MAPPED` | Same. The Gemini generation gate now keys on the tool name alone. |
| `postToolUse` | `""` | *omitted* | — | R14. |
| `subagentStart` | `""` | *omitted* | — | R14, and note the target is `subagent_type`, not a tool name. |
| `subagentStop` | `""` | *omitted* | — | R14, same target. |

No matcher in this plugin is `NOT PORTABLE`. **No `mcp__` string appears in the ported
`hooks.json`** — verified by grep, per R13's hard prohibition.

Every matcher was compiled with `re.compile()` before shipping (R13 trap 1). The alternation
`Write|MCP:browser_navigate|MCP:browser_screenshot|MCP:create_frontend` is valid; `:` is not a
regex metacharacter. The check is not skippable: the runtime tester `cYg` @19779820 wraps
`new RegExp(m).test(t)` in `catch { return !0 }`, so an invalid matcher would silently turn this
narrow guard into a global one.

#### Why the MCP matchers go on `beforeMCPExecution`, not `preToolUse`

The root README left this routing question open. It is settled by a **literal asymmetry inside
`aYg`** (offset 19779200), the one function that decides what a matcher is tested against:

```js
case "beforeMCPExecution": case "afterMCPExecution": {
  const n = t; return n.tool_name ? `MCP:${n.tool_name}` : void 0
}
...
case "preToolUse": case "postToolUse": case "postToolUseFailure":
  return t.tool_name || void 0
```

Only the MCP branch **synthesises** the `MCP:` prefix. The `preToolUse` branch returns `tool_name`
raw. That synthesis is the proof: if `tool_name` were already `MCP:xxx` for an MCP call, building
the string again would be dead code. So a matcher `MCP:browser_navigate` placed on `preToolUse` is
tested against an **unprefixed** name and **never matches** — a dead guard that raises nothing.
`beforeMCPExecution` is the only path where the prefix is guaranteed by construction.

**The compatibility layer disagrees, and is very likely buggy.** `tYg` calls `JQg` (the
`MCP:`-builder) *only* on the `PreToolUse` / `PostToolUse` branch and files the result under
`_Ni[PreToolUse]` = `preToolUse` — i.e. it produces exactly the dead combination above. That
describes automatic translation of a `.claude/settings.json`, **not** the behaviour of a native
`hooks.json`. This port targets the native file, so it follows `aYg`, not `tYg`. Aligned with the
same split applied to `fuse-security` and `fuse-changelog`.

#### The MCP guard degrades silently — structural, not fixable here

The server segment is destroyed by the translation (`mcp__fuse-browser__browser_navigate` →
`MCP:browser_navigate`), which has a consequence worth stating plainly: **the tool enumeration is
non-exhaustive by construction.** Two failure modes follow, and neither raises anything:

- **Too wide** — `MCP:browser_screenshot` now matches a same-named tool on *any* MCP server, not
  just `fuse-browser`.
- **Too narrow, and this is the dangerous one** — any tool added to `fuse-browser` or
  `gemini-design` later simply stops being watched. No error, no warning, no log. The guard does
  not protest, it goes quiet.

The enumeration must therefore be revisited whenever those MCP servers gain tools. A regex such as
`MCP:browser_.*` would widen coverage but is not equivalent to the source and was not substituted
unilaterally.

#### Comment keys removed

`_description` (file + one per entry) and `_version: "5.0.0"` were removed, not renamed (R16).
`_version` is the trap: Cursor's hooks config has a real `version` field that must be a **number**
(`"Config version must be a number"`, positive integer), so de-underscoring `"5.0.0"` would have
written a string into a typed schema field. The `"version": 1` here is a constant written by the
port.

The removed prose, reproduced:

> **File** — Design Expert, full enforcement (SOLID/skill/DRY + design pipeline state machine:
> html-css-only, phase ordering, screenshot/scroll, gemini gating, content checks) via
> `@fusengine/harness`.
> **PreToolUse** — SOLID + design pipeline gates (html-css-only, design-system phase gate, browser
> navigate/scroll, gemini create gate).
> **PostToolUse** — design pipeline transitions (screenshot/scroll/navigate/read → phase advance) +
> design content warnings + generic activity tracking.
> **SubagentStart** — init design pipeline state machine + raise the active-design flag.
> **SubagentStop** — archive design state + clear the active-design flag.

#### Honesty note, carried over from the source

**Source intent: hooks provide state tracking, not phase gating.** The inspected harness contains design-specific state and gate logic, but its `designLifecycle` dispatch currently excludes Cursor, so actual Cursor state tracking and enforcement remain runtime-unverified. The pipeline discipline in `design-method` is followed by convention and verified in `design-review`, not assumed from hook execution. That distinction was true in Claude Code; for Cursor, the matcher table above describes *which hook entries are configured*, not proof of *what executes or blocks*.

### Command path

Source: `bun $HOME/.claude/plugins/marketplaces/fusengine-plugins/plugins/node_modules/@fusengine/harness/dist/cli/bin.mjs hook claude-code`

Target: `npx -y @fusengine/harness hook cursor`

All four entries in this plugin call the harness with **no scope argument**. That absence is
preserved exactly (R15): adding a `design` scope would route a generic dispatcher call into a
plugin-specific one. `$HOME/...` is absolute and points into a Claude Code install tree that does
not exist for a Cursor user; `npx` removes the path dependency. `hook claude-code` becomes
`hook cursor`.

## Runtime paths

This plugin references no `.claude/…` runtime state path — 0 occurrences across all 309 ported
files. The R21 clause is therefore deliberately not reproduced here: it asserts that the bodies of
this plugin's skills, agents and commands reference `.claude/…` files, and on a plugin with zero
occurrences that assertion is false. Nothing for the harness to resolve.

Two neighbouring cases, so the silence is not mistaken for an oversight:

- The hook command's `$HOME/.claude/plugins/marketplaces/…` was an **install** path, not a state
  path, and was rewritten under R15 (see "Command path").
- `skills/design-review/references/pre-flight-checklist.md` now records the missing
  `layout-check` executable and requires browser screenshots and measurements without inventing a
  plugin-root command.

## Not portable

### `scripts/layout-check/` — a functional sub-project, removed (R20b)

**Source path:** `plugins/design-expert/scripts/layout-check/` — 13 TypeScript modules
(`layout-check.ts`, `runner.ts`, `browser.ts`, `report.ts`, `config.ts`, `warnings.ts`,
`warmup.ts`, four `probe-*.ts`, `types.ts`, `page.types.ts`), 8 check modules under `checks/`,
2 HTML fixtures, and its own `README.md`. **None of it is ported.**

**What it did.** It loaded a page in headless Chrome, measured it at several viewport widths, and
emitted a JSON violations report plus an exit code — `0` clean, `1` violations, `2` error. Five
deterministic checks, quoting its README:

| `type` | Predicate |
| :-- | :-- |
| `text-overflow` | `scrollWidth > clientWidth + tolerance`, **or** text ink outside the content box |
| `overlap` | intersecting `getBoundingClientRect()` of two elements with no ancestor/descendant link |
| `cta-wrap` | height > `1.6 × line-height` **and** ≥ 2 text line boxes |
| `contrast` | WCAG ratio on resolved colors, 4.5:1 / 3:1 |
| `document-overflow` | `documentElement.scrollWidth > viewport`, at every width |

Its stated reason to exist, translated from its README: the instructions "look at the screenshot",
"the label fits on one line" are already written in the skills, and an agent can still declare a
section verified while a label wraps. **The script runs outside the model — its verdict cannot be
worked around by declaring compliance.** It resolved `playwright-core` from any ambient install
(local, global, or the one bundled by `@playwright/mcp`) rather than adding a dependency, which is
why it has no `package.json` of its own.

**The five R20b steps, applied.**

1. **Concept it plugs into.** Not a Claude Code UI concept like a status line. It is a Bun CLI that
   the `design-review` skill invokes through the Bash tool at
   `${CLAUDE_PLUGIN_ROOT}/scripts/layout-check`, with a runtime argument (the file or URL under
   review) and a parsed JSON result. The Claude Code concept it depends on is therefore
   **`CLAUDE_PLUGIN_ROOT` being exported into the agent's tool environment** — that variable is
   what makes a plugin-bundled executable addressable at all.
2. **Cursor target concept, checked against the binary (R19), not the docs.**
   `CURSOR_PLUGIN_ROOT` and `CLAUDE_PLUGIN_ROOT` each occur exactly **twice** in
   `workbench.desktop.main.js`, and all four occurrences are inside one function,
   `_executeCommandHookScript`: a textual `${…}` substitution in `t.command`, and two variables set
   on the environment built by `_buildHookEnvironment` — both gated on the hook source being
   `"claude-plugin"`. `pluginRoot` occurs **0** times. **The plugin root is exposed to hook command
   execution and to nothing else** — never to the agent's shell tool.
3. **Target found?** No. The only place a plugin path resolves is a hook command line, and a hook
   is event-triggered with a fixed command: it cannot receive the file argument `design-review`
   computes, and it cannot return the violations JSON that the checklist's step 11 reads. It is a
   different mechanism, not the same one under another name.
4. **Therefore: not ported, and no substitute invented.** No hook, command or agent simulates it.
   Wiring the script onto `preToolUse` or `afterFileEdit` would fire it at the wrong moment on the
   wrong input and would be exactly the "convincing-looking dead code" R18c bars.
5. **Sources removed with the artefacts**, and its own `README.md` with them: a program nothing can
   launch is dead weight, and R20c covers the documentation *of the plugin*, not of a subtree that
   is not ported. What was worth keeping from that README is quoted above.

Also excluded from the same subtree under R20a, and not a documented loss: `scripts/.harness/cache/`
and `scripts/layout-check/.harness/` (cache + track).

**Cursor adaptation.** The checklist no longer presents the removed subproject as executable.
Rendered checks are explicit browser measurements with screenshot evidence. This preserves the
review obligation without fabricating a plugin-root API or a missing tool.

### Everything else

- No `Glob`, `MultiEdit`, `TaskCreate` or `TaskUpdate` matcher appears in this plugin's hooks, so
  none of R13's `NOT PORTABLE` rows costs anything here.
- No `Notification`, `PermissionRequest`, `TeammateIdle`, `TaskCompleted` or `InstructionsLoaded`
  event is declared, so none of R12's `NOT PORTABLE` rows costs anything here.
- The **server segment of the three MCP matchers is lost** (`fuse-browser`, `gemini-design`) — it
  widens the guard today and silently narrows it tomorrow, because the tool list is non-exhaustive
  by construction. See "The MCP guard degrades silently" above; it is the one entry here that needs
  revisiting whenever those MCP servers gain tools.
- Excluded as artefacts, carrying no behaviour (R20a, not documented losses): `.harness/cache/`
  (plugin root, `skills/`, and `skills/design-web/references/refs-design/`),
  `_archive/2026-07-17-rebuild/` (a dated snapshot of skills that still exist), and `.DS_Store`.
- The source plugin's own top-level `README.md` is **not** carried alongside this file: it occupies
  the same path, so it is replaced, and its non-redundant content (method summary, skill table,
  command list, rules note, honesty notes) is folded into the sections above.

## Rules that needed a ruling

Four points where R1–R21 as written did not decide the case. The port took the
fidelity-preserving option each time and records it here rather than silently choosing.

1. **R7's key list reads as enumerative but is not.** This plugin's skills carry `when-to-use`,
   `related` and `priority`, none of which appear in R7's parenthesis. All were kept verbatim under
   R19's default. R7 should be re-worded as "every key not in Cursor's schema", with the list as
   examples.
2. **R10 assumes commands carry no `name`.** `commands/audit-design.md` declares
   `name: design-audit` against a filename of `audit-design`. R10 says "do not add one" — it does
   not say what to do with one that is already there and disagrees. Kept verbatim; which identifier
   wins under Cursor is unverified.
3. **R9 × R20b require reconciliation.** When a functional subproject is removed, executable
   references from copied skills must become an honest non-executable limitation or a verified
   native procedure. The checklist now follows that rule.
4. **R16 names `_description` only.** Elsewhere in the marketplace the same comment appears as a
   plain `description` key. Both were treated as comments here, but the rule's wording covers only
   the underscored spelling. Its companion trap is worth keeping explicit: strip `_`-prefixed keys,
   never de-underscore one into a real field — `_version: "5.0.0"` → `"version": "5.0.0"` would
   write a string into a field Cursor validates as a positive integer.

## Install locally

Clone the repository and point Cursor at this plugin directory, or install the whole repository as
a marketplace via its root `.cursor-plugin/marketplace.json`.
