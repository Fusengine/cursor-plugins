/**
 * Global installer inventory.
 * @description SRP: read `marketplace.json` and resolve it to real plugin
 * source directories, only.
 */
import path from "node:path";
import { resolveMarketplacePlugins } from "./marketplace-sources";
import { readGlobalJson } from "./global-paths";
import type { GlobalPluginSource } from "../interfaces/global-install";

/** Marketplace manifest shape read from `.cursor-plugin/marketplace.json`. */
interface MarketplaceManifest {
	plugins: unknown[];
}

/**
 * Read the marketplace manifest and resolve its declared plugins to their
 * real on-disk source directories.
 * @param sourceRoot - Repository root (or the test-injected source root override).
 */
export function inventory(sourceRoot: string): GlobalPluginSource[] {
	const market = readGlobalJson<MarketplaceManifest>(path.join(sourceRoot, ".cursor-plugin", "marketplace.json"));
	if (!Array.isArray(market.plugins) || market.plugins.length !== 25) {
		throw new Error("global install requires exactly 25 marketplace plugins");
	}
	return resolveMarketplacePlugins(sourceRoot, market);
}
