# Harness Cursor Completion Prompt

Use this prompt in the `@fusengine/harness` source repository. Do not execute it from the Cursor plugin marketplace repository.

## Owner corrections (verbatim)

- "tu regarde comment fonctionne le harness pour adapté"
- "on est d'accord il ne touche pas au harness si il veulent faire des correction il me donne le prompt"
- "on a notre harness corriger sur l'ordinateur tu peux regarder mais pas toucher"
- "les mécaniques sont dans les hooks"

## Objective

Complete and package-prove the native Cursor adapter without changing the Cursor plugin marketplace. Start from the owner's corrected local harness and do not redo completed local P0 work unless a regression test proves it broken.

The local source and ignored local `dist` expose matching correction symbols, but this is not clean-build or package evidence. The version remains `0.1.90`, and no local tarball has been proven. Do not describe local corrections as published or safe to pin.

The current marketplace keeps all 62 `npx -y @fusengine/harness hook cursor [scope]` commands unpinned. Do not change those commands from this task. A future pin is allowed only after a corrected package has been built, packed, and verified independently.

## Hook/harness boundary

The hook manifests are trigger and configuration surfaces: they declare the event, matcher,
command, timeout, and any direct prompt hook. The mechanics executed by the 62 command entries live
in the harness: stdin normalization, gates, state, native response rendering, and blocking exit
status `2`. Preserve this boundary and do not claim runtime execution until authentic Cursor replay
proves it.

## Repository boundary

Work only in the harness source repository. Read-only inputs: the Cursor plugin marketplace and its hook manifests; installed Cursor configuration and plugin caches; the published npm tarball for `0.1.90`; official Cursor documentation and captured authentic hook payloads.

Never edit the marketplace, installed plugins, user configuration, package caches, or secrets. Never run marketplace setup or installation scripts.

## Implemented in local source

The owner-verified local source, with matching symbols in the ignored local `dist`, already contains: Shell/Bash command candidates; Write/Edit path and content candidates; MCP string, root, and nested candidates; `beforeReadFile` input normalization; `afterFileEdit` fan-out and neutral `{}` output; seven-event `harness init` wiring.

Treat these as regressions to preserve, not as unimplemented P0 tasks. Add or retain focused source tests for each behavior. Repair one only if its test fails, and document why the owner-verified baseline did not hold. Matching ignored-dist symbols do not replace clean dist or package proof.

## Remaining implementation

1. Canonicalize documented lower-camel lifecycle names for the internal dispatcher.
2. Render native, event-specific Cursor responses rather than a generic Claude envelope.
3. Preserve project `cwd` and `workspace_roots`, including multi-root selection.
4. Resolve plugin and rules roots from verified Cursor inputs with explicit precedence and diagnostics.
5. Define per-event policy for malformed JSON, empty stdin, and oversized stdin.
6. Add sanitized authentic Cursor lifecycle fixtures.
7. Implement **beforeReadFile native allow/deny permission enforcement**. The runtime currently allows it unconditionally. Keep normalization as a regression, then add native allow/deny rendering and `failClosed` tests for allow, deny, crash, timeout, and invalid output.

## Required analysis

1. Read the project cartography, adapter entrypoints, CLI dispatcher, normalization layer, response renderer, lifecycle dispatcher, configuration layout, package build configuration, and their tests.
2. Inventory every Cursor event used by the marketplace and every Cursor event supported by the adapter.
3. Compare separately the current TypeScript source, the locally built `dist`, and the exact files extracted from `npm pack @fusengine/harness@0.1.90`. Document every difference; identical version strings do not mean identical behavior.
4. Cross-check current official Cursor hook, plugin, subagent, and MCP documentation. Label behavior inferred from tests or binary inspection as such.

## Authentic Cursor fixtures

