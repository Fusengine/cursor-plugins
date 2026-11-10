# Changelog

## [0.1.12] - 10-11-2026

- feat(devops): new fuse-devops plugin at 1.0.0 — `devops-expert` agent + 18
  skills, no hooks, registered in `.cursor-plugin/marketplace.json` —
  marketplace now lists 26 plugins (was 25); fuse-rules project detection gains
  the infrastructure-repo row routing to `fuse-devops:devops-expert`
- feat(harness): atomic session-start auto-update to `@fusengine/harness`
  >= 0.1.115 — staged `bun add` into `versions/<ver>`, verified, `current`
  swapped by one rename, old version kept; zero process when current; back-off
  `FUSE_HARNESS_UPDATE_BACKOFF_MIN` (30) written before staging; mkdir
  single-flight lock; install bound `FUSE_HARNESS_INSTALL_TIMEOUT_SEC` (45);
  `--session-start` on 5 plugins, upgrade-only `--harness-check` on the 17
  others; installer delegates to `hook.sh --install-harness`
- fix(harness): fail-open when the shared control root is not writable — the
  installed harness keeps running, no install is attempted
- test(harness): `harness-autoupdate`, `harness-swap-atomic`, opt-in
  `harness-autoupdate-real`
- chore(plugins): PATCH bump, mirrored in `.cursor-plugin/marketplace.json` —
  core-guards 1.1.40, fuse-ai-pilot 1.2.47, fuse-cartographer 1.0.15,
  fuse-changelog 1.0.17, fuse-design 2.2.12, fuse-go 1.0.9, fuse-hermes 1.0.1,
  fuse-laravel 1.2.11, fuse-lessons 1.0.9, fuse-nextjs 1.1.27, fuse-php 1.0.10,
  fuse-react 1.0.24, fuse-rules 1.0.26, fuse-rust 1.0.10, fuse-security 1.0.21,
  fuse-seo 1.0.15, fuse-shadcn-ui 1.0.21, fuse-solid 1.0.22,
  fuse-swift-apple-expert 1.1.23, fuse-tailwindcss 1.1.14,
  fuse-tanstack-start 1.0.8, fuse-typescript 1.0.10
- chore(marketplace): suite `metadata.version` 0.1.11 → 0.1.12, README version badge updated

## [0.1.11] - 10-11-2026

- feat(security): port the claude-plugins security plugin refresh (v1.39.47) —
  new `agentic-security` skill; `auth-audit`, `cve-research`, `dependency-audit`,
  `security-headers`, `security-scan` skills (new references), `security-expert`
  agent, `scan` command and rules refreshed; Cursor adaptations (scan via
  `npx -y @fusengine/harness scan <dir>`, agent model grok-4.6, Agent → Task)
- chore(plugins): PATCH bump, mirrored in `.cursor-plugin/marketplace.json` —
  fuse-security 1.0.20
- chore(marketplace): suite `metadata.version` 0.1.10 → 0.1.11, README version badge updated

## [0.1.10] - 09-11-2026

- docs(ai-pilot): port the claude-plugins lead-corrections rules (49e2ea35) —
  `lead-orchestration`: Owner's verb, Scope, "Everywhere", Migration / deploy,
  Production data, Full gate before release; `brief-template`: owner's verb and
  "Everywhere" lines; `verification`: After each deploy; `sniper`: Test review rules
- chore(plugins): PATCH bump, mirrored in `.cursor-plugin/marketplace.json` —
  fuse-ai-pilot 1.2.46
- chore(marketplace): suite `metadata.version` 0.1.9 → 0.1.10, README version badge updated

## [0.1.9] - 09-11-2026

- feat(port): port the claude-plugins coordinator workflow — COORDINATOR PATH
  in `AGENTS.md`, `lead-orchestration` skill, at most 6 concurrent agents;
  rules, fuse-ai-pilot commands/agents and `apex-methodology` references in sync
- feat(fuse-ai-pilot): new `web-performance` skill, wired into the 5 web experts
- fix(docs): `browser_metrics` documented as server counters, not Core Web Vitals
- chore(experts): agent/skill updates for astro, laravel, nextjs, php, react,
  rust, security, seo, shadcn-ui, solid, swift-apple-expert, tailwindcss,
  tanstack-start, typescript, commit-pro
