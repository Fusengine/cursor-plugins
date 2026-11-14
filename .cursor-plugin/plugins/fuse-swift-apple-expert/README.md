# fuse-swift-apple-expert (Cursor Plugin)

Expert Swift 6.4.2 + SwiftUI (Xcode 27.2) for iOS 27.2, macOS 27.2, iPadOS 27.2, watchOS 27.2, visionOS 27.2 and tvOS 27.2 —
Liquid Glass, `@Observable`, actors, SwiftData inheritance.

Ported from the Claude Code plugin `fuse-swift-apple-expert` v1.2.0 (source folder
`plugins/swift-apple-expert`). The plugin name is deliberately identical across both ecosystems so
cross-plugin references (`fuse-swift-apple-expert:<skill>`) keep resolving.

## Contents

| Component | Count | Cursor discovery |
| :-- | :-- | :-- |
| Agents (subagents) | 1 | `agents/*.md` |
| Skills | 15 | `skills/<name>/SKILL.md` |
| Hooks | 2 events | `hooks/hooks.json` |

No `commands/` and no `docs/` folder: the source plugin has neither. An empty component folder
would be a divergence, not a precaution (R4–R6 / R8–R10 preamble).

## Skills

| Skill | Description |
| :-- | :-- |
| `swift-core` | Swift Testing first, Swift 6.2 concurrency defaults, architecture, i18n, performance, Xcode 27 agents and `xcrun mcpbridge` — across any Apple platform |
| `swiftui-core` | SwiftUI views, navigation, SwiftData 27, WebView, state, Liquid Glass, App Intents runtime, WidgetKit/ActivityKit, and HIG rules (accessibility, RTL, modality, notifications/Siri, iPhone Duo) — shared across iOS, macOS, watchOS, visionOS |
| `ios` | iPhone apps — simulator/device testing, UI automation, debugging — with XcodeBuildMCP tools; UIKit 26-27 |
| `ipados` | iPad apps — split views, external keyboard support, multitasking, Stage Manager, menu bar, toolbars, adaptive layouts |
| `macos` | Mac apps — menu bar extras, window management, toolbars, touch on Mac, AppKit integration, notarized distribution |
| `watchos` | Apple Watch apps — complications, workouts, HealthKit, iPhone-Watch connectivity |
| `visionos` | Vision Pro apps — spatial computing, RealityKit 27, ARKit, spatial web, ornaments, immersive spaces, volumes (no eye-tracking API) |
| `tvos` | Apple TV apps — focus-based navigation, Siri Remote interactions, media/video streaming UI |
| `apple-intelligence` | Foundation Models (on-device and Private Cloud Compute), Writing Tools, Genmoji, Image Playground, Visual Intelligence |
| `apple-frameworks` | Passkeys, MapKit, CloudKit, Core Data, TipKit, background tasks, MetricKit, App Attest, HealthKit, CarPlay, Chart3D |
| `graphics-games` | Metal 4, MetalFX, GameKit, Game Controller, Game Porting Toolkit 4; Metal vs RealityKit vs SpriteKit vs SceneKit |
| `media-vision` | AVFoundation, Now Playing, PhotoKit, Vision, Speech, translation, Core ML, Core Location, WeatherKit, EventKit |
| `mcp-tools` | Xcode build automation and Apple API/WWDC documentation lookup via XcodeBuildMCP and apple-docs MCP servers; UI verification on simulator; Xcode 27 agents and Xcode's MCP server |
| `build-distribution` | Apple releases — code signing, TestFlight upload, App Store submission, Icon Composer app icons, StoreKit 2, CI; deadlines: Developer ID G2 2027-02-01, age-rating declarations 2027-01-12, April 2027 SDK 27 / iOS 15 / iPhone Duo screenshots |
| `solid-swift` | SOLID for Swift 6/SwiftUI — hook size ceiling (`FUSE_SOLID_MAX_LINES`), protocol separation, `@Observable`, actors, feature-modular architecture |

SOLID guidance is **local** here (`solid-swift`), not delegated to `fuse-solid`.

## Activation

The agent activates when `Package.swift` or an `*.xcodeproj` is detected — iOS/macOS/watchOS/
visionOS/tvOS apps, SwiftUI views, Swift concurrency, XcodeBuildMCP automation. Not for web
frontend, Laravel/PHP, or non-Apple platforms.

Routing examples: "Add a Foundation Models summary feature" -> `apple-intelligence`; "Render with Metal 4 and MetalFX upscaling" -> `graphics-games`; passkeys, MapKit, CloudKit, TipKit, background tasks, HealthKit, CarPlay -> `apple-frameworks`; camera capture, Now Playing, PhotoKit, Vision, Speech, Core Location -> `media-vision`.

