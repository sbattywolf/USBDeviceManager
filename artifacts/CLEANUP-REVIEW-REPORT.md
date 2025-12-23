# Cleanup Review Report

Date: 2025-12-23

Summary
- Created branch `cleanup/remove-obsolete` that removed legacy solution files and the `server/SimRacingDashboard.Tests` sources. A PR compare page is available for review.
- This report lists remaining cleanup candidates, large committed artifacts, references to personal/local paths, and a recommended plan to complete the repository cleanup and documentation update.

Scan highlights
- Largest files observed (top candidates are build outputs under `server/*/bin`):
  - many compiled assemblies and native runtime files (e_sqlite3, Microsoft.CodeAnalysis.*, EntityFrameworkCore, etc.) present under `server/USBDeviceManager.Tests/bin` and `server/USBDeviceManager/bin` — these are build artifacts and should not be committed.
- Tracked filenames referencing removed items: none remaining (legacy solutions removed and docs updated).
- Files containing local user paths: `scripts/sanitize-repo.ps1` (contains `C:\Users\` occurrences). There may be additional occurrences inside generated artifacts (TRX, obj) which are already partially sanitized but should be re-scanned before final merge.
- Tracked `bin/` and `obj/` files: scan showed many build output files present in repository folders (these are likely committed). Recommend removing committed `bin/` and `obj/` from tracked files and adding `.gitignore` rules.
- TODO/FIXME occurrences: multiple TODO comments across controllers and front-end components indicating in-progress work (these should be triaged into the overall refactor plan).

Recommendations (priority order)
1) Remove committed build outputs
   - Remove `**/bin/` and `**/obj/` from the repo index (git rm -r --cached) where present, add `.gitignore` entries, commit in a dedicated cleanup PR. This reduces repo size and avoids leaking local paths inside generated files.
   - Example steps (already performed in parts):
     - Create branch `cleanup/remove-build-artifacts` (or reuse existing), run `git rm -r --cached **/bin **/obj`, add `.gitignore` entries, commit & push, open PR.

2) Sanitize remaining contained personal/local paths
   - Re-run a targeted search for `C:\Users\`, computer names, temp paths and TRX contents in committed files (including `server/*/obj`, `artifacts/`, and any `.trx` files). Replace with `REDACTED` placeholders or remove sensitive sections.

3) Consolidate/Remove legacy solutions and projects (done)
   - `USBDeviceManager.fixed.sln`, `Device-Sentinel.sln`, and `server/SimRacingDashboard.Tests` were removed in `cleanup/remove-obsolete`. Verify CI and docs reference the canonical `USBDeviceManager.sln`.

4) Run full static analysis and triage
   - Run `dotnet build` and `dotnet test` on the canonical solution (`USBDeviceManager.sln`) and collect analyzer output.
   - Create a prioritized list of warnings (SA*, CS*) and produce individual small PRs to fix groups (e.g., public API docs, SA1137 indentation, SA1611 param docs).

5) Code cleanup & refactor plan
   - Produce an inventory of duplicate or dead files (helpers, legacy scripts under `shared/` or `agent/shared`).
   - Propose small PR batches:
     - Batch A: Remove build artifacts + ignore rules (low risk).
     - Batch B: Delete legacy solutions and tests (already created: `cleanup/remove-obsolete`).
     - Batch C: Documentation updates (README, docs/*, SESSION_SUMMARY) to reflect final structure.
     - Batch D: Static analysis fixes grouped by rule class.

6) Documentation sweep
   - After code cleanup, update `README.md`, `docs/*`, and `SESSION_SUMMARY_NEXT.md` to reflect the new canonical layout and how to build/test locally.

Risks & notes
- Some directories prevented content scanning due to filesystem access patterns in this environment; please re-run full grep in CI or locally if any paths are intentionally excluded by permissions.
- If you need to fully remove sensitive data from history, plan a separate history-scrub step using `git filter-repo` and coordinate with collaborators.

Suggested next action (I can do automatically)
1. Run a focused removal PR to untrack all `bin/` and `obj/` contents and add `.gitignore` (I can create and open PR `cleanup/remove-build-artifacts` if you confirm).
2. Re-scan committed files for `C:\Users\` and TRX contents and apply redactions in a small PR.

Artifacts
- PR for removed legacy files: https://github.com/sbattywolf/USBDeviceManager/pull/new/cleanup/remove-obsolete

If you confirm, I'll create the `bin/obj` removal PR next (safe, low-risk). Otherwise I will run a deeper repo scan to enumerate duplicates and refactor candidates and produce a prioritized task list.

End of report
