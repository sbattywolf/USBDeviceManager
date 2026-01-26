Scripts/tools audit
=====================

Summary
-------
This document lists discovered scripts and tools under `scripts/` and `scripts/tools/` and marks candidates for cleanup or archiving. Review and update before removing anything.

Discovered files (partial)
--------------------------

- scripts/apply-user-token-and-download-v2.ps1
- scripts/apply-user-token-and-download.ps1
- scripts/ci-monitor.ps1
- scripts/ci-analyze.py
- scripts/download_artifacts.py
- scripts/generate-final-report-html.py
- scripts/generate-integration-report.ps1
- scripts/fetch-gh-token.ps1
- scripts/extract-failures.ps1
- scripts/ensure-server-stopped.ps1
- scripts/enrich-summary.py
- scripts/enrich-failures.py
- scripts/monitor-ci.ps1
- scripts/sanitize-repo.ps1
- scripts/start-and-run-tests.ps1
- scripts/run-integration-noninteractive.ps1
- scripts/run-gui.ps1
- scripts/run-agent.ps1
- scripts/ci/* (many helpers)
- scripts/tools/* (small utility helpers)

Recommendations
---------------
- Create a `scripts/README.md` describing remaining scripts and intended usage.
- Archive clearly-named one-off scripts (e.g., `download-run-21334129688.ps1`) into `scripts/archive/`.
- Consolidate CI triage helpers under `scripts/ci/` and mark `scripts/tools/` as utilities.
- Add a follow-up TODO to review each script for obsolescence and add unit tests where appropriate.

Next action
-----------
If you want, I can:
- Move obvious one-offs into `scripts/archive/` in a focused PR.
- Create `scripts/README.md` listing common workflows and usage examples.
- Open a follow-up ticket (TODO list entry) to review each script.

