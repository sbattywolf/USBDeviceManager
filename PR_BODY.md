Title: chore(docs): normalize product name to “USB Device Manager” and tidy repo

Why
- Improve documentation consistency and remove machine-specific/personal helper scripts.

What changed
- Docs & naming:
  - Normalized product-name mentions to “USB Device Manager” in docs and session summary.
  - Updated README links to point to `docs/shared/*`.
- Test fixtures:
  - Moved integration test helpers into `agent/SimRacingAgent.Tests/Integration/Helpers/` and updated tests to reference the new path.
  - Removed legacy `shared/test-utils` directory.
- Cleanup:
  - Removed personal git/SSH helper scripts under `server/USBDeviceManager/scripts`.
  - Removed legacy `shared/docs` duplicates (consolidated under `docs/shared`).
- Tooling:
  - Added/verified `ci/run-tests.ps1` and `scripts/sanitize-repo.ps1` helpers.
- Minor code comment updates reflecting product-name change.

Files changed (high level)
- docs/*, SESSION_SUMMARY.md, README.md, server/USBDeviceManager/Controllers/CompatController.cs
- moved: agent/SimRacingAgent.Tests/Integration/Helpers/test-dashboard-server.ps1(.js)
- deleted: shared/* (legacy docs and test utils)

Testing
- Run `./ci/run-tests.ps1` to run server and agent tests where available.

Notes
- Removed legacy solution files `Device-Sentinel.sln` and `USBDeviceManager.fixed.sln` (cleaned in `cleanup/remove-obsolete` branch).
- Added a follow-up TODO to consider history-scrub (`git filter-repo`) if you want to remove personal paths from history.
