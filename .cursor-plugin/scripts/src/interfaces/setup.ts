/**
 * Setup interfaces
 */

/** Paths configuration for setup process */
export interface SetupPaths {
	settings: string;
	marketplace: string;
	loaderSrc: string;
	cursorMdSrc: string;
	cursorMdDest: string;
	/**
	 * Directory holding the deployed plugins. Explicit rather than derived from
	 * `marketplace`: Cursor lays them out flat under `~/.cursor/plugins/local`,
	 * with no intermediate `plugins/` level like Claude Code's marketplace.
	 */
	pluginsDir: string;
	/**
	 * Repo `scripts/hook.sh` that owns the staged harness install and atomic
	 * switch (`--install-harness`); run on every install to refresh the harness.
	 */
	harnessHookScript: string;
}
