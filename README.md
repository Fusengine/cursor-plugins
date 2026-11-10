# Fusengine Cursor Plugins

![version](https://img.shields.io/badge/version-0.1.11-blue?style=flat-square)
![plugins](https://img.shields.io/badge/plugins-26-brightgreen?style=flat-square)
![runtime](https://img.shields.io/badge/runtime-Cursor%20CLI-black?style=flat-square)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)

> **Cursor plugin marketplace.** 26 expert plugins for APEX workflows, SOLID/DRY
> enforcement, framework guidance, security, design, Git, SEO, and code quality.

## Quick install

```bash
# Register the marketplace
agent plugin marketplace add https://github.com/fusengine/cursor-plugins.git

# Run the installer directly from Cursor's marketplace checkout
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/install.sh --dry-run
~/.cursor/plugins/marketplaces/github.com/fusengine/cursor-plugins/*/install.sh
```

Windows PowerShell:

```powershell
agent plugin marketplace add https://github.com/fusengine/cursor-plugins.git
$installer = Get-ChildItem "$HOME\.cursor\plugins\marketplaces\github.com\fusengine\cursor-plugins\*\install.ps1" | Select-Object -First 1
& $installer.FullName -DryRun
& $installer.FullName
```

These are two distinct steps: `agent plugin marketplace add` registers
`fusengine-plugins`; it does not install the plugins. The bundled installer then
installs them globally for the current user. Its default target is `~/.cursor/`
on macOS/Linux or `%USERPROFILE%\.cursor\` on Windows. The `Cursor marketplace snapshot`
supplies the complete installer and all 26 plugin sources.

**Prerequisites:** Cursor CLI, Git, and Bun available to Cursor (install with
`curl -fsSL https://bun.sh/install | bash`). For project
scope, detailed installation, and filesystem layouts, see
[Installation and scope](docs/getting-started/installation.md).

## Documentation

- [Documentation index](docs/README.md)
- [Installation and scope](docs/getting-started/installation.md)
- [Global installation architecture](docs/reference/global-installation.md)
- [Project loader and hooks](docs/reference/project-loader.md)
- [Migration and compatibility notes](docs/reference/migration-compatibility.md)
- [Port audit summary](docs/reference/port-audit.md)

## License

MIT