- feat(fuse-hermes): new plugin (13 skills) at 1.0.0, registered in
  `.cursor-plugin/marketplace.json` — marketplace now lists 25 plugins
  (installer, tests, `verify.sh`, docs and README badge updated)
- chore(plugins): PATCH bump, mirrored in `.cursor-plugin/marketplace.json` —
  fuse-ai-pilot 1.2.45, fuse-astro 1.0.15, fuse-commit-pro 1.2.27,
  fuse-laravel 1.2.10, fuse-nextjs 1.1.26, fuse-php 1.0.9, fuse-react 1.0.23,
  fuse-rules 1.0.25, fuse-rust 1.0.9, fuse-security 1.0.19, fuse-seo 1.0.14,
  fuse-shadcn-ui 1.0.20, fuse-solid 1.0.21, fuse-swift-apple-expert 1.1.22,
  fuse-tailwindcss 1.1.13, fuse-tanstack-start 1.0.7, fuse-typescript 1.0.9
- chore(marketplace): suite `metadata.version` 0.1.8 → 0.1.9, README version badge updated

## [0.1.8] - 12-10-2026

- fix(installer): keep the shared harness on latest — every installer run
  refreshes `@fusengine/harness` in the shared control root (`bun update`,
  falling back to `bun install`; fail-open) via new
  `scripts/src/services/harness-vendor.ts` (+ interface, 6 tests); the
  `hook.sh` wrapper comment (21 plugins + `plugin-runtime`) no longer claims
  auto-upgrade and names the upgrade path; installation docs updated
- chore(plugins): PATCH bump, mirrored in `.cursor-plugin/marketplace.json` —
  core-guards 1.1.39, fuse-ai-pilot 1.2.44, fuse-cartographer 1.0.14,
  fuse-changelog 1.0.16, fuse-design 2.2.11, fuse-go 1.0.8, fuse-laravel 1.2.9,
  fuse-lessons 1.0.8, fuse-nextjs 1.1.25, fuse-php 1.0.8, fuse-react 1.0.22,
  fuse-rules 1.0.24, fuse-rust 1.0.8, fuse-security 1.0.18, fuse-seo 1.0.13,
  fuse-shadcn-ui 1.0.19, fuse-solid 1.0.20, fuse-swift-apple-expert 1.1.21,
  fuse-tailwindcss 1.1.12, fuse-tanstack-start 1.0.6, fuse-typescript 1.0.8
- chore(marketplace): suite `metadata.version` 0.1.7 → 0.1.8, README version badge updated

## [0.1.7] - 12-10-2026

- fix(rules): "always delegate" made consistent — Scope Ladder first row is
  now "1 agent (the domain expert) + sniper — the lead never edits, even a
  one-line change"; a single canonical lead-edit exception (after 2 failed
  delegations on a localised, already-measured defect) used identically in
  `AGENTS.md`, `user-rules/fuse-global.mdc`, `templates/CLAUDE.md.template`,
  rule 03 and the fuse-ai-pilot `lead-orchestration` skill (step 4, its Check,
  and the Follow relaunch cap); `apex-quick` spawns ONE domain-expert subagent
  and the main session never edits inline; rule 02 SKIP APEX states the edit
  is still delegated
- chore(plugins): PATCH bump, mirrored in `.cursor-plugin/marketplace.json` —
  fuse-ai-pilot 1.2.43, fuse-rules 1.0.23
- chore(marketplace): suite `metadata.version` 0.1.6 → 0.1.7, README version badge updated

## [0.1.6] - 12-10-2026

- feat(port): port claude-plugins improvements adapted to Cursor — new
  fuse-ai-pilot `lead-orchestration` skill; rules 00/01/02/03/04/06/08,
  `AGENTS.md` and `user-rules/fuse-global.mdc` in sync (AUTONOMY, RECURRING
  TRAPS); solid-detection; commit-pro Step 9 release watch (conditional on a
  publish workflow) + `git-flow/references/release-workflow.md`; verification
  skill; sniper/challenger/explore-codebase/commit agents; design-ios
  (+4 references) and design-method; swift-apple-expert skills (+5 HIG refs,
  +2 mcp-tools refs) and the swift-expert agent
- chore(deps): scripts `@clack/prompts` ^1.8.1, `@types/bun` ^1.4.3
  (`bun.lock` refreshed); fuse-seo `package.json` dependencies bumped
