---
name: init-tracking
description: APEX task tracking at Step 0 — nothing for agents to write; tracking lives in REPORTs
---

# Step 0: Task Tracking

**Do not create or write `.cursor/apex/task.json`: on Cursor no tool syncs it (the harness task sync is Claude-only).** No APEX step creates, initializes or writes it — no `mkdir`, no `jq > task.json`.

## What to do at Step 0

Tracking lives in the agents' REPORTs (current phase, files touched, proof) and in `docs/decisions.md` for decisions that must outlive the session.

## Proof artefacts (not under `.cursor/`)

The eLicit and Verify proofs live in the agent REPORT; their optional records go to `docs/verify/elicit-<branch-slug>.json` and `docs/verify/<branch-slug>.md` at the repo root. `<branch-slug>` follows the `verification` skill's derivation (`references/verify-template.md`): `git branch --show-current`, drop the `<type>/` prefix, lowercase, every character outside `a-z0-9` becomes `-`; detached HEAD → `detached-<short sha>`.

```bash
BRANCH=$(git branch --show-current)
if [ -n "$BRANCH" ]; then
  BRANCH_SLUG=$(printf '%s' "${BRANCH#*/}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
else
  BRANCH_SLUG="detached-$(git rev-parse --short HEAD)"
fi
```

**Agents must not use Write/Edit until documentation is consulted; PreToolUse hook denial is intended defense-in-depth, and actual Cursor blocking remains runtime-unverified with the unpinned harness.**
