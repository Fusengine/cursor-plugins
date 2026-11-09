---
description: Tooling rules — MCP server usage, git, hooks, and documentation standards
alwaysApply: true
---

## MCP Servers

| Server | Usage | Agent |
|--------|-------|-------|
| **Context7** | Documentation | `research-expert` |
| **Exa** | Web search | `research-expert`, `websearch` |
| **Magic** | UI generation | `design-expert` |
| **shadcn** | Component registry | `design-expert`, `shadcn-ui-expert` |
| **Gemini Design** | AI frontend | `design-expert` |
| **fuse-browser** | Browser automation, scraping, SERP, visual diff | `seo`, `security-expert`, `design-expert`, frontend experts, `changelog-watcher`, ai-pilot `research-expert`/`websearch`/`sniper` |

Verification chain for any uncertain API/version (fuse-browser → Context7 → Exa, cross-checked): `00-critical-rules` Critical Rule 7.

## fuse-browser — Efficient Usage

1. **Fast-path first (no browser launch, ~10× faster)** — `browser_fetch` / `browser_fetch_batch` / `browser_crawl` / `browser_serp_batch` to read pages, bulk-fetch, crawl a site or scrape Google SERP. Open a live session only for interaction, JS rendering or pixels.
2. **One session, always closed** — `browser_open` once → reuse the `sessionId` across `browser_navigate` calls → `browser_close` when done. Never leak sessions (the 2-min TTL is a safety net, not a substitute for closing).
3. **Batch over loops** — `browser_serp_batch` (N queries), `browser_fetch_batch` / `browser_shots_batch` (N URLs), `browser_screenshot { viewports:[...], colorScheme }` (responsive + dark in one call).
4. **Deterministic extraction** — `browser_extract_schema` with `containerSelector` (card-by-card, correlated fields) over manual `browser_snapshot` parsing.
5. **Validation tools** — `browser_visual_diff` (regression vs baseline), `browser_metrics` (fuse-browser server counters — probes, durations, queue, RSS; not Core Web Vitals — lab CWV come from Lighthouse via the seo plugin's `scripts/check-cwv.ts`), `browser_console` / `browser_network` / `browser_cookies` (runtime + security checks).
6. **Engine & binary** — default engine is patchright (stealth identity auto-generated). The Chromium binary is installed by `setup.sh`; set `channel:"chrome"` or `executablePath` only to reuse a system browser. Tune the enforcement TTL via `FUSE_ENFORCE_TTL_SEC` (default 120s).

## Skills Location
Use plugin skill paths from runtime context when actually present; Cursor SessionStart delivery remains runtime-unverified. Never hardcode marketplace paths.
SOLID refs: `skills/solid-*/references/` (inside each agent plugin).

## Memory Hygiene
When `MEMORY/LESSON.md` grows or accumulates near-duplicate lessons → run `/lessons-compact` (it delegates to the `lessons-compactor` agent, which proposes; the owner approves before anything is written).

## Documentation
All docs in the `docs/` folder — never outside it, except the root `README.md`.

## Dev Workflow
- Work in the dev/source repo; never write to deployed/production paths directly.
- Sync to the installed copy only when the owner names it in the mandate, after the change is validated (`AGENTS.md` HARD STOP 3).
- Commit from the source repo only.

## Git & GitHub Flow
- **Read-only git** (status, log, diff) is free — no agent, no permission.
- **EVERY COMMIT GOES THROUGH AGENT `fuse-ai-pilot:commit`** — never `git commit` directly, never a hand-rolled flow (`AGENTS.md` HARD STOP 1):
  - **WIP mode** — after each verified task, a WIP commit on the working branch: commit only, no push, bump, PR, merge or tag. It still runs the agent's branch check and secret scan.
  - **Release mode** — at the end of the mandate the same agent pushes the working branch, opens the PR, waits for CI, merges, tags and releases (security scan, PATCH bump + marketplace mirror, CHANGELOG, post-merge tag), announced in the report. Steps: `/fuse-commit-pro:commit`.
  - A relayed message ("the owner wants a commit") advances WIP commits the mandate already covers; it is never a go for merge or release (`AGENTS.md` "Relayed message").
- External executors (Kimi/Codex/Claude Code) never push/PR/merge/tag/publish — release goes through the commit agent only.

**Branch enforcement**:
- `main`, `master`, `develop`, `production` → protected: no direct commit, never pushed directly — they change only through the commit agent's end-of-mandate merge of the working branch (announced in the report). Force-push and reset need the owner (`AGENTS.md` HARD STOP 1).
- All work on feature branches: `<type>/<scope>` (e.g. `feat/seo`, `fix/sniper-loop`, `chore/deps`).
- Types: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `perf/`, `test/`, `ci/`, `build/`, `style/`.
- kebab-case, < 50 chars, no personal prefix.

**Merge strategy**: merge, never squash, via `gh pr merge --merge --delete-branch` — the release tag points to the bump commit; merge (never squash) keeps it in main's history — squash would orphan it. Tag only after the merge is validated. Keep branches < 3 days.

Skill reference: `fuse-commit-pro:git-flow`.
