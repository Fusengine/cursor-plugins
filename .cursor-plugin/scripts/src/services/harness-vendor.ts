/**
 * Shared-harness vendoring: move `~/.cursor/.fusengine-global` to the latest
 * published `@fusengine/harness` on every installer run.
 * @description SRP: delegate to `hook.sh --install-harness`, the single
 * implementation of the staged install + atomic switch (the hook wrappers use
 * the same routine to self-heal and to upgrade at session start). The live
 * tree is never modified in place — an in-place `bun update` leaves `bin.mjs`
 * and the hashed chunks absent for a few ms, which crashes concurrent hooks.
 */
import { existsSync } from "node:fs";
import { join } from "node:path";
import type {
	HarnessVendorOptions,
	HarnessVendorStatus,
} from "../interfaces/harness-vendor";
import { runScript } from "../utils/script-runner";

const HARNESS_LEGACY_BIN = "node_modules/@fusengine/harness/dist/cli/bin.mjs";
const VENDOR_TIMEOUT_MS = 180_000;

/**
 * Refresh the shared harness to the latest release through hook.sh. Fail-open:
 * never throws, a failure only returns `"failed"` and the previous version
 * (if any) stays live.
 *
 * @param options - hook.sh path, control root and optional script runner
 * @returns `installed` (first install), `updated` (an install existed),
 *   `skipped` (hook.sh missing) or `failed`
 */
export async function vendorHarness(options: HarnessVendorOptions): Promise<HarnessVendorStatus> {
	const { hookScript, controlRoot, run = runScript, warn } = options;
	if (!existsSync(hookScript)) return "skipped";
	try {
		const hadInstall =
			existsSync(join(controlRoot, "current")) || existsSync(join(controlRoot, HARNESS_LEGACY_BIN));
		const { code, stderr } = await run(
			hookScript,
			["--install-harness"],
			{ FUSE_HARNESS_ROOT: controlRoot },
			VENDOR_TIMEOUT_MS,
		);
		if (code !== 0) {
			warn?.(stderr || `hook.sh --install-harness exited ${code}`);
			return "failed";
		}
		return hadInstall ? "updated" : "installed";
	} catch {
		return "failed";
	}
}
