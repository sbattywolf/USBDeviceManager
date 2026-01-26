# CI Review & Enrichment Plan

Goal: Start from a stable unit-test baseline, merge unit-test guards, then incrementally enrich CI (integration → functional → e2e), reusing existing job definitions where available.

1. Baseline: Unit Tests
- Reusable workflow: `.github/workflows/unit-tests-reusable.yml` — runs on `windows-latest`, uploads TRX artifacts under `artifacts/test-results/unit/<runner.os>/`.
- Action: Ensure unit-only dispatch is automated and reproducible. Add a small dispatcher workflow or use `ci-dispatch.yml` to run unit-only (`run_unit=true`) and verify artifacts are uploaded.

2. Merge baseline fixes (PR)
- Open PRs that include test guards/fixes (already applied in `fix/skip-windows-tests2` and merged). Verify via unit-only run that passing state is stable.

3. Enrich: Integration
- Reuse `integration.yml` and `integration-analysis-reusable.yml` jobs as references.
- Add integration job to CI as a separate staged execution after `unit-tests` passes.

4. Enrich: Functional / E2E
- Add `test-runner-dispatch.yml` to dispatch functional/e2e jobs conditionally.
- Keep `run_e2e=false` by default; enable via `workflow_dispatch` input for manual runs.

5. Artifact aggregation
- Maintain per-job TRX uploads; implement or validate a `final-report` aggregator to merge TRX into `artifacts/test-results/all-tests.trx`.
- Ensure aggregator runs even for unit-only runs (guard against skipped-run conditions).

6. Automation & iteration
- Automate: dispatch → poll → download artifacts → analyze TRX → open issues or post summaries.
- Use existing `scripts/gh-poll-run.ps1` as the poller; augment to recognize the canonical `all-tests.trx` and fail fast if not found.

Next immediate tasks I will execute unless you tell me otherwise:
- Produce a concrete job-map (unit→integration→e2e) mapping to existing workflow filenames.
- Draft a minimal change to ensure `final-report` aggregator runs for unit-only dispatches.

If you want me to continue now, I will generate the job-map and a proposed patch for the aggregator invocation in `.github/workflows/ci.yml` (or `ci-dispatch.yml`) and open a PR branch for review.