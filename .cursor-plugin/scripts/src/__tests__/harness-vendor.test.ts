/**
 * Tests for vendorHarness: the installer delegates the staged install to
 * `hook.sh --install-harness`, targeting the given control root, and never
 * throws. No script is ever executed — every test injects a fake runner.
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ScriptRunFn } from "../interfaces/harness-vendor";
import { vendorHarness } from "../services/harness-vendor";

let root: string;
let hookScript: string;
let controlRoot: string;

type Call = { script: string; args: string[]; env: Record<string, string> };

/** Fake runner recording every call and answering with a scripted exit code. */
function fakeRun(code: number): { run: ScriptRunFn; calls: Call[] } {
	const calls: Call[] = [];
	const run: ScriptRunFn = async (script, args, env) => {
		calls.push({ script, args, env });
		return { code, stderr: code === 0 ? "" : "fusengine harness: upgrade failed (installed 0.1.110)" };
	};
	return { run, calls };
}

beforeEach(() => {
	root = mkdtempSync(join(tmpdir(), "fusengine-vendor-"));
	hookScript = join(root, "hook.sh");
	controlRoot = join(root, ".fusengine-global");
	writeFileSync(hookScript, "#!/bin/sh\n");
});

afterEach(() => rmSync(root, { recursive: true, force: true }));

describe("vendorHarness", () => {
	test("fresh machine: runs hook.sh --install-harness against the control root", async () => {
		const { run, calls } = fakeRun(0);
		expect(await vendorHarness({ hookScript, controlRoot, run })).toBe("installed");
		expect(calls).toEqual([
			{ script: hookScript, args: ["--install-harness"], env: { FUSE_HARNESS_ROOT: controlRoot } },
		]);
	});

	test("existing versioned install: reported as updated", async () => {
		mkdirSync(controlRoot, { recursive: true });
		writeFileSync(join(controlRoot, "current"), "0.1.110\n");
		const { run } = fakeRun(0);
		expect(await vendorHarness({ hookScript, controlRoot, run })).toBe("updated");
	});

	test("existing legacy node_modules install: reported as updated", async () => {
		const bin = join(controlRoot, "node_modules/@fusengine/harness/dist/cli");
		mkdirSync(bin, { recursive: true });
		writeFileSync(join(bin, "bin.mjs"), "// old");
		const { run } = fakeRun(0);
		expect(await vendorHarness({ hookScript, controlRoot, run })).toBe("updated");
	});

	test("script exits non-zero: reports failed, does not throw", async () => {
		const { run } = fakeRun(1);
		expect(await vendorHarness({ hookScript, controlRoot, run })).toBe("failed");
	});

	test("script fails: its stderr line is surfaced through warn", async () => {
		const { run } = fakeRun(1);
		const messages: string[] = [];
		await vendorHarness({ hookScript, controlRoot, run, warn: (m) => messages.push(m) });
		expect(messages).toEqual(["fusengine harness: upgrade failed (installed 0.1.110)"]);
	});

	test("script succeeds: warn is never called", async () => {
		const { run } = fakeRun(0);
		const messages: string[] = [];
		await vendorHarness({ hookScript, controlRoot, run, warn: (m) => messages.push(m) });
		expect(messages).toEqual([]);
	});

	test("runner throws: fail-open, reports failed", async () => {
		const run: ScriptRunFn = async () => {
			throw new Error("spawn failed");
		};
		expect(await vendorHarness({ hookScript, controlRoot, run })).toBe("failed");
	});

	test("missing hook.sh: skipped, runner never called", async () => {
		rmSync(hookScript);
		const { run, calls } = fakeRun(0);
		expect(await vendorHarness({ hookScript, controlRoot, run })).toBe("skipped");
		expect(calls).toEqual([]);
	});
});
