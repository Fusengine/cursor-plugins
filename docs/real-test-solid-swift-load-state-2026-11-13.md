# Real test: solid-swift LoadState change, Cursor (cursor-agent)

Date: 2026-11-13. Worktree: `cursor-plugins-wt-swift`, skill `.cursor-plugin/plugins/fuse-swift-apple-expert/skills/solid-swift`.

## Verdict: BLOCKED (not PASS) - Cursor account usage limit hit mid-run

| PASS criterion | Result |
|----------------|--------|
| Log shows worktree `state-machines.md` / `viewmodel.md` read | MET |
| Produced Swift uses `LoadState`, no `isLoading` | NOT MET: no Swift file was produced |
| `swiftc -typecheck -swift-version 6` exit 0 | NOT RUN: nothing to typecheck |

## Command

Script `<scratchpad>/realtest/run-cursor.sh` (scratchpad = `/private/tmp/claude-501/-Users-brunoazoulay-Labo-docker-lab-dev-local-Dev-ai-claude-code-claude-plugins/2723977a-20cc-47b1-bf76-10a7db930be8/scratchpad`), cwd = `<scratchpad>/realtest/cursor` (empty):

```
cursor-agent -p --trust --force --sandbox enabled --workspace <scratchpad>/realtest/cursor \
  --add-dir <worktree skill dir> --output-format stream-json \
  "Read <worktree>/skills/solid-swift/SKILL.md and the references it lists, then use the solid-swift skill to write a SwiftUI FeatureViewModel and FeatureView that load a list of articles from an ArticleService. Write them to ArticlesViewModel.swift and ArticlesView.swift in the current directory. Do not write anywhere else."
```
Login verified first: `cursor-agent status` -> `Logged in`. No `--plugin-dir` was used (the prompt points at the worktree skill path, as briefed). Nothing written under `~/.cursor` by me.

## Evidence

Transcript: `<scratchpad>/realtest/cursor/transcript.jsonl` (32 tool calls started). `readToolCall` paths, all under `.../cursor-plugins-wt-swift/.cursor-plugin/plugins/fuse-swift-apple-expert/skills/solid-swift/`:

```
SKILL.md
references/solid-principles.md, single-responsibility.md, open-closed.md, liskov-substitution.md,
  interface-segregation.md, dependency-inversion.md, concurrency-patterns.md,
  state-machines.md, anti-patterns.md
references/templates/view.md, viewmodel.md, service.md, protocol.md, model.md
```
The agent read every reference the SKILL.md lists, including the new `state-machines.md` and `templates/viewmodel.md`. It then planned (sequential-thinking: "LoadState"), ran explore + research sub-tasks, and issued the last call: a `Task` "Write Articles Swift files" delegating the two-file write to a `swift-expert` subagent, with `LoadState` named in the mandate.

Then the run stopped. `stderr.txt`:
```
ActionRequiredError: You've hit your usage limit Get Cursor Pro for more Agent usage, unlimited Tab, and more.
```
Confirmed not transient: a minimal probe (`cursor-agent -p --mode ask "reply ok"`) returned the same error. `find . -name '*.swift'` in the temp dir: none.

## Not verified

- Whether the Cursor-produced Swift follows `LoadState` (no file exists).
- Typecheck (not run; stubs would be the same as in the Claude report: `LoadState`/`LoadFailure` verbatim from `state-machines.md`, plus `Article`, `ArticleServiceProtocol`, `MockArticleService`).

## Owner action to unblock

Cursor usage limit must be lifted (plan upgrade or quota reset). Then re-dispatch: re-run `bash <scratchpad>/realtest/run-cursor.sh`, then typecheck. I did not retry in a loop (same fix twice, account-level limit).

## Files touched

`<scratchpad>/realtest/cursor/` (transcript.jsonl, stderr.txt, `.harness`), `<scratchpad>/realtest/run-cursor.sh`, and this report. No commit.