For UI changes the agent runs a 10-item HIG gate on the simulator (Dynamic Type AX5, dark mode + Increase Contrast, VoiceOver labels, hit targets, RTL, Reduce Motion/Transparency, Liquid Glass, screen sizes, modality/order), each reported `pass` / `fail` / `not verified`, before `sniper`.

## Configuration

No `variables` are declared; the plugin needs no secrets. Hooks shell out to
`npx -y @fusengine/harness`, so Node's `npx` must be on `PATH`.

The agent's tool list references two MCP servers — `XcodeBuildMCP` and `apple-docs` — which must be
configured on the Cursor side for the build-automation and documentation skills to work. The plugin
declares no `mcpServers` of its own; it did not in the source either.

## Port notes (read before editing)

### Agent

`swift-expert` is the plugin's only subagent.

- **`tools:` is kept in the frontmatter, unchanged** (R4). The 5-field table in Cursor's docs is
  incomplete: `tools` is a first-class repeated field of the internal `agent.v1.CustomSubagent`
  protobuf. The `## Allowed tools` block at the top of the body is emitted **in addition**, not
  instead — nothing proves the local `.md` frontmatter parser populates the field or enforces it at
  runtime, so both cover either outcome.
- **The two wildcard tool entries are kept verbatim**: `mcp__XcodeBuildMCP__*` and
  `mcp__apple-docs__*`. Whether Cursor expands a `*` suffix inside a `tools:` entry is unverified.
  R17/R19 govern: keep the source value and flag it rather than expanding it into a guessed list of
  concrete tool names.
- **`model: sonnet` → `model: grok-4.6`** — the uniform-model doctrine: every ported agent runs on
  `grok-4.6`, whose default effort is `medium`, written bare (`[effort=medium]` would be redundant).
  This agent is an executant, not an organ of control, so it takes no `[effort=high]`.
  `claude-opus-*` remains barred by policy.
- **`readonly` is not set** (R6). The rule requires the source `tools:` to contain neither `Write`
  nor `Edit` **and** no `mcp__*` tool. `swift-expert` fails both conditions: it declares `Write` and
  `Edit`, and its tool list is dominated by `mcp__*` entries.
- **`color:` and `skills:` are kept as-is** (R7/R19). `skills:` uses Claude Code's
  plugin-qualified form for the cross-plugin entry (`fuse-ai-pilot:fuse-browser-usage`); Cursor
  identifies skills by bare folder name, so whether the qualified form resolves is unverified. The
  list also names `elicitation`, a skill that lives in `fuse-ai-pilot` but is written unqualified in
  the source — that inconsistency is inherited, not introduced here.

### Skills

