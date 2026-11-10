/**
 * Setup runner service
 * Single Responsibility: Orchestrate plugin setup steps
 */
import { dirname, join } from "node:path";
import * as p from "@clack/prompts";
import type { SetupPaths } from "../interfaces/setup";
import { copyLoaderTree } from "../utils/fs-helpers";
import { installBrowserBinary } from "./browser-binary";
import { setHarnessRefs } from "./harness-env";
import { resolveHomeInHooks } from "./harness-path-resolver";
import { promptHarnessGates } from "./harness-gates";
import { vendorHarness } from "./harness-vendor";
import { promptHarnessTuning } from "./harness-tuning";
import { promptEnforceTtl } from "./enforce-ttl";
import { promptSolidMaxLines } from "./solid-lines";
import { configureShell } from "./env-manager";
import { configureMcpServers } from "./mcp-setup";
import { promptPerfEnv } from "./perf-env";
import { purgeFuseEnvVars } from "./settings-env-purge";
import {
	backupSettings, configureDefaults, configureHooks, enableAgentTeams,
	isAgentTeamsEnabled, loadSettings, promptLanguage, saveSettings,
} from "./settings-manager";
import { installDeps, scanAndPrepare, setupStatusline } from "./setup-plugins";

/** Run the complete setup process */
export async function runSetup(
	paths: SetupPaths,
	skipEnv: boolean,
): Promise<void> {
	p.intro("Fusengine Plugins Setup");

	const pluginsDir = paths.pluginsDir;
	// Copy the loader WITH its `src/` tree: hooks-loader.ts imports five relative
	// modules (interfaces/hooks, deps-targets, ensure-deps, hook-executor,
	// plugin-scanner). Copying the single file leaves it unrunnable — every hook
	// wired in ~/.cursor/hooks.json would die on "Cannot find module".
	const loaderRoot = join(paths.marketplace, ".fusengine-global/scripts");
	const loaderDest = join(loaderRoot, "hooks-loader.ts");
	await copyLoaderTree(dirname(paths.loaderSrc), loaderRoot);

	await scanAndPrepare(pluginsDir);

	const selectedLanguage = await promptLanguage();

	const s = p.spinner();
	s.start("Configuring hooks loader...");
	backupSettings(paths.settings);
	let settings = await loadSettings(paths.settings);
	settings = purgeFuseEnvVars(settings);
	settings = configureDefaults(settings, selectedLanguage);
	const wired = configureHooks(loaderDest);
	s.stop(`Hooks loader configured (${wired} events in ~/.cursor/hooks.json)`);

	// Global instructions are NOT written here: the deploy engine already installs
	// ~/.cursor/rules/fuse-global.mdc (frontmatter `alwaysApply: true`, hashed in
	// receipt.json). Copying CLAUDE.md.template on top would add a second, inert
	// file — it carries no .mdc frontmatter, so Cursor would apply it only on an
	// explicit @mention, and its body is Claude Code's prompt, not Cursor's.
	// `installClaudeMd` stays available for the project scope.
	await installDeps(pluginsDir);

	// Shared harness: every run moves it to the latest published release through
	// hook.sh's staged install + atomic switch (the same routine the wrappers use
	// at session start), never an in-place replacement. Fail-open.
	const vendorSpinner = p.spinner();
	vendorSpinner.start("Refreshing shared @fusengine/harness to latest...");
	const vendored = await vendorHarness({
		hookScript: paths.harnessHookScript,
		warn: (message) => p.log.warn(message),
		controlRoot: join(paths.marketplace, ".fusengine-global"),
	});
	vendorSpinner.stop(`Shared harness: ${vendored}`);
	if (vendored === "failed") {
		p.log.warn("Harness refresh failed — the hook wrappers keep the vendored copy (or self-heal).");
	}

	const homeSpinner = p.spinner();
	homeSpinner.start("Resolving $HOME in hook paths...");
	const resolved = await resolveHomeInHooks(pluginsDir);
	homeSpinner.stop(`${resolved} hooks.json paths resolved`);

	settings = await setupStatusline(pluginsDir, settings);
	settings = setHarnessRefs(settings, pluginsDir);

	if (isAgentTeamsEnabled(settings)) {
		p.log.info(
			"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS already recorded in the Fusengine settings store (bookkeeping only, no effect on Cursor — its multi-agent feature is Subagents, on by default, no flag: https://cursor.com/docs/subagents)",
		);
	} else {
		settings = enableAgentTeams(settings);
		p.log.info(
			"Recorded CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS in the Fusengine settings store (bookkeeping only, no effect on Cursor — its multi-agent feature is Subagents, on by default, no flag: https://cursor.com/docs/subagents)",
		);
	}

	settings = await promptPerfEnv(settings);
	if (!skipEnv) {
		await configureShell();
		settings = await promptSolidMaxLines(settings);
		settings = await promptEnforceTtl(settings);
		settings = await promptHarnessGates(settings);
		settings = await promptHarnessTuning(settings);
		const selectedMcp = await configureMcpServers();
		if (selectedMcp.includes("fuse-browser")) {
			await installBrowserBinary();
		}
	}

	await saveSettings(paths.settings, settings);

	p.outro("Setup complete! Reload the Cursor window to apply.");
}
