/**
 * Fail-open shell-script runner — built-ins/Bun-global only, like
 * bun-install-runner.ts.
 */
import type { ScriptRunFn } from "../interfaces/harness-vendor";

/**
 * Run `sh <script> ...args` with `env` merged over the current environment,
 * hard-killing it after `timeoutMs`. Never throws on timeout/non-zero exit: the
 * exit code is returned together with the trimmed stderr text.
 *
 * @param script - Absolute path of the shell script
 * @param args - Arguments passed to the script
 * @param env - Extra environment variables
 * @param timeoutMs - Hard kill timeout in milliseconds
 * @returns Exit code (non-zero when killed) and captured stderr
 */
export const runScript: ScriptRunFn = async (script, args, env, timeoutMs) => {
	const proc = Bun.spawn(["sh", script, ...args], {
		env: { ...process.env, ...env },
		stdin: "ignore",
		stdout: "ignore",
		stderr: "pipe",
		timeout: timeoutMs,
		killSignal: "SIGKILL",
	});
	const [stderr, code] = await Promise.all([new Response(proc.stderr).text(), proc.exited]);
	return { code, stderr: stderr.trim() };
};
