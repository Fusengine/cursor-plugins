---
description: SOLID/DRY enforcement — which SOLID skill and interfaces path to use per stack
alwaysApply: true
---

## SOLID Rules
SOLID/DRY → **consult the SOLID skills** (`solid-*`, table below).
1. **File size** — the ONLY authority is the hook's ceiling (`FUSE_SOLID_MAX_LINES`, owner-tunable, default 200); split well before it. Never set your own cap, never bypass the hook's; a legitimate fix that cannot fit is never skipped — report it to the owner (`AGENTS.md` RECURRING TRAPS).
2. **Interfaces separated** - Per stack location
3. **Research first** - `research-expert` before ANY code
4. **Validate after** - sniper per `00-critical-rules` Critical Rule 4
5. **JSDoc/PHPDoc** - Every exported function documented

## SOLID Skill per Stack (read before coding)

| Agent | Skill | Interfaces |
|-------|-------|------------|
| nextjs-expert | `solid-nextjs/references/` | `modules/[feature]/src/interfaces/` |
| laravel-expert | `solid-php/references/` | `app/Contracts/` |
| swift-expert | `solid-swift/references/` | `Sources/Interfaces/` |
| react-expert | `solid-react/references/` | `modules/[feature]/src/interfaces/` |
| astro-expert | `solid-astro/references/` | `src/interfaces/` |
| other languages | `solid` plugin: `solid-detection` → `solid-{python,go,java,rust,ruby,csharp,generic}/references/` | per stack convention |

**Split:** `main.ts` + `validators.ts` + `types.ts` + `utils.ts` + `constants.ts`

## DRY (ZERO TOLERANCE)

Before ANY new code: apply `00-critical-rules` DRY Priority (grep first), then load the stack's SOLID skill — `fuse-solid:solid-detection` routes to the right `solid-<stack>` (solid-nextjs, solid-react, solid-tanstack-start, solid-astro, solid-swift, solid-php (Laravel/PHP), solid-go, solid-rust, solid-python, solid-java, solid-csharp, solid-ruby, solid-generic), which defines that stack's shared locations; extend/reuse what exists.
