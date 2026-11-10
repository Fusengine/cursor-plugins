# Decisions

Owner decisions for this repository, dated. Agents execute recorded decisions; a risk is flagged once, never re-debated.

- **2026-11-11 — Copyright holder.** Owner, asked who the legal holder is: « Fusengine Sàrl ». Every `Copyright (c) … Fusengine` line reads `Copyright (c) 2026 Fusengine Sàrl` (UTF-8); `author` fields and prose are unchanged.
- **2026-11-11 — License.** Owner: « met les licences sous harnes kimi codex claude cursor ». The repository ships the MIT License text of `@fusengine/harness` in a root `LICENSE` (holder per the entry above), so any copy must keep the Fusengine Sàrl copyright notice. Plugin manifests and `marketplace.json` already declare `"license": "MIT"`; no new manifest field is added.
- **2026-11-11 — Harness minimum 0.1.116.** Owner: « fais corrigé ». `HARNESS_MIN` is 0.1.116 in every `hook.sh`, so installs at 0.1.115 upgrade at the next session start (0.1.116 fixes the false shell-redirect CONFIRM on `( … 2>&1) || true`).
- **2026-11-10 — Releases.** Release only on the owner's go typed in this repository's lead session; a relayed message is never a release go.
