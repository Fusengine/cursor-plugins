---
name: 03-execution
description: Implement code following plan (APEX Phase E)
prev_step: references/02-features-plan.md
next_step: references/03.5-elicit.md
---

# 03 - Execution

**Implement code following plan (APEX Phase E).**

## When to Use

- After plan is complete and approved
- Follow the task order of the plan
- Update progress as you go

---

## Execution Order

### Strict Sequence

```text
1. Interfaces/Types/Protocols FIRST
2. Constants/Config
3. Utilities/Helpers
4. Main implementation
5. Integration points
```

### Why This Order?

```text
✅ Types catch errors early
✅ Utilities are reusable
✅ Main code has dependencies ready
✅ Easier to test incrementally
```

---

## Code Quality Rules

### File Size (ABSOLUTE)

```text
🚨 `FUSE_SOLID_MAX_LINES` is the only file-size ceiling
❌ NEVER exceed the resolved positive-integer ceiling (default `200`)
📊 Split by responsibility before the ceiling is exceeded
```

### Split Triggers

```text
If a file approaches the resolved ceiling or accumulates multiple responsibilities:
1. STOP writing
2. Identify logical boundaries
3. Extract to new file
4. Import and continue
```

---

## Documentation (Language-Specific)

Use your language's documentation standard:

| Language | Standard | Example |
| --- | --- | --- |
| TypeScript/JS | JSDoc | `/** @param name Description */` |
| PHP | PHPDoc | `/** @param string $name */` |
| Python | Docstrings | `"""Description."""` |
| Swift | DocC | `/// Description` |
| Go | GoDoc | `// FunctionName does X` |
| Rust | RustDoc | `/// Description` |

### Documentation Must Include

```text
✅ Brief function purpose
✅ Parameter descriptions
✅ Return value description
✅ Error/exception cases
✅ Usage example (complex functions)
```

---

## Pattern Compliance

### Follow Existing Patterns

```text
✅ Match naming conventions found in 01-analyze
✅ Use existing utilities (don't duplicate)
✅ Follow architectural patterns
✅ Consistent import ordering
```

### Interface Location (Language-Specific)

| Language | Location |
| --- | --- |
| TypeScript/JS | `src/interfaces/` or `src/types/` |
| PHP/Laravel | `app/Contracts/` |
| Swift | `Sources/Protocols/` |
| Go | Same package or `internal/` |
| Python | `interfaces/` or type hints |

---

## Commit Strategy

### Atomic Commits

```text
✅ One logical change per commit
✅ Commit after each task completion
✅ Conventional commit format
```

### Commit Format

```text
<type>(<scope>): <description>

Types: feat, fix, refactor, docs, test, chore
Scope: component/feature name
Description: imperative mood, <50 chars
```

### Examples

```text
feat(auth): add login validation
refactor(api): extract fetch utilities
test(auth): add login component tests
```

---

## Progress Tracking

### Update task status in your REPORT

```text
After each task:
1. Mark task as completed (state the status in your REPORT)
2. Note any deviations
3. Update estimates if needed
4. Flag blockers immediately (in your REPORT)
```

---

## Error Handling

### During Execution

```text
If you encounter:

1. Unexpected complexity
   → STOP, reassess, update plan

2. Missing dependency
   → Add to plan, implement first

3. File size limit approaching
   → Split immediately, don't push limits

4. Pattern conflict
   → Follow existing pattern, document deviation

5. API discrepancy
   → Re-verify with research-expert
```

---

## Anti-Patterns

```text
❌ Skip interfaces, write inline types
❌ Create files exceeding `FUSE_SOLID_MAX_LINES`
❌ Duplicate existing utilities
❌ Ignore existing patterns
❌ Large commits with multiple features
❌ No documentation/comments
❌ Push without local testing
```

---

## Validation Checklist

```text
□ Interfaces/types created first
□ All files within `FUSE_SOLID_MAX_LINES` (default `200`)
□ Documentation on all functions
□ Existing patterns followed
□ No duplicate utilities
□ Atomic commits made
□ Task status stated in your REPORT
□ Local testing passed
```

---

## Task Phase

Phase: `execution`. Do not create or write `.cursor/apex/task.json`: on Cursor no tool syncs it (the harness task sync is Claude-only). State the phase in your REPORT; tracking lives in the agents' REPORTs and `docs/decisions.md`.

---

## Next Phase

→ Proceed to `04-validation.md`
