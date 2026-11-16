---
name: prd
description: PRD workflow for a multi-agent mandate on Cursor -- router init, task PRD written by the lead, assignment carried in the brief, agent reports, resume, validate
when-to-use: Steps 5, 6, 8 and 9 of lead-orchestration, only when FUSE_PRD=1 and the mandate has two or more agents
keywords: prd, fuse_prd, harness prd init, task prd, ownership, resume, validate
priority: medium
related: brief-template.md
---

# PRD (opt-in task/agent ownership)

## Why

When a lead splits one task across several subagents, PRD gives each agent one JSON report file that only it writes, so two agents never clobber each other's report, and `prd validate` proves every assigned sub-task was reported done. Source: `@fusengine/harness` `docs/prd.md` and `src/policy/prd/prd-ownership.ts`.

## When it applies

| Condition | Lead behaviour |
|-----------|----------------|
| `FUSE_PRD` is not exactly `1` (in `~/.cursor/.env` or `<project>/.env`) | Skip everything below. Zero change. The owner sets the flag; the lead never writes `~/.cursor/.env` (HARD STOP 3). |
| `FUSE_PRD=1`, one agent | Skip. |
| `FUSE_PRD=1`, two or more agents | Follow the procedure below. |

## Cursor specifics (measured in harness 0.1.121)

- Ownership is **consultative** on Cursor: the harness never blocks a PRD write there (no agent identity reaches it).
- The Cursor adapter **drops the `SubagentStart` slice**: the agent never receives its PRD assignment from the harness. The lead's brief carries it (step 6, block below).
- Files live under `<project>/.cursor/apex/`.

## Which harness to run

Run the harness from the plugin install that `scripts/hook.sh` resolves, never a global `harness` binary (it may predate `prd init`):

```
H="$HOME/.cursor/.fusengine-global/versions/$(cat "$HOME/.cursor/.fusengine-global/current")/node_modules/@fusengine/harness/dist/cli/bin.mjs"
bun "$H" --version        # prd init needs >= 0.1.121
```

Read-only use of `~/.cursor` only. A harness below 0.1.121 answers `unknown sub-command "init"`: the router cannot be created (the lead cannot Write `apex/prd.json`), so PRD stays off for the mandate -- say so in one line in the report, continue without it.

## Procedure

1. **Init (the router only)** -- after the step 5 table, the lead or an agent it names runs:
   `FUSE_PRD=1 bun "$H" prd init --id cursor --task <task-id> --root <project>`
   Creates `.cursor/apex/prd.json` = `{ "<task-id>": { "prd": "prd/<task-id>-prd.json", "status": "assigned" } }`. Never rewrites an existing router (exit 0 if valid and it holds the task; exit 1 if the task is missing -- then Write the entry). `<task-id>` matches `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`.
2. **Task PRD (the lead writes it)** -- `.cursor/apex/prd/<task-id>-prd.json` is coordinator-only; the lead writes it itself with Write (same exception class as `docs/decisions.md`; an agent never writes it). One entry per table row, keyed by the agent's name:

   ```json
   {
     "api-auth": { "files": ["src/auth/login.ts"], "sub-tasks": { "jwt-validation": { "status": "assigned" } } },
     "api-session": { "files": ["src/auth/session.ts"], "sub-tasks": { "session-store": { "status": "assigned" } } }
   }
   ```
   `files` = that agent's exclusive files from the step 5 table; sub-tasks = its deliverables (one name per OUTPUT line).
3. **Brief** -- every brief adds this block (after TEAM):

   ```markdown
   ## PRD ASSIGNMENT
   Task: <task-id>. You are `<agent name>`.
   Your files: <files>. Your sub-tasks: <sub1, sub2>.
   When done, write ONLY your own report `.cursor/apex/prd/agents/<agent name>-prd.json` (Write tool, never a shell redirect):
   { "<task-id>": { "<sub1>": { "status": "done", "modified": ["<path>"], "unchanged": [] } } }
   Never write the router, the task PRD or another agent's report.
   ```
4. **Follow / resume** -- `bun "$H" prd status --id cursor --root <project>` (read-only, no flag needed) lists agents, sub-tasks done/total and violations. A mandate resumed in a fresh session starts with it: reported slots stay closed, open ones are relaunched with the same brief block.
5. **Before "done"** -- `FUSE_PRD=1 bun "$H" prd validate <task-id> --id cursor --root <project>` must exit 0 (silent on success; otherwise one `- <task>/<agent>/<sub>: <reason>` line per gap -- resume that agent). Keep the output as the proof artifact. Optional afterwards: `prd compact <task-id>`.

## Never

- Never write the router by hand or by shell redirect (protected path; `init` exists for it).
- Never let an agent write the task PRD or another agent's report.
- Never treat a PRD report as proof of the deliverable: step 9 still opens the real output.
