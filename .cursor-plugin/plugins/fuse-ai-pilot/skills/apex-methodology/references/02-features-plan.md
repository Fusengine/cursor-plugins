---
name: 02-features-plan
description: Create detailed implementation plan (APEX Phase P)
prev_step: references/01-analyze-code.md
next_step: references/03-execution.md
---

# 02 - Features Plan

**Create detailed implementation plan (APEX Phase P).**

## When to Use

- After code analysis complete
- Before writing any code
- When scope is understood

---

## Task-List Planning

### Create Task Breakdown

```text
List in the plan (and in your REPORT):
1. Ordered list of implementation steps
2. Each step is cohesive and reviewable
3. Clear acceptance criteria
4. Dependencies between tasks (stated in the plan)
State each task's status (in_progress/completed) in your REPORT.
```

### Task Structure

```markdown
## Implementation Plan

### Task 1: [Create interfaces/types]
- File: [interfaces location]/feature.[ext]
- Lines: ~30
- Dependencies: None

### Task 2: [Create utility functions]
- File: [utils location]/feature-utils.[ext]
- Lines: ~50
- Dependencies: Task 1

### Task 3: [Implement main logic]
- File: [main location]/Feature.[ext]
- Lines: ~80
- Dependencies: Task 1, 2
```

---

## File Size Planning

### Size Estimation Rules

| Planning signal | Action |
| --- | --- |
| Cohesive single responsibility | Single file is appropriate if it stays within `FUSE_SOLID_MAX_LINES` |
| Multiple responsibilities | Plan split points now |
| Exceeds `FUSE_SOLID_MAX_LINES` | MUST split before starting |

### Split Strategy

```text
Large feature → Split into:
├── main.[ext] (focused orchestration)
├── types.[ext] (interfaces, types)
├── validators.[ext] (validation logic)
├── utils.[ext] (helper functions)
└── constants.[ext] (config, constants)
```

---

## Interface-First Design

### Create Interfaces FIRST

Define contracts before implementation:

```text
1. Input/Output types
2. Configuration types
3. State shapes
4. API contracts
```

### Location Rules (Language-Specific)

| Language | Interface Location |
| --- | --- |
| TypeScript/JS | `src/interfaces/` or `src/types/` |
| PHP/Laravel | `app/Contracts/` |
| Swift | `Sources/Protocols/` |
| Go | Same package or `internal/` |
| Python | `interfaces/` module |

```text
✅ Centralized interface location
❌ NEVER in component/implementation files
❌ NEVER inline in implementation
```

---

## Dependency Mapping

### Identify Order

```text
1. Interfaces/Types (no dependencies)
2. Constants/Config (no dependencies)
3. Utilities (depends on types)
4. Business logic (depends on types, utils)
5. UI/Controllers (depends on all above)
6. Tests (depends on implementation)
```

### Dependency Graph

```text
interfaces/types
    ↓
constants
    ↓
utils ←→ validators
    ↓
business logic
    ↓
UI/Controllers
    ↓
tests
```

---

## Risk Assessment

### Identify Risks

```text
□ Complex logic that should be split by responsibility?
   → Plan split NOW

□ Multiple external dependencies?
   → Verify compatibility

□ Existing code modifications?
   → Document current behavior

□ Database/API changes?
   → Plan migration

□ Breaking changes?
   → Document upgrade path
```

---

## Plan Template

```markdown
# Feature: [Name]

## Overview
[1-2 sentence description]

## Analysis Summary
- Patterns: [from 01-analyze]
- APIs: [verified methods]

## Tasks

### 1. Interfaces (~20 lines)
- [ ] Create [interfaces location]/feature.[ext]

### 2. Utilities (~40 lines)
- [ ] Create [utils location]/feature-utils.[ext]

### 3. Main Logic (~70 lines)
- [ ] Create [main location]/Feature.[ext]

### 4. Tests (~50 lines)
- [ ] Create [tests location]/feature.test.[ext]

## File Structure
[project structure visualization]

## Risks
- [identified risks]

## Estimated Total: ~180 lines (4 files)
```

---

## Validation Checklist

```text
□ Task list written in the plan / REPORT
□ All tasks are cohesive and reviewable
□ Interfaces planned FIRST
□ File splits pre-planned
□ Dependencies mapped
□ Risks identified
□ Total scope reasonable
```

---

## Task Phase

Phase: `features-plan`. Do not create or write `.cursor/apex/task.json`: on Cursor no tool syncs it (the harness task sync is Claude-only). State the phase in your REPORT; tracking lives in the agents' REPORTs and `docs/decisions.md`.

---

## Next Phase

→ Proceed to `03-execution.md`
