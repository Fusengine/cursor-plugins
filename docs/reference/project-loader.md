# Project loader and hooks

## Discovery architecture

Cursor project discovery uses `<project>/.cursor/hooks.json`. The installer merges this entry into
the existing `workspaceOpen` array:

```json
{
  "command": "node .cursor/fusengine/load-plugins.mjs --fusengine-owner=<stable-token>"
}
```

The command is relative to the project root. It reads the installed `marketplace.json` as its sole
inventory, resolves only those declared plugin directories in manifest order, and prints one JSON
response:

```json
{"pluginPaths":["/absolute/project/.cursor/fusengine/plugins/core-guards"]}
```

The actual response contains one absolute path for every installed marketplace entry. Every path
is an individual plugin root containing `.cursor-plugin/plugin.json`. The marketplace root is never
returned as a plugin path, and the loader does not rely on recursive marketplace discovery.
Undeclared directories are ignored. Unsafe, duplicate, missing, or identity-mismatched manifest
entries make the loader fail instead of returning a partial list.

The loader also verifies its physical project-local managed root. Symlink substitution of
`.cursor`, `fusengine`, `plugins`, `marketplace.json`, an individual plugin root, its metadata
directory, or its plugin manifest is rejected before any external path can be emitted.

## Transactional updates

Installation copies all plugins into a same-filesystem staging directory below `.cursor/`, copies
the loader and marketplace inventory, then executes the staged loader as validation. Only a complete
stage can replace the managed root by rename. A copy or validation failure removes the stage and
leaves the previous installation and its registered hook functional.

After the swap and hook finalization commit, removal of the recovery backup is best-effort. A
cleanup failure keeps the new validated installation active, reports the exact retained path, and
does not falsely report installation failure. The next install removes only stale backup directories
that match the installer naming pattern and contain its exact ownership marker; lookalike unowned
directories are preserved.

## Non-destructive merge

The installer parses the existing hooks file, requires hooks schema version `1`, preserves unknown
top-level properties and unrelated event arrays, then adds one exact command entry. Reinstallation
deduplicates that owned entry.

If a matching command already exists, installation adds nothing and records no ownership. Otherwise
it appends one exact `{ "command": "..." }` object with a stable ownership token and records its
array occurrence in the receipt. The loader explicitly accepts that single harmless argument and
rejects every other argument. Reinstall keeps the same token and occurrence. Uninstall removes only
that recorded exact object; matching foreign objects, extra fields, order, and multiplicity are
preserved. It deletes `hooks.json` only when the installer created the file and no hooks or unrelated
keys remain.

Uninstall preflights target types and ownership before any mutation. Hook writes are atomic, and a
failure after hook mutation restores the original hook and rule snapshots while the managed plugin
root remains active. The managed root is renamed out of service only after file mutations succeed.

## Rule delivery

The installer generates `.cursor/rules/fusengine.mdc` from the repository's `AGENTS.md`, with
`alwaysApply: true`. Although the source policy is shared across the ecosystem, the installed rule
is project-scoped because it lives below the target repository's `.cursor/rules/` directory.

## Runtime hooks

Individual plugins carry `hooks/hooks.json`. Their commands invoke:

```text
./scripts/hook.sh
```

Each plugin ships that wrapper. It resolves the harness itself, in order: the shared vendored
install under `$HOME/.cursor/.fusengine-global` (the version named by `current`), then a one-shot
self-heal that stages a `latest` install and switches to it atomically, then `npx` on `latest` as a
last resort. At session start it also upgrades a version below `HARNESS_MIN` the same staged way. The path stays relative to the plugin, as the
Cursor submission checklist requires, and the plugin therefore works when installed from the
marketplace, where no installer ever runs.

This is runtime execution after Cursor has discovered a plugin. It is not installation. The `npx`
fallback may download the package on first use, so network and
package availability can affect the first hook execution.

The harness is maintained in a separate repository. This installer neither edits nor deploys its
source.
