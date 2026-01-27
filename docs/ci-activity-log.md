# CI Activity Log

This file is appended by `scripts/gh-poll-run.ps1` to record poller activity and run summaries.

- 2026-01-26 21:38:59Z - Started poller for workflow='ci.yml' branch='ci/temp-with-workflows' timeout=60m interval=8s
- 2026-01-26 21:38:59Z - No runs found yet for workflow='ci.yml' branch='ci/temp-with-workflows'
- 2026-01-26 21:39:07Z - No runs found yet for workflow='ci.yml' branch='ci/temp-with-workflows'
- 2026-01-26 21:39:15Z - No runs found yet for workflow='ci.yml' branch='ci/temp-with-workflows'
- 2026-01-26 21:39:23Z - No runs found yet for workflow='ci.yml' branch='ci/temp-with-workflows'
- 2026-01-26 21:39:31Z - No runs found yet for workflow='ci.yml' branch='ci/temp-with-workflows'
- 2026-01-26 21:39:39Z - No runs found yet for workflow='ci.yml' branch='ci/temp-with-workflows'
- 2026-01-26 21:39:47Z - No runs found yet for workflow='ci.yml' branch='ci/temp-with-workflows'
 - 2026-01-26 21:45:00Z - Poller updated: pre-check added; will exit early if no active runs (queued/in_progress/requested) — scripts/gh-poll-run.ps1 updated.
- 2026-01-26 21:52:44Z - Started poller for workflow='ci.yml' branch='chore/stabilize-tests' timeout=60m interval=10s requireActiveRun=False
- 2026-01-26 21:52:46Z - Found run #215 status=completed conclusion=startup_failure
- 2026-01-26 21:52:46Z - Run #215 finished with conclusion='startup_failure'. Downloading artifacts...
- 2026-01-26 21:52:46Z - unknown flag: --archive
- 2026-01-26 21:52:46Z - System.Management.Automation.RemoteException
- 2026-01-26 21:52:46Z - Usage:  gh run download [<run-id>] [flags]
- 2026-01-26 21:52:46Z - System.Management.Automation.RemoteException
- 2026-01-26 21:52:46Z - Flags:
- 2026-01-26 21:52:46Z -   -D, --dir string            The directory to download artifacts into (default ".")
- 2026-01-26 21:52:46Z -   -n, --name stringArray      Download artifacts that match any of the given names
- 2026-01-26 21:52:46Z -   -p, --pattern stringArray   Download artifacts that match a glob pattern
- 2026-01-26 21:52:46Z -   
- 2026-01-26 21:52:46Z - Artifacts downloaded to artifacts\ci-run-215
- 2026-01-26 21:52:46Z - Wrote summary to artifacts\ci-run-215\ci-run-summary.json
- 2026-01-26 21:53:07Z - Started poller for workflow='ci.yml' branch='chore/stabilize-tests' timeout=60m interval=10s requireActiveRun=False
- 2026-01-26 21:53:09Z - Found run #215 status=completed conclusion=startup_failure
- 2026-01-26 21:53:09Z - Run #215 finished with conclusion='startup_failure'. Downloading artifacts...
- 2026-01-26 21:53:09Z - error fetching artifacts: HTTP 404: Not Found (https://api.github.com/repos/Sbatta/USBDeviceManager/actions/runs/215/artifacts?per_page=100)
- 2026-01-26 21:53:09Z - Artifacts downloaded to artifacts\ci-run-215
- 2026-01-26 21:53:09Z - Wrote summary to artifacts\ci-run-215\ci-run-summary.json
- 2026-01-26 21:56:00Z - Retrieval attempted: `designer/mockups` not found; retrieval skipped and task blocked.