All 15 satisfy Cursor's hard rule that `name:` equals the parent folder name (R9). `references/` and
nested `references/templates/` folders are natively supported and were copied verbatim in the
initial port. On 2026-10-12 the source's uncommitted working-tree improvements were ported on top
(HIG references, mcp-tools workflows, tvOS/watchOS/visionOS/build-distribution updates), so
`diff -rq` against the source is no longer empty. On 2026-11-14 the source change `fd4f8c5e..a6a25857`
(v1.2.0) was ported: four new skills (`apple-intelligence`, `apple-frameworks`, `graphics-games`,
`media-vision`), 49 other new reference files, and updated SKILL.md/references; every reference file
changed in source range `fd4f8c5e..a6a25857` is byte-identical to the source except
`mcp-tools/references/xcode-agents.md`, the one adapted reference (Cursor `mcp.json` registration
first, Apple's `claude mcp add` / `codex mcp add` kept on one line, `AGENTS.md` / `.cursor/rules`
instead of `CLAUDE.md`). Target-only deviations kept on purpose: in `mcp-tools/SKILL.md` and
the agent body, the Xcode
MCP connection line says "register a stdio MCP server `xcode` in Cursor's MCP settings" instead of
Claude's `claude mcp add` command; the
`Task`-based wording (instead of Claude's `Agent`-with-`name`) in the SKILL.md "Agent Workflow" sections, the `FUSE_SOLID_MAX_LINES` rewrite of
`solid-swift`, the same ceiling wording in `swiftui-core` (no "30+ lines" view cap), this README's port notes, and the Cursor frontmatter of the agent.

Frontmatter keys preserved verbatim, absent from Cursor's documented skill schema and **not
verified against the binary**, so their status is unknown rather than unsupported (R7/R19):
`references` (15), `related-skills` (15), `user-invocable` (15), `versions` (14).

`user-invocable` was **not** translated to `disable-model-invocation` (R8). They are near-opposites:
Cursor's `disable-model-invocation: true` means "only reachable via `/skill-name`", whereas Claude
Code's `user-invocable: false` means "the user cannot type `/skill`, but the model may still
auto-invoke". Mapping one onto the other would invert the intent.

No skill carries an embedded `hooks:` block, so the pilot's `apex-methodology` problem does not
arise here.

### Hooks

Rewritten from Claude Code's nested shape to Cursor's flat shape (R11).

**R12 — every event this plugin declares (2 of 2):**

| Claude Code event | Cursor event | Status | Evidence |
| :-- | :-- | :-- | :-- |
| `PreToolUse` | `preToolUse` | `MAPPED` | `_Ni` @19775968. Matcher tests `tool_name`. |
| `PostToolUse` | `postToolUse` | `MAPPED` | `_Ni` @19775968. Matcher tests `tool_name`. |

**R13 — every tool matcher this plugin declares:**

| Source matcher | Event | Cursor matcher | Status | Consequence |
| :-- | :-- | :-- | :-- | :-- |
| `Write` | `PreToolUse` | `Write` | `MAPPED` | `tKu` @19776314. Unchanged. |
| `Edit` | `PreToolUse` | `Write` | `MAPPED` | `tKu`. Collapses into `Write`; the two source names become one entry. |
| `""` | `PostToolUse` | *omitted* | `R14` | Not a tool matcher — `""` meant match-everything; omitting the field is the Cursor-correct way to say that. |

Net: `preToolUse` matcher `Write|Edit` → `Write`; `postToolUse` matcher omitted. Both matchers were
compiled with `re.compile()` before shipping — R13's first trap is that the field is a regex and an
*invalid* one makes the hook match **everything**, silently (`cYg` @19779820 wraps the test in
`catch { return true }`).

The source `_description` and `_version` keys were removed (R16). They are not schema fields and
JSON has no comments; their content is reproduced in this file instead. Note the typing trap: the
source `_version` was the string `"2.0.0"`, a plugin-internal schema label. The `"version": 1` in
`hooks/hooks.json` is an **unrelated Cursor schema constant** (a number) written here from scratch —
a naive de-underscoring would have produced `"version": "2.0.0"`, a wrong-typed value in a real
field.

### Command path

Source: `bun $HOME/.claude/plugins/marketplaces/fusengine-plugins/plugins/node_modules/@fusengine/harness/dist/cli/bin.mjs hook claude-code`

Target: `npx -y @fusengine/harness hook cursor`

Two things forced the change (R15). The submission checklist requires that all manifest paths be
relative and valid — `$HOME/...` is absolute — and the path points into a Claude Code install tree
that does not exist for a Cursor user. `npx` removes the path dependency entirely. The source hook
declares **no scope argument**, and that absence is preserved exactly: nothing is appended after
`cursor`.

### Manifest

`.claude-plugin/plugin.json` → `.cursor-plugin/plugin.json` (R2). `author.url` was purged (R18b);
`strict` was absent. Every other key — including `keywords` — is unchanged.

## Runtime paths

This plugin references no `.claude/…` runtime state path in the body of any skill or agent (0
occurrences across 15 skills and 1 agent). There is nothing for the harness to resolve, so R21's
clause is deliberately not reproduced here: on a plugin with zero occurrences it would assert
something false.

The only `.claude/` strings in the source tree were two lines in the source `README.md` giving the
Claude Code **install** path (`~/.claude/plugins/swift-apple-expert/`). That is an install path, not
a state path — R21's exception 3 — and it disappeared with the README it lived in.

## Not portable

Nothing is lost in this plugin.

- Both source hook events map cleanly (R12), and both tool matchers map cleanly (R13) once `Edit`
  collapses into `Write`.
- The source declares no `Glob`, `MultiEdit`, `TaskCreate` or `TaskUpdate` matcher, and no
  `Notification` / `PermissionRequest` / `TeammateIdle` / `TaskCompleted` / `InstructionsLoaded`
  event — the constructs that are `NOT PORTABLE` under R12/R13.

Two source files were excluded as artefacts under R20a, carrying no behaviour: `.DS_Store` and
`mcp.json.bak`. Artefacts are not documented losses; they are listed here only because `mcp.json.bak`
looks like configuration. It is a `.bak` snapshot, excluded on sight per R20a.

The source `README.md` was **replaced** by this file rather than ported alongside it (R20c would
otherwise put two different documents at the same path). It was also **stale**: it advertised a
`Plugin: 1.0.0` version against a manifest at 1.1.17, and listed eight skills
(`swiftui-components`, `swift-architecture`, `swift-concurrency`, `swiftui-navigation`,
`swiftui-data`, `apple-platforms`, `swiftui-testing`, `swift-performance`) that **do not exist** in
the plugin. Only its accurate content — the platform coverage and the activation boundary — was
folded into the sections above; the wrong skill table was deliberately not carried over.

## Install locally

Clone the repository and point Cursor at this plugin directory, or install the whole repository as a
marketplace via its root `.cursor-plugin/marketplace.json`.