- chore(parity): skills/agents parity with claude-plugins — TeamCreate → Task
  wording, new `fuse-ai-pilot/agents/skill-creator.md`, agent `tools:` lists
  synced, `readonly` removed on 3 agents, README version refreshes (Go 1.27,
  Rust 1.98, PHP PER-CS 3.1, TypeScript 7.0 / Bun 1.4), fuse-design
  fora-recode translated to English
- chore(plugins): PATCH bump, mirrored in `.cursor-plugin/marketplace.json` —
  fuse-ai-pilot 1.2.42, fuse-astro 1.0.14, fuse-cartographer 1.0.13,
  fuse-changelog 1.0.15, fuse-commit-pro 1.2.26, fuse-design 2.2.10,
  fuse-go 1.0.7, fuse-laravel 1.2.8, fuse-lessons 1.0.7, fuse-nextjs 1.1.24,
  fuse-php 1.0.7, fuse-prompt-engineer 1.1.12, fuse-react 1.0.21,
  fuse-rules 1.0.22, fuse-rust 1.0.7, fuse-seo 1.0.12, fuse-shadcn-ui 1.0.18,
  fuse-solid 1.0.19, fuse-swift-apple-expert 1.1.20, fuse-tailwindcss 1.1.11,
  fuse-typescript 1.0.7
- chore(fuse-seo): `package.json` version synced with `plugin.json` (1.0.12)
- chore(marketplace): suite `metadata.version` 0.1.5 → 0.1.6, README version badge updated

## [0.1.5] - 28-09-2026

- fix(hooks): core-guards now wires `beforeShellExecution` → `./scripts/hook.sh`,
  so shell commands pass the git/install/security guards before execution
  (loader-verified: `git checkout -b` → deny + CONFIRM, `git status` → allow,
  `git push --force` → deny G4 destructive)
- chore(gitignore): `.cursor/apex/` and `.cartographer/` added to agent scratch state
- chore(core-guards): PATCH bump 1.1.37 → 1.1.38, mirrored in `.cursor-plugin/marketplace.json`
- chore(marketplace): suite `metadata.version` 0.1.4 → 0.1.5, README version badge updated

## [0.1.4] - 27-09-2026

- chore(skills): port the claude-plugins 2026-09-27 skills refresh — latest
  stable versions (React 19.3, Next.js 16.3, Prisma 7.10, TypeScript 7.0,
  Tailwind CSS 4.3, Astro 7.3, Laravel 13, PHP 8.5, Go 1.27, Rust 1.98,
  Swift 6.4 / iOS 27), shadcn/ui Base UI-first, all content in English
  (707 skill/agent files)
- chore(plugins): PATCH bump, mirrored in `.cursor-plugin/marketplace.json` —
  fuse-astro 1.0.13, fuse-cartographer 1.0.12, fuse-design 2.2.9,
  fuse-go 1.0.6, fuse-laravel 1.2.7, fuse-nextjs 1.1.23, fuse-php 1.0.6,
  fuse-react 1.0.20, fuse-rust 1.0.6, fuse-seo 1.0.11, fuse-shadcn-ui 1.0.17,
  fuse-solid 1.0.18, fuse-swift-apple-expert 1.1.19, fuse-tailwindcss 1.1.10,
  fuse-tanstack-start 1.0.5, fuse-typescript 1.0.6
- chore(fuse-seo): `package.json` version synced with `plugin.json` (1.0.9 → 1.0.11)
- chore(marketplace): suite `metadata.version` realigned on the release line
  (0.1.1 → 0.1.4) and README version badge updated

## [0.1.3] - 07-09-2026

- fix(hooks): stop Cursor plugin hooks failing silently on every event —
  `plugin-scanner.ts` read the nested Claude Code `entry.hooks[]` shape
  instead of Cursor's flat `{ command, matcher?, type? }`, `matchesFilter`
  always tested `tool_name` instead of the command line / synthesized
  `MCP:<tool_name>` / `subagent_type` per event, and `./scripts/hook.sh`
  was never resolved to an absolute `cwd` before spawn. Also rewrote the
  `hooks-harness-exclusive` anti-regression gate (22 → 106 assertions,
  proven red path against shell-injection payloads)

## [0.1.2] - 04-09-2026

