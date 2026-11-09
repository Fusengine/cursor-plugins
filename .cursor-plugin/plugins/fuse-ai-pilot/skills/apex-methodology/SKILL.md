---
name: apex-methodology
description: "Use when starting ANY development task -- feature, bug fix, refactor, hotfix (triggers: implement, create, build, fix, add feature, refactor, develop)."
argument-hint: "[task-description]"
user-invocable: false
---

<objective>
APEX Methodology drives the full Analyze -> Plan -> Execute -> eLicit -> eXamine workflow for any development task -- new features, bug fixes, refactors, hotfixes. It auto-detects the project type (Laravel, Next.js, React, Swift) and loads the matching framework-specific reference set, then walks through branch creation, brainstorming, codebase analysis, planning, TDD execution, expert self-review (eLicit), functional verification, and sniper validation (eXamine) through to PR creation.

APEX requires the project's hard constraints throughout: `FUSE_SOLID_MAX_LINES` (default `200`) as the only file-size ceiling, interfaces kept out of component files, SOLID principles, and a mandatory sniper pass after every write. The agent must perform these requirements directly; the postToolUse/core-guards hooks are intended to reinforce them with reminders, but automatic end-to-end Cursor enforcement remains runtime-unverified in the inspected unpinned harness. Two elicitation modes control how much is automatic: `--auto` (default, no prompts) and `--manual` (only when the owner asks: 5 techniques proposed, the owner chooses). eLicit itself is never skipped. The Verify proof lives in the agent REPORT, with an optional record at `docs/verify/<branch-slug>.md` (never under `.cursor/`) — see the `verification` skill.
</objective>

**Current Task:** $ARGUMENTS

# APEX Methodology Skill

**Analyze → Plan → Execute → eLicit → eXamine**

Complete development workflow for features, fixes, and refactoring.

---

## Step 0: Task Tracking (MANDATORY FIRST ACTION)

**BEFORE anything else**, set up tracking — see `references/init-tracking.md`. Do not create or write `.cursor/apex/task.json`: on Cursor no tool syncs it (the harness task sync is Claude-only); tracking lives in the agents' REPORTs and `docs/decisions.md`. The agent MUST NOT Write/Edit until documentation is consulted. The preToolUse hooks are intended to deny qualifying operations until that consultation is recorded, but actual Cursor blocking remains runtime-unverified in the inspected unpinned harness.

---

## Workflow Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                     APEX WORKFLOW                               │
├─────────────────────────────────────────────────────────────────┤
│  00-init-branch     → Create feature branch                     │
│  00.5-brainstorm    → Design-first questioning (B) ← NEW        │
│  01-analyze-code    → Understand codebase (A)                   │
│  02-features-plan   → Plan implementation (P)                   │
│  03-execution       → Write code with TDD (E) ← UPDATED        │
│  03.5-elicit        → Expert self-review (L)                    │
│  03.7-verification  → Functional resolution check (V) ← NEW    │
│  04-validation      → Verify quality (X)                        │
│  05-review          → Self-review                               │
│  06-fix-issue       → Handle issues                             │
│  07-add-test        → Write tests (TDD cycle)                   │
│  08-check-test      → Run tests                                 │
│  09-create-pr       → Create Pull Request                       │
└─────────────────────────────────────────────────────────────────┘
```

### Skills Integration

| Phase | Skill | Invocation |
|-------|-------|------------|
| 00.5 | `brainstorming` | Questions → alternatives → design doc → approval |
| 03 | `tdd` | RED (test) → GREEN (code) → REFACTOR cycle |
| 03.7 | `verification` | Re-read request → check criteria → confirm resolution |

---

## Phase References

| Phase | File | Purpose |
| --- | --- | --- |
| **00** | `references/00-init-branch.md` | Create feature branch |
| **01** | `references/01-analyze-code.md` | Explore + Research (APEX A) |
| **02** | `references/02-features-plan.md` | Task-list planning (APEX P) |
| **03** | `references/03-execution.md` | Implementation (APEX E) |
| **03.5** | `references/03.5-elicit.md` | Expert self-review (APEX L) ← NEW |
| **04** | `references/04-validation.md` | sniper validation (APEX X) |
| **05** | `references/05-review.md` | Self-review checklist |
| **06** | `references/06-fix-issue.md` | Fix validation/review issues |
| **07** | `references/07-add-test.md` | Write unit/integration tests |
| **08** | `references/08-check-test.md` | Run and verify tests |
| **09** | `references/09-create-pr.md` | Create and merge PR |

---

## Core Rules

### File Size (ABSOLUTE)

```text
FUSE_SOLID_MAX_LINES is the only file-size ceiling.
Resolve it as a positive integer; default to 200.
Split any file that would exceed the resolved ceiling.
```

### Interface Location

```text
✅ src/interfaces/     (global)
✅ src/types/          (type definitions)
✅ Contracts/          (PHP/Laravel)
❌ NEVER in component files
```

### Agent Usage

```text
01-analyze:  explore-codebase + research-expert (PARALLEL)
04-validate: sniper (MANDATORY after ANY change)
```

---

## NEVER

```text
❌ Skip explore-codebase or research-expert
❌ Assume API syntax without verification
❌ Create files exceeding `FUSE_SOLID_MAX_LINES` (default `200`)
❌ Put interfaces in component files
❌ Skip sniper after changes
❌ Merge without tests
❌ Incohesive or unreviewable PRs
```

---

## Detailed References (Load on Demand)

- `references/init-tracking.md` — Load when running Step 0 (task tracking on Cursor: nothing to write, tracking lives in REPORTs)
- `references/phases-explained.md` — Load when you need the full explanation of each APEX phase (A/P/E/V/X)
- `references/branching-strategy.md` — Load when creating or naming branches
- `references/commit-conventions.md` — Load when writing commit messages
- `references/quick-start-flows.md` — Load when you need the full step-by-step Standard Feature / Bug Fix / Hotfix flows
- `references/flow-diagram.md` — Load when you want the full ASCII flow diagram of the workflow
- `references/validation-requirements.md` — Load when running the pre-PR / code-quality checklist
- `references/pr-guidelines.md` — Load when writing a PR title or description
- `references/language-detection.md` — Load when auto-detecting project type or navigating framework-specific reference directories
