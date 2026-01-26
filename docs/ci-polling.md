CI Polling and Activity Log

This repository includes a robust PowerShell poller used to watch GitHub Actions workflow runs, download artifacts when they complete, and keep a persisted activity log for traceability.

Files added:
- `scripts/gh-poll-run.ps1` — Poller script. Usage:

```powershell
# basic usage (defaults to branch 'ci/temp-with-workflows')
.\scripts\gh-poll-run.ps1 -WorkflowFile ci.yml -Branch ci/temp-with-workflows

# customize timeout/interval
.\scripts\gh-poll-run.ps1 -WorkflowFile ci.yml -Branch ci/temp-with-workflows -TimeoutMinutes 60 -IntervalSeconds 10
```

Optional behavior:
- `-RequireActiveRun` (default true): when set, the poller makes a quick pre-check and will exit immediately if there are no active runs (statuses `queued`, `in_progress`, or `requested`) for the given workflow and branch. Set `-RequireActiveRun:$false` to preserve the original behavior of waiting for new runs to appear.

CI Polling and Activity Log

This repository includes a robust PowerShell poller used to watch GitHub Actions workflow runs, download artifacts when they complete, and keep a persisted activity log for traceability.

Files added:
- `scripts/gh-poll-run.ps1` — Poller script. Usage:

```powershell
# basic usage (defaults to branch 'ci/temp-with-workflows')
.\scripts\gh-poll-run.ps1 -WorkflowFile ci.yml -Branch ci/temp-with-workflows

# customize timeout/interval
.\scripts\gh-poll-run.ps1 -WorkflowFile ci.yml -Branch ci/temp-with-workflows -TimeoutMinutes 60 -IntervalSeconds 10
```

Behavior:
- Queries `gh run list` for the specified `--workflow` and branch.
- When a run reaches `completed`/`failure`/`cancelled`, it downloads artifacts to `artifacts/ci-run-<runId>`.
- Appends status lines to `docs/ci-activity-log.md` for persistent tracing.

Prerequisites:
- `gh` CLI installed and authenticated (must have repo access).
- PowerShell 7+ recommended on non-Windows platforms.

Notes:
- The poller is intentionally conservative: it will timeout after `-TimeoutMinutes` (default 40).
- Use the produced `artifacts/ci-run-<id>/ci-run-summary.json` for a small machine-readable summary.