Add sanitized fixtures captured from real Cursor executions for every lifecycle shape the marketplace uses, at least: `sessionStart`, `sessionEnd`, `beforeSubmitPrompt`, `preCompact`, `subagentStart`, `subagentStop`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `beforeShellExecution`, `afterShellExecution`, `beforeMCPExecution`, `afterMCPExecution`, `beforeReadFile`, `afterFileEdit`, `stop`, `workspaceOpen`.

Fixtures preserve real field names and nesting while removing project paths, prompts, credentials, and personal data. Never synthesize payloads from Claude schemas. Cover multi-root workspaces, root-level and nested commands, stringified tool input where Cursor emits it, edit arrays, missing optional fields, malformed JSON, empty stdin, and oversized stdin.

## Canonicalization and native responses

Create one explicit Cursor event-name canonicalization table mapping lower-camel Cursor names to the internal lifecycle identifiers the dispatcher consumes. Do not route by Claude event aliases unless Cursor's documented compatibility layer produced that alias. Unknown events get a documented neutral behavior and must never enter another lifecycle branch.

For every event, prove: pre/post phase; canonical lifecycle name; tool name and matcher subject; command candidates; file path, edit content, and old content; session and subagent identity; project cwd and workspace roots.

Render a native response per Cursor event contract, never a generic Claude envelope. Prove separately that permission events return only Cursor-supported fields with exact casing, context-injection events return Cursor-supported context fields, observation-only post events return the documented neutral response, and `stop` and other lifecycle events use their own shapes. Malformed or oversized input follows an explicit, tested fail-open or fail-closed policy per event. Assert serialized stdout bytes in tests; TypeScript types alone prove nothing.

## Plugin root and cwd discovery

Do not assume `CLAUDE_PLUGIN_ROOT`, `CURSOR_PLUGIN_ROOT`, or `process.cwd()` is the plugin root. Discover it from verified Cursor inputs and the hook environment, with defined precedence and diagnostics: (1) an authenticated plugin-root value provided by Cursor; (2) a validated hook-command or package location; (3) marketplace metadata supplied by the runtime; (4) a safe failure when no root can be proven.

Use the payload's project `cwd` for project state and detection, and preserve `workspace_roots` for multi-root selection. Never silently replace payload cwd with the harness process cwd. Test local plugins, marketplace plugins, symlinks, npm execution, spaces in paths, missing environment variables, and a process launched outside the project root.

## State layout

- Session tracks live under `~/.fuse-harness/state/<project-hash>/` as `track-*.json`.
- `.harness/track/solid-notice.json` remains an existing project sidecar reader/writer; it is not the session tracking root. Preserve it until a separate migration is proven against every reader and writer.
- `.harness/cache` remains the harness-neutral project cache; `.harness/memory` remains harness-owned project memory where existing readers require it.

Do not introduce `.claude/apex` or `.claude/cache` as native Cursor state. Cursor APEX artifacts are `.cursor/apex`. Treat `.claude/settings.json`, `.claude/skills`, and `.claude/agents` only as documented compatibility inputs, not harness-owned state.

## TDD and build proof

Use RED-GREEN-REFACTOR for each contract: add a failing fixture test and record the expected failure reason; apply the smallest source correction; run unit, adapter, lifecycle, integration, and simulation tests. Then:

1. Build `dist` from a clean output directory and run the same fixtures against source and built `dist`.
2. Create a local npm tarball with `npm pack` or the repository's pack command; install it only into an isolated temporary directory.
3. Run the same fixtures through the packed CLI and assert stdout, stderr, and exit status.
4. Compare the packed file list with `package.json#files` and prove the corrected adapter and CLI code are included.

Include regression tests for the `0.1.90` tarball defects so a source-only fix cannot pass. Require **source + clean dist + local packed-tarball parity**; an ignored-dist symbol match is insufficient.

Require **version >0.1.90 before publishing or pinning**. Select the minimum valid next version only after packed parity is proven. This task must not publish or pin it.

## Measured defects — RED commands that must flip

