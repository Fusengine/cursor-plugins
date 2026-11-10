/**
 * Shared-harness vendoring interfaces.
 * @description SRP: types for the installer's `@fusengine/harness` refresh only.
 */

/** Outcome of one vendoring run. `failed` is fail-open: the installer keeps going. */
export type HarnessVendorStatus = "installed" | "updated" | "skipped" | "failed";

/** Injectable `bun` runner — returns the exit code; tests fake it (no network). */
export type BunRunFn = (cwd: string, args: string[], timeoutMs: number) => Promise<number>;

/**
 * Injectable runner of a hook.sh invocation: `sh <script> ...args` with extra
 * environment variables. Returns the exit code and captured stderr; tests fake
 * it (no network).
 */
export type ScriptRunFn = (
	script: string,
	args: string[],
	env: Record<string, string>,
	timeoutMs: number,
) => Promise<{ code: number; stderr: string }>;

/** Inputs of {@link vendorHarness}. */
export interface HarnessVendorOptions {
	/**
	 * Absolute path of a repo `scripts/hook.sh`. It owns the staged install and
	 * the atomic switch (`--install-harness`), so the installer never carries a
	 * second copy of that logic.
	 */
	hookScript: string;
	/** Absolute shared install dir (`~/.cursor/.fusengine-global`). */
	controlRoot: string;
	/** Script runner; defaults to a real `sh`. */
	run?: ScriptRunFn;
	/** Receives hook.sh's stderr line when the install fails (shown in the installer output). */
	warn?: (message: string) => void;
}
