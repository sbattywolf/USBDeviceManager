CI: preserve per-job TRX into artifacts/test-results and upload

Summary
-------
This PR updates the test-run reusable workflows to ensure per-job `.trx` results are written to a canonical location under `artifacts/test-results/<job>/<runner.os>/` and uploaded as stable per-job artifacts. This makes per-test TRX files available to the final aggregation job and improves triage (local vs CI) comparisons.

What changed
------------
- `unit-tests-reusable.yml`: write `dotnet test` results into `artifacts/test-results/unit/${{ runner.os }}` and upload as `test-results-unit-${{ runner.os }}`.
- `integration-analysis-reusable.yml`: copy any generated `*.trx` into `artifacts/test-results/integration/${{ runner.os }}` and upload as `test-results-integration-${{ runner.os }}`.
- `e2e-tests-reusable.yml`: copy any generated `*.trx` into `artifacts/test-results/e2e/${{ runner.os }}` and upload as `test-results-e2e-${{ runner.os }}`.

Why
---
- The repository's report generator and analyzers expect an aggregated `artifacts/test-results/**/all-tests.trx` and enriched reports referencing `artifacts/test-results/all-tests.trx`. Past runs emitted TRX but they were not consistently uploaded/available in the run artifacts. This change makes TRX preservation explicit and stable.

Testing / Validation
--------------------
1. After merging, trigger `ci.yml` via `workflow_dispatch` (or use the GH UI) with `collect_ci_logs=true` to include expanded analyzer steps.
2. Confirm per-job artifacts appear with names `test-results-unit-Windows`, `test-results-integration-Windows`, etc.
3. Confirm the existing `final-report` job (already present in `ci.yml`) can download and aggregate `artifacts/test-results/**` and uploads `latest-test-report` and `final-test-report`.

Follow-ups
----------
- Optionally update analyzers to prefer canonical artifact names and fall back to legacy names.
- Add similar preservation steps for any other test runners/components (GUI, agent).

Notes
-----
This PR only preserves and uploads TRX artifacts. It does not change the report generator behavior. If you want, I can also open the PR on GitHub and dispatch a test run.
Adds CI step to run `server/AgentHeartbeat.Tests` and upload its TRX artifact.

Changes included in this branch:
- CI workflow: `.github/workflows/ci.yml` — runs the isolated `AgentHeartbeat` test project and includes its TRX in uploaded artifacts.
- New test project: `server/AgentHeartbeat.Tests` (unit tests for `AgentsController` heartbeat policy).
- Minor test fixes: updated global usings and ensured `appsettings.Testing.json` is copied to test output so functional/integration tests run in CI.

Local verification: ran `dotnet test` for the solution locally — `USBDeviceManager.Tests` passed (68/68) and the isolated `AgentHeartbeat.Tests` passed.

Please review the CI change; this keeps the new isolated tests exercised independently while we continue stabilizing the larger server test graph.