These three were obtained by executing the CLI against payloads built from `cursor.com/docs/hooks`,
never from a repository fixture. A forged fixture is what produced the original false green. Each
command below gives the wrong answer today; the task is done when each gives the right one.

```bash
cd <fuse-harness>

# 1. BLOCKING — must become allow, returns deny today.
#    Phase is derived from `filePath && edits.length > 0` instead of `hook_event_name`
#    (src/adapters/cursor/normalize.ts:33), so a degenerate afterFileEdit falls into the PRE
#    pipeline and blocks. This is the "must not accidentally enter a different lifecycle branch"
#    clause above, and it contradicts the module's own contract in
#    src/adapters/cursor/index.ts:36-44 — "We deliberately never emit permission:\"deny\" here".
#    Same cause, same fix: postToolUse, afterShellExecution and beforeReadFile also return deny
#    on real payloads today. postToolUse has no `permission` field in its documented schema at all.
echo '{"hook_event_name":"afterFileEdit","file_path":"/tmp/x.ts","edits":[]}' | bun src/cli/bin.ts hook cursor core

# 2. Must become deny, returns allow today.
#    cursorToolName() (src/adapters/cursor/normalize.ts:14-18) does `tool === "Shell" || (!tool && hasCommand)`.
#    Any tool_name present and different from "Shell" that still carries a command disarms every
#    Bash guard: "Terminal", lowercase "shell", and the documented "MCP:<tool_name>" form.
#    Exact-match allowlisting is literally the logic that produced the original P0.
#    Robust criterion: a `command` is present => arm the guards, whatever the tool is called.
echo '{"hook_event_name":"preToolUse","tool_name":"Terminal","tool_input":{"command":"rm -rf /"}}' | bun src/cli/bin.ts hook cursor core

# 3. Three consecutive runs must give identical counts and identical failing test names.
bun test 2>&1 | tail -3
```

Also verify, and decide explicitly: the `afterFileEdit` size/DRY verdict is currently computed
from the fanned-out `edits[]` and then discarded (`src/runtime/post-outcome.ts:30`, plus the
`&& !cursorAfterFileEdit` guards in `handle-post.ts`). Net effect for the user is identical to
before the fix. Either emit it as `permission:"allow"` + `user_message` — the only channel
`afterFileEdit` exposes — or record it as a real loss. What is not acceptable is the current
state, where `test/cursor-cli-p0.test.ts` locks the silence in with `toEqual({exit:0, stdout:""})`:
a test that freezes a defect makes it permanent.

## Work isolation — required before any "no regression" claim

At last measurement the working tree held 25 modified files plus 6 untracked, including
`src/policy/guards/bash-write.ts`, `bash-write-safe-paths.ts`, `bash-write-redirects.ts`,
`protected-path.ts`, `src/policy/shell-read-refs.ts`, `src/prompt/types.ts`,
`src/runtime/confirm/confirm-gate.ts` and `codex-confirm.ts` — none of them Cursor adapter files.
The tree also changed *during* verification (12 modified files at the start, 25 at the end).

Separate the `bash-write` work from the Cursor fix, then re-run the suite on a frozen tree.
While both live in the same tree, "0 failures" is unfalsifiable and the one deterministic
failure — `test/approval-never.test.ts:67`, where `evaluate(never(...))` returns `deny` instead
of `warn`, reproducible in the repo and absent from a pristine HEAD export — cannot be attributed
to either effort.

## Verification report

Report: exact changed harness files; RED and GREEN commands with results; fixture provenance and sanitization method; the canonicalization table; the native response table; plugin-root and cwd precedence; source versus dist versus packed-tarball evidence; remaining undocumented Cursor behavior; the minimum corrected version that could safely be published later.

## Forbidden actions

Do not commit, push, create or switch a branch, open or merge a pull request, tag, publish, release, install into real Cursor state, alter marketplace hook commands, or modify user configuration. Stop after producing verified source changes and an isolated local tarball report.
