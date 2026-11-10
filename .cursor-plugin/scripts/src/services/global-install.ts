/**
 * User-global Cursor plugin installer.
 * @description SRP: orchestrate install/uninstall of the shared
 * `~/.cursor/plugins/local` snapshot and its sibling rule/receipt files.
 * All writes stay below the resolved user home. Running this module (as the
 * former `global-install.mjs` did) parses `process.argv` and executes the
 * install or uninstall flow immediately.
 */
import fs from "node:fs";
import path from "node:path";
import { assertNotSymlink, withProjectLock } from "./project-files";
import { hashDirectory, hashFile } from "./global-artifacts";
import { inventory } from "./global-inventory";
import { resolveGlobalPaths } from "./global-paths";
import { GLOBAL_CONTROL_MARKER_CONTENT, preflightOwned, readGlobalReceipt } from "./global-receipt";
import { commitGlobalSnapshot, recoverGlobalTransaction } from "./global-transaction";
import type { GlobalOptions, GlobalPaths, GlobalReceipt } from "../interfaces/global-install";

const paths: GlobalPaths = resolveGlobalPaths(import.meta.dir);

/** Parse `--dry-run` / `--uninstall` / `--help` from the given CLI arguments. */
export function parseGlobalOptions(argv: string[]): GlobalOptions {
	const parsed: GlobalOptions = { dryRun: false, uninstall: false };
	for (const argument of argv) {
		if (argument === "--dry-run") parsed.dryRun = true;
		else if (argument === "--uninstall") parsed.uninstall = true;
		else if (argument === "--help" || argument === "-h") {
			process.stdout.write(
				"Usage: install.sh [--dry-run] [--uninstall]\n       install.sh --project <path> [--dry-run] [--uninstall]\n",
			);
			process.exit(0);
		} else throw new Error(`unknown global option: ${argument}`);
	}
	return parsed;
}

const options: GlobalOptions = parseGlobalOptions(process.argv.slice(2));

/** Reject a symlink anywhere along the global control paths, or under one plugin name. */
function validatePathChain(pluginNames: string[] = []): void {
	const targets = [
		paths.cursorRoot,
		paths.pluginsRoot,
		paths.localRoot,
		paths.rulesRoot,
		paths.rulePath,
		paths.controlRoot,
		paths.receiptPath,
		paths.controlMarker,
	];
	for (const target of targets) assertNotSymlink(target);
	for (const name of pluginNames) assertNotSymlink(path.join(paths.localRoot, name));
}

/** Snapshot `plugins/local` (or an empty directory) into a fresh stage for this nonce. */
function stageLocal(nonce: string): string {
	const stage = path.join(paths.pluginsRoot, `.fusengine-local-stage-${nonce}`);
	fs.mkdirSync(paths.pluginsRoot, { recursive: true });
	if (fs.existsSync(paths.localRoot)) fs.cpSync(paths.localRoot, stage, { recursive: true });
	else fs.mkdirSync(stage);
	return stage;
}

/** Install (or dry-run preview) the 26 marketplace plugins and the global rule. */
function installGlobal(): void {
	recoverGlobalTransaction(paths.cursorRoot);
	const plugins = inventory(paths.sourceRoot);
	const rulesPlugin = plugins.find((plugin) => plugin.name === "fuse-rules");
	if (!rulesPlugin) throw new Error("global install requires fuse-rules");
	const ruleSource = path.join(rulesPlugin.source, "user-rules", "fuse-global.mdc");
	validatePathChain(plugins.map((plugin) => plugin.name));
	const previous = readGlobalReceipt(paths);
	preflightOwned(paths, previous, plugins);
	const rule = fs.readFileSync(ruleSource);
	if (options.dryRun) {
		process.stdout.write(`Would install 26 plugins under ${paths.localRoot}\nWould write ${paths.rulePath}\nDry run: nothing written.\n`);
		return;
	}
	const nonce = `${process.pid}-${Date.now()}`;
	const stage = stageLocal(nonce);
	try {
		const hashes: Record<string, string> = {};
		for (const plugin of plugins) {
			const target = path.join(stage, plugin.name);
			if (fs.existsSync(target)) fs.rmSync(target, { recursive: true });
			fs.cpSync(plugin.source, target, { recursive: true });
			hashes[plugin.name] = hashDirectory(target);
		}
		const receipt: GlobalReceipt = { version: 1, plugins: hashes, ruleHash: hashFile(ruleSource) };
		const receiptBuffer = Buffer.from(`${JSON.stringify(receipt, null, 2)}\n`);
		commitGlobalSnapshot({
			cursorRoot: paths.cursorRoot,
			stageRoot: stage,
			finalFiles: [
				{ path: paths.rulePath, content: rule },
				{ path: paths.receiptPath, content: receiptBuffer },
				{ path: paths.controlMarker, content: GLOBAL_CONTROL_MARKER_CONTENT },
			],
		});
	} catch (error) {
		if (fs.existsSync(stage)) fs.rmSync(stage, { recursive: true });
		throw error;
	}
	process.stdout.write(`Installed 26 user-global plugins in ${paths.localRoot}\nReload the Cursor window to activate them.\n`);
}

