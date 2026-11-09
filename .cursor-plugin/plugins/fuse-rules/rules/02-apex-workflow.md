---
description: APEX workflow auto-trigger — when to use the full APEX methodology vs skip it
alwaysApply: true
---

## APEX — backbone of every code request

APEX is the coordinator path (`AGENTS.md` COORDINATOR PATH) applied to code. Seven phases, Brainstorm being the only optional one:
Brainstorm → Analyze → Plan → Execute → **eLicit** (expert self-review) → **Verify** (functional check) → **eXamine** (sniper, then challenger). Gate: eLicit + Verify run before sniper and are never skipped; eXamine is never skipped either (`00-critical-rules`).
Before starting, consult the `/apex` command and skill `fuse-ai-pilot:apex-methodology`. The full methodology lives there, not here.

**When APEX applies:** any request that touches code (create, implement, add, build, refactor, migrate, new component, multi-file, architecture, fix). Analyze = `explore-codebase` + `research-expert` + the domain expert in one message (COORDINATOR PATH 3).
**Trivial 1-3 line change:** `/apex-quick` — one delegated domain expert; it skips Brainstorm, the Analyze trio and the team split, but still runs eLicit, a real functional check (an executed build/test/run, not linter-only) and sniper.
**No APEX:** questions, read-only lookups (`explore-codebase` alone), simple read-only git.
**Debug/investigation** ("why", "not working", "bug", "crash", "doesn't load") always goes through Analyze first, never straight to a fix.

## APEX Flow

| Phase | Skill / owner | When |
|-------|---------------|------|
| **Brainstorm** | `brainstorming` | New features, major changes. Skipped for trivial fixes and bugs with a clear repro |
| **Analyze** | explore-codebase + research-expert + domain expert, in parallel | Every code request except `apex-quick` |
| **Plan** | Decompose, distribute, brief (COORDINATOR PATH 4-6; `03-agent-teams`) | Always. File size: the hook's `FUSE_SOLID_MAX_LINES` only, never a self-set cap |
| **Execute** | Domain expert + `tdd` | Test first (RED), then code (GREEN), then refactor |
| **eLicit** | Elicitation techniques, by the executing agent | Always |
| **Verify** | `verification`, checked by the lead with proof by type (COORDINATOR PATH 9) | Always — run the actual build/tests; a Verify without execution is a guess |
| **eXamine** | sniper, then challenger | sniper once every agent has finished (single agent: after its change), zero errors; challenger before any "done" |

## sniper 7 Phases (aligned with `ai-pilot/agents/sniper.md`)
explore-codebase ∥ research-expert (parallel) → grep usages → jscpd DRY scan → [react-effects-audit if `.tsx`/`.jsx`] → run linters → apply fixes → re-run all checks = zero errors.

## eLicit Modes
- `--auto` (default): auto-detect the code type → select elicitation techniques.
- `--manual`: only when the owner asks for it — the expert proposes 5 techniques, the owner chooses.
