#!/usr/bin/env bun
/**
 * install-hooks.ts - Single entry point for the Fusengine Cursor installer.
 * @description Parses --project/--dry-run/--uninstall/--skip-env, spawns the
 * matching TS deployment engine (global-install.ts or project-install.ts,
 * transactional deploy with rollback), then chains the environment
 * configuration stage (hooks, MCP, shell loaders, vendored harness) unless
 * the requested mode makes it moot.
 */
import { dirname, join } from "node:path";
import * as p from "@clack/prompts";
import { runSetup } from "./src/services/setup-runner";

const HOME = process.env.HOME || process.env.USERPROFILE || "";
const SCRIPT_DIR = dirname(import.meta.path);
const PROJECT_ROOT = dirname(SCRIPT_DIR);

/**
 * Cursor deploys plugins flat under `~/.cursor/plugins/local/<name>`, with no
 * intermediate `plugins/` directory — unlike Claude Code's marketplace layout.
 * `marketplace` therefore points one level up, so the setup runner's
 * `join(marketplace, "plugins")` resolves to that same flat directory.
 */
const PATHS = {
	settings: join(HOME, ".cursor/.fusengine-global/settings.json"),
	marketplace: join(HOME, ".cursor"),
	pluginsDir: join(HOME, ".cursor/plugins/local"),
	loaderSrc: join(SCRIPT_DIR, "hooks-loader.ts"),
	harnessHookScript: join(PROJECT_ROOT, "plugins/core-guards/scripts/hook.sh"),
	cursorMdSrc: join(
		PROJECT_ROOT,
		"plugins/fuse-rules/templates/CLAUDE.md.template",
	),
	// Cursor recognises AGENTS.md only at the ROOT OF A WORKSPACE FOLDER (verified
	// in Cursor 3.18.25: `getWorkspaceFolder(uri)` returns false outside one), so a
	// file under ~/.cursor/ would never be read. The global instructions channel is
	// the user rules directory — `getRuleTargetDirectory` resolves to
	// joinPath(userHome, ".cursor", "rules") — hence a .mdc there.
	cursorMdDest: join(HOME, ".cursor/rules/fuse-agents.mdc"),
};

/**
 * Spawn the deployment engine matching `argv` (global by default, project
 * when `--project <path>` is present), forwarding stdio and its exit code.
 * `--skip-env` is a configuration-stage-only flag: the deploy engines never
 * saw it even in the two-process era, so it is stripped before forwarding.
 */
function runDeployEngine(argv: string[]): void {
	const isProject = argv.includes("--project");
	const engine = join(SCRIPT_DIR, "src/services", isProject ? "project-install.ts" : "global-install.ts");
	const deployArgs = argv.filter((arg) => arg !== "--skip-env");
	const result = Bun.spawnSync({
		cmd: [process.execPath, engine, ...deployArgs],
		stdio: ["inherit", "inherit", "inherit"],
	});
	if (!result.success) process.exit(result.exitCode);
}

async function main(): Promise<void> {
	const argv = process.argv.slice(2);
	runDeployEngine(argv);
	// The configuration stage works on PATHS, which are all global (~/.cursor).
	// `--project` deploys into <project>/.cursor and wires its own hooks, so it
	// must not fall through to the global setup wizard.
	if (argv.includes("--dry-run") || argv.includes("--uninstall") || argv.includes("--project")) return;
	await runSetup(PATHS, argv.includes("--skip-env"));
}

main().catch((e) => {
	p.log.error(e.message);
	process.exit(1);
});