- feat(fuse-ai-pilot): `beforeMCPExecution` wired to the `aipilot` scope (matcher
  `MCP:(query-docs|resolve-library-id|web_search_exa|get_code_context_exa)`, `failClosed: false`).
  The harness doc-cache gate lives under that scope, but the event was only wired by `core-guards`
  and `fuse-design`, both in scope `core` — so the gate was never reached. `core-guards` still fires
  on the three shared doc tools; Cursor merges both results with `deny > allow`, and
  `resolve-library-id` is now covered for the first time
- chore(fuse-ai-pilot): PATCH bump 1.2.40 → 1.2.41, mirrored in `.cursor-plugin/marketplace.json`
- docs(harness): the Cursor adapter defects measured against real payloads are recorded in
  `docs/harness-cursor-fix-prompt.md`, with the RED commands that must flip and the requirement to
  isolate the `bash-write` work before any "no regression" claim. All three were fixed in
  `@fusengine/harness@0.1.94`, verified against the published package — the `hook.sh` wrappers track
  `latest`, so nothing is pinned here

## [0.1.1] - 01-09-2026

- refactor(installer)!: installer engine ported to TypeScript/bun — no `.mjs` left under
  `.cursor-plugin/scripts/`. Single entry point `install-hooks.ts`, which spawns the deploy engine
  (`src/services/global-install.ts` or `project-install.ts`) then runs the configuration stage
- chore(installer)!: prerequisite changed from Node.js to Bun (`curl -fsSL https://bun.sh/install | bash`);
  CLI options unchanged (`--dry-run`, `--uninstall`, `--project <path>`, `--skip-env`), as are the
  transactional guarantees (rollback, per-plugin hashes in `receipt.json`, ownership preflight, symlink guard)
- fix(mcp): MCP servers are now written directly to `~/.cursor/mcp.json` (non-destructive merge,
  API keys via `${env:NAME}`) — the port previously shelled out to `claude mcp add-json`, which is
  Claude Code's CLI, not Cursor's, so it installed nothing
- fix(hooks): the loader is wired into `~/.cursor/hooks.json` with camelCase Cursor events, verified
  against the Cursor 3.18.25 bundle — it previously targeted a `settings.json` Cursor never reads
- fix(rules): global instructions ship as `~/.cursor/rules/fuse-global.mdc` (`alwaysApply: true`,
  hashed in `receipt.json`). Cursor only recognises `AGENTS.md` at the root of a workspace folder,
  so a copy under `~/.cursor/` was never read
- feat(harness): every plugin embeds `scripts/hook.sh`, invoked through a relative path as the Cursor
  submission checklist requires; it resolves the shared harness (vendored binary → self-heal
  `bun install` → pinned `npx`) and tracks the `latest` release, so the plugin also works when
  installed from the marketplace, where no installer ever runs
- fix(installer): `--project` no longer exits 1 on a fresh `$HOME`. It used to fall through to the
  global setup stage, which scans `~/.cursor/plugins/local`; on a missing directory `find` exits 1
  and Bun's `$` turns that into an uncaught throw, so the command failed even though the project
  deploy had already succeeded. Project mode now stops after its own deploy, and a missing directory
  is no longer an error for `makeScriptsExecutable`
- fix(uninstall): `--uninstall` now removes the whole `~/.cursor/.fusengine-global` control root.
  It used to leave ~50 files behind for good — the deployed hook loader and its `src/` tree, plus the
  harness `node_modules` the wrapper self-installs there: the receipt only tracks plugins and the rule,
  so nothing could reclaim them, and a non-recursive `rmdir` failed silently on the non-empty directory.
  User plugins, a modified rule, `~/.cursor/.env` and the hooks/MCP config are untouched, as before
- fix(installer): `.DS_Store` is no longer copied into the deployed loader tree
- fix(env): `FUSE_HARNESS_REFS` now scans `~/.cursor/plugins/local` — it was one level short and
  silently produced an empty list
- chore(repo): added `.gitignore` (`node_modules` ignored, `bun.lock` committed) and the missing
  `.mdc` frontmatter on 12 plugin rules that were therefore never auto-applied

## [1.39.26] - 01-09-2026

- Fixed marketplace sparse checkout installation (24 plugin versions bumped)

## [0.0.1] - 01-09-2026

- docs(install): document Cursor marketplace setup

## [0.0.1] - 01-09-2026

- fix(installer): install Cursor plugins in correct scopes
