# Global installation architecture

## Discovery layout

Cursor's user-global plugin directory is `~/.cursor/plugins/local/`. The installer copies every
marketplace entry as an individual immediate child:

```text
~/.cursor/plugins/local/
├── core-guards/.cursor-plugin/plugin.json
├── fuse-ai-pilot/.cursor-plugin/plugin.json
└── ... 22 more plugin roots
```

It does not copy or link the multi-plugin marketplace root as one child. The source marketplace
stores all 25 plugin roots under `.cursor-plugin/plugins/`; each manifest source must match that
deterministic nested path and each installed target remains the flat plugin name.

Cursor's cone-sparse marketplace checkout always materializes `.cursor-plugin/`. The same subtree
therefore carries the manifest, installer runtime, and every plugin source without a second clone
or a network bootstrap.

## Ownership and updates

The receipt at `~/.cursor/.fusengine-global/receipt.json` stores a deterministic content hash for
every installed plugin and the global rule. Reinstall replaces only targets whose current hash
matches the previous receipt. A foreign collision or user-modified owned target stops installation
before the active layout is changed.

Uninstall removes intact owned targets and preserves modified or foreign content with a warning.
The ownership marker and receipt are removed after that decision, so preserved content becomes
ordinary user-owned Cursor configuration.

## Transaction boundary

The installer builds a complete snapshot beside `plugins/local`, preserving foreign children. It
then swaps the shared directory by same-filesystem rename and atomically finalizes the rule,
receipt, and marker. A transaction journal restores the previous plugin directory and files after
an injected failure or an interrupted rename window.

All target paths and existing ancestors below the resolved home are checked with `lstat`; existing
and dangling symlinks are rejected. Tests set a temporary `HOME` and never exercise the real user
directory.

## Runtime boundary

Global Cursor discovery needs no project `workspaceOpen` loader. Plugin hook commands invoke
`./scripts/hook.sh`, the wrapper each plugin ships, after discovery. It resolves the harness from
the shared vendored install under `$HOME/.cursor/.fusengine-global`, self-heals it once if missing,
and falls back to pinned `npx`. That command executes hook mechanics; it does not install plugins.
The installer vendors the shared harness but never modifies it.
