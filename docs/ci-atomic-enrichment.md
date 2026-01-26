**CI Atomic Enrichment**
- **Goal:** Create a minimal, reliable unit-only CI job as the canonical baseline, then incrementally add integration, functional and e2e jobs once the baseline is stable.
- **Why:** Reusable workflows and workflow_dispatch parsing are sensitive to mismatched inputs and missing called workflows. Stabilizing a single job reduces blast radius and makes debugging incremental.

Plan
- Step 1 — Unit baseline
  - Create/verify a single reusable `unit` job that: checks out code, restores, builds, runs `dotnet test` for unit projects, publishes TRX into `artifacts/test-results`, and exits successfully on pass.
  - Ensure the reusable workflow `unit.yml` defines exactly the inputs the caller provides (no extra undefined inputs like `full`).

- Step 2 — Validate dispatch
  - Add the unit workflow to the target branch and dispatch a unit-only run with `collect_ci_logs=true`.
  - Confirm `artifacts/test-results/all-tests.trx` and job logs are produced and downloadable.

- Step 3 — Iterate fixes locally
  - Run unit tests locally to reproduce failures; apply small, safe fixes (OS guards, mocks, timeouts) and re-run until stable.

- Step 4 — Compose other jobs
  - Once unit baseline is stable, add integration, functional, and e2e as separate reusable jobs and compose them in the main `ci.yml` via inputs that match definitions.

Notes
- Keep `artifacts/mockups` preserved and avoid adding cross-cutting reusable-workflow dependencies until the unit job is stable.
- If a workflow parser error references an undefined input (like `full`), either remove that parameter from the caller or add a matching `inputs:` entry to the callee's `workflow_call`.

Skip-info contract
- The unit job now produces a small JSON artifact `artifacts/test-results/skip-info.json` alongside TRX files. It contains:
  - `trx`: per-TRX parsed counters and a list of skipped test names.
  - `console_errors`: snippets of console lines that look like parse errors or exceptions.
  - `summary`: aggregated counters (`total_passed`, `total_failed`, `total_skipped`) and `skipped_tests` list.
- The aggregator and downstream jobs should prefer `skip-info.json` for quick triage (skips, parse errors) before parsing large TRX sets. If present, the aggregator should merge its contents into `artifacts/test-results/all-tests.trx` processing or include the JSON in the final HTML report.

Next actions
- I will locate where `full` is passed in the workflows and either add the input to the called workflow or remove the parameter from the caller.