/** Uninstall (or dry-run preview) only the artifacts still matching the receipt. */
function uninstallGlobal(): void {
	recoverGlobalTransaction(paths.cursorRoot);
	validatePathChain();
	const receipt = readGlobalReceipt(paths);
	if (!receipt) throw new Error(`no managed global installation at ${paths.controlRoot}`);
	if (options.dryRun) {
		process.stdout.write(`Would remove only intact Fusengine global plugins and rule under ${paths.cursorRoot}\nDry run: nothing written.\n`);
		return;
	}
	const nonce = `${process.pid}-${Date.now()}`;
	const stage = stageLocal(nonce);
	try {
		for (const [name, expectedHash] of Object.entries(receipt.plugins)) {
			if (path.basename(name) !== name) throw new Error(`unsafe receipt plugin name: ${name}`);
			const active = path.join(paths.localRoot, name);
			if (!fs.existsSync(active)) continue;
			if (hashDirectory(active) === expectedHash) fs.rmSync(path.join(stage, name), { recursive: true });
			else process.stderr.write(`warning: preserved modified global plugin ${active}\n`);
		}
		const removeRule = fs.existsSync(paths.rulePath) && hashFile(paths.rulePath) === receipt.ruleHash;
		if (fs.existsSync(paths.rulePath) && !removeRule) {
			process.stderr.write(`warning: preserved modified global rule ${paths.rulePath}\n`);
		}
		const finalFiles = [
			{ path: paths.receiptPath, content: null },
			{ path: paths.controlMarker, content: null },
		];
		if (removeRule) finalFiles.push({ path: paths.rulePath, content: null });
		commitGlobalSnapshot({ cursorRoot: paths.cursorRoot, stageRoot: stage, finalFiles });
		// The control root is ours in full: readGlobalReceipt refused to go any
		// further unless the ownership marker matched, and every install rewrites
		// the whole tree anyway (copyLoaderTree removes it first). So take it down
		// entirely — a non-recursive rmdir with a swallowed error left the deployed
		// loader, its src/ tree and the harness node_modules the wrapper installs
		// there behind forever, with no code path able to reclaim them.
		const stat = fs.lstatSync(paths.controlRoot);
		if (stat.isSymbolicLink() || !stat.isDirectory()) {
			throw new Error(`expected real directory: ${paths.controlRoot}`);
		}
		fs.rmSync(paths.controlRoot, { recursive: true, force: true });
	} catch (error) {
		if (fs.existsSync(stage)) fs.rmSync(stage, { recursive: true });
		throw error;
	}
	process.stdout.write(`Uninstalled intact user-global Fusengine artifacts from ${paths.cursorRoot}\n`);
}

try {
	validatePathChain();
	if (options.dryRun) (options.uninstall ? uninstallGlobal : installGlobal)();
	else withProjectLock(paths.cursorRoot, options.uninstall ? uninstallGlobal : installGlobal);
} catch (error) {
	process.stderr.write(`error: ${(error as Error).message}\n`);
	process.exit(1);
}
