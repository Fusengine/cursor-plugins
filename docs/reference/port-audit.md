# Cursor port audit summary

This page preserves the reusable conclusions from the original migration audit. It is evidence for
maintainers, not installation guidance.

## Inventory invariants

- `.cursor-plugin/marketplace.json` contains exactly 26 `plugins[]` entries.
- Every `source` is a top-level directory with `.cursor-plugin/plugin.json`.
- Marketplace and plugin manifests agree on plugin name and version.
- `core-guards` and `fuse-rules` are ordinary Cursor plugins because Cursor has no marketplace
  `core[]` equivalent. Their former required-install status is not enforceable by the marketplace.
- Hook-only plugins may correctly omit agents, skills, and commands.

## Hook conversion invariants

- Native hook files use `{"version":1,"hooks":{...}}` and lower-camel Cursor event names.
- Matchers are JavaScript regular expressions. An invalid expression can broaden matching and is a
  validation failure.
- MCP matchers use `MCP:<tool>` rather than the `mcp__<server>__<tool>` source form.
- Empty matchers are omitted.
- Hook commands invoke each plugin's own relative `./scripts/hook.sh`, which resolves the harness
  itself (vendored binary → self-heal `bun install` → `npx -y @fusengine/harness hook cursor` as
  last resort); this is runtime, not installation.
- Cursor-native events must live in Cursor-native hook files rather than compatibility-shaped files.

## Path invariants

- Native APEX state uses `.cursor/apex/`.
- Harness-owned project cache uses `.harness/cache/`.
- Project installation uses `<project>/.cursor/`; `~/.cursor/` is user-global.
- Executable paths never depend on a Claude marketplace root or `CLAUDE_PLUGIN_ROOT`.
- Compatibility references may remain only when they document an intentional input or migration
  fact rather than an executable Cursor path.

## Manifest and component invariants

- Plugin folders are named after each plugin's declared Cursor name.
- Manifests do not carry Claude-only strictness or owner URL fields.
- Skill `name` values match their parent directories.
- Agent model and tool metadata are preserved only where supported by verified Cursor schema or
  explicitly documented as runtime-unverified.
- Generated caches, build outputs, archives, lock files, and local installation state are excluded
  from plugin payloads.

## Verification boundary

`./verify.sh --repository-only` proves manifest bijection, JSON parsing, matcher compilation, path
hygiene, model constraints, skill identity, and migration contracts. The project integration test
proves installation mechanics in temporary directories.

Neither static check proves that a particular Cursor build delivers every lifecycle event. Runtime
activation must be confirmed after reload in Cursor's Plugins view and logs.

For detailed historical rationale, see plugin-level READMEs, the
[harness adapter analysis](harness/cursor-runtime-analysis-part-1.md), and
`docs/harness-cursor-fix-prompt.md`.
