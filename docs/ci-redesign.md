CI Redesign Proposal
=====================

Purpose
-------
Give a concise, actionable redesign for the current GitHub Actions CI to improve maintainability, reliability, and fast feedback while preserving forensic triage capabilities.

Problems observed
-----------------
- Large monolithic workflow (`.github/workflows/ci.yml`) with many `needs` producing fragile dependency graph and validation errors.
- Long inline `run:` scripts make YAML editing and validation brittle.
- Artifact name drift across producer workflows complicates analyzers.
- High blast radius and slower feedback when unrelated changes trigger many jobs.
- Optional diagnostics/log-collection not centralized; analyzers sometimes miss artifacts.

Goals
-----
- Reduce complexity: smaller, focused workflows with clear responsibilities.
- Keep forensic triage by default (minimal triage artifacts), optional full archives.
- Make analyzers robust to name changes via canonical names + short legacy fallbacks.
- Reduce validation issues by moving complex scripts to `scripts/ci/` files.
- Provide an incremental migration plan with safe rollback points.

Proposed architecture
---------------------
1. Component-oriented, reusable workflows
   - Create small `workflow_call` workflows per purpose:
     - `workflows/unit.yml` (runs unit tests for a component)
     - `workflows/integration.yml` (runs integration tests for a component)
     - `workflows/e2e.yml` (E2E tests; optional self-hosted)
   - Each component (agent, server, gui) has a dispatcher call to these workflows.
   - Keep a small `ci-dispatch.yml` that reads inputs and calls component workflows.

2. Producer / analyzer separation
   - Producers: build/test workflows that upload canonical artifacts (and legacy names during migration).
   - Analyzers: separate workflows that run after producers, download canonical artifacts, produce TRX->HTML, DB dumps, integrity checks, and upload `analysis-results-${{ github.run_id }}`.
   - Use `workflow_run` or explicit `needs` in dispatch to sequence analyzers after producers.

3. Scripts & helpers
   - Move long `run:` blocks to `scripts/ci/*.ps1` and `scripts/ci/*.sh` with clear inputs and idempotency.
   - Add `scripts/ci/ci-collect-logs.ps1` which gathers runner logs, job logs and selected system outputs and creates a small zip. Make its invocation optional via workflow input `collect_ci_logs: 'false'`.

4. Artifact naming
   - Enforce canonical names from `docs/ci-artifact-names.md`. Producers upload both legacy and canonical names during migration.

5. Optional CI logs collection
   - Add a small, opt-in step in each job to call `ci-collect-logs.ps1` when `inputs.collect_ci_logs` is truthy. Store output under `artifacts/ci-logs/${{ github.run_id }}/${{ github.job }}`.

Migration plan (incremental)
----------------------------
Priority order and PR sizes to minimize risk:
1. Unit tests migration (smallest):
   - Add `workflows/unit.yml` reusable workflow.
   - Update `ci.yml` to call `unit.yml` and upload `unit-tests` canonical artifacts.
   - Validate analyzers still find `unit-tests` artifacts.
   - PR size: small. Validate on push.
2. Integration migration:
   - Create `workflows/integration.yml` per-component calls.
   - Add dual artifact uploads (legacy + canonical) in producers.
   - Ensure DB preservation and triage-by-default artifacts are produced.
   - Scaffolding: added `scripts/ci/ci-collect-logs.ps1` as an opt-in helper that collects runner/system info, common log files, and zips them into `artifacts/ci-logs` for upload as an artifact.
3. E2E migration:
   - Create `workflows/e2e.yml` with explicit runner labels (self-hosted if needed).
4. Sweep & finalize:
   - Remove legacy artifact uploads after downstream analyzers updated.
   - Consolidate scripts in `scripts/ci/` and add `scripts/README.md`.

Rollback & safety
-----------------
- Keep dual uploads during migration to avoid breaking analyzers.
- Make each change in a focused PR enabling quick reverts.
- Add `continue-on-error` only at specific analysis steps, not at job-level, to avoid masking validation issues.

Cost / runtime considerations
---------------------------
- Componentization reduces unnecessary matrix permutations; allows running only affected component workflows.
- Use `paths`/`paths-ignore` at workflow trigger level to avoid running CI for docs-only changes.
- Consider caching and selective publishing (e.g., skip heavy publish jobs on forked PRs).

Deliverables & roadmap (first 2 weeks)
-------------------------------------
- Week 1:
  - Draft `workflows/unit.yml` and migrate unit tests (1 PR).
  - Add `scripts/ci/ci-collect-logs.ps1` and optional job input `collect_ci_logs`.
  - Add `docs/ci-redesign.md` and update TODOs.
- Week 2:
  - Migrate integration (split into per-component PRs), add dual uploads.
  - Start sweeping other workflows and centralize scripts.

Next immediate steps I can take now
----------------------------------
- Draft `workflows/unit.yml` reusable workflow skeleton and a small PR migrating `unit-tests` (fast win).
- Scaffold `scripts/ci/ci-collect-logs.ps1` and add example opt-in step to a job.

Would you like me to scaffold the `workflows/unit.yml` and the `ci-collect-logs` script now?