# Installation and scope

## Prerequisites

- Cursor
- Cursor CLI (`agent`)
- Git
- Bun — required; `install.sh` / `install.ps1` exec straight into
  `.cursor-plugin/scripts/install-hooks.ts`, which deploys the plugins (the
  global or project engine under `src/services/`) and then runs the
  configuration stage (hooks, `.env`, MCP servers, shell loaders, vendored
  harness). Install it with
  `curl -fsSL https://bun.sh/install | bash`.

## Marketplace registration and global installation

### macOS and Linux

```bash
agent plugin marketplace add https://github.com/fusengine/cursor-plugins.git
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/install.sh --dry-run
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/install.sh
```

### Windows PowerShell

```powershell
agent plugin marketplace add https://github.com/fusengine/cursor-plugins.git
$installer = Get-ChildItem "$HOME\.cursor\plugins\marketplaces\github.com\fusengine\cursor-plugins\*\install.ps1" | Select-Object -First 1
& $installer.FullName -DryRun
& $installer.FullName
```

Marketplace registration and bundled installation are distinct. The official
`agent plugin marketplace add` command registers `fusengine-plugins`; it does
not install the 26 plugins. The repository's installer performs the global
installation and defaults to `~/.cursor/` on macOS/Linux or
`%USERPROFILE%\.cursor\` on Windows. Cursor's marketplace checkout contains the
installer runtime and all 26 plugin sources under `.cursor-plugin/`, so no
second clone is required.

## Project scope

Project scope is optional and applies only to the target repository. Run the
same marketplace installer path with an explicit project target.

### macOS and Linux project install

```sh
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/install.sh --project /absolute/path/to/your-project --dry-run
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/install.sh --project /absolute/path/to/your-project
```

### Windows PowerShell project install

```powershell
& $installer.FullName -Project C:\path\to\your-project -DryRun
& $installer.FullName -Project C:\path\to\your-project
```

PowerShell delegates to the same Node installer as the Bash entry point. The
Bash integration test proves the macOS/Linux path. PowerShell parity remains
runtime-unverified until executed on Windows.

## Global installation layout

```text
~/.cursor/
├── plugins/local/<plugin-name>/.cursor-plugin/plugin.json
├── rules/fuse-global.mdc
└── .fusengine-global/
    ├── .managed-by-fusengine
    ├── receipt.json
    ├── package.json        # spec "latest", copied from .cursor-plugin/harness
    ├── bun.lock
    └── node_modules/@fusengine/harness
```

The bundled installer copies each repository plugin as an immediate child of
`plugins/local`; the marketplace root is never installed as one plugin.
Existing foreign plugin directories are preserved. Reinstall refreshes only
intact installer-owned copies and refuses modified or colliding targets.

### Shared harness upgrades

Every `install.sh` run rewrites `.fusengine-global/package.json` from the repo
manifest (`"@fusengine/harness": "latest"`, never a pinned version) and runs
`bun update @fusengine/harness`, which keeps the dist-tag and advances
`bun.lock` to the newest release. The `hook.sh` wrappers only install the
harness when it is missing; they never upgrade it. Without re-running the
installer, upgrade by hand with
`cd ~/.cursor/.fusengine-global && bun update @fusengine/harness`.

## Project installation layout

```text
<project>/.cursor/
├── hooks.json
├── rules/fusengine.mdc
└── fusengine/
    ├── load-plugins.mjs
    ├── project-plugin-inventory.mjs
    ├── marketplace.json
    ├── install-receipt.json
    └── plugins/<plugin-name>/
```

Plugin files are copied into the project instead of linked to an external
checkout. The project therefore remains self-contained and the loader never
depends on an external symlink target.

## Installer scope distinction

`<project>/.cursor/` is project scope. It applies only when Cursor opens that repository.

`~/.cursor/` on macOS/Linux and `%USERPROFILE%\.cursor\` on Windows are
user-global scope and are the default. `<project>/.cursor/` is selected only by
`--project` or `-Project`. Both modes copy plugin sources; neither depends on an
external checkout symlink.

## Verification

```sh
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/verify-project.sh /absolute/path/to/your-project
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/verify.sh --repository-only
```

All integration tests use temporary projects and fake home directories.

## Uninstall

Remove only intact installer-owned global artifacts:

```sh
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/install.sh --uninstall
```

Remove one project installation:

```sh
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/install.sh --project /absolute/path/to/your-project --uninstall
```

Global uninstall preserves foreign or modified plugin directories and rules.
Project uninstall removes only its owned `workspaceOpen` entry, managed
directory, and unchanged rule. Both modes validate ownership and target types
before destructive mutation.
