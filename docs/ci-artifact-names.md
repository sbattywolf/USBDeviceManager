Canonical CI artifact names
==========================

Purpose
-------
Document a small canonical set of artifact names used across workflows so analyzers and downstream tooling can rely on stable names.

Canonical names (recommended)
-----------------------------
- `unit-tests` : TRX results and unit test artifacts.
- `integration-triage` : Minimal triage artifacts (TRX, server stdout/stderr, small DB dumps).
- `integration-report` : Enriched human-readable report and packaged full integration artifacts (zip).
- `integration-tests-summary-${{ runner.os }}` : Per-OS summarized integration artifacts.
- `e2e-results` : E2E TRX and related artifacts.
- `published-server-win-x64` : Published self-contained Windows exe outputs (or `published-server-win-x64-zip` for zipped package).
- `job-logs-${{ github.run_id }}` : Job-level logs bundle for forensic triage.
- `test-db-artifacts-${{ github.run_id }}` : Collected DB files and PRAGMA integrity outputs.
- `analysis-results-${{ github.run_id }}` : Analyzer outputs (already used by `analyze-results.yml`).

Compatibility mapping (legacy → canonical)
------------------------------------------
- `dotnet-integration-${{ runner.os }}`, `integration-tests-${{ runner.os }}`, `integration-tests` → `integration-triage` and also upload `integration-report` when packaging full report.
- `unit-test-results`, `dotnet-unit-tests-${{ matrix.os }}` → `unit-tests`.
- `integration-report-full*` → `integration-report` (single canonical package name preferred).
- `integration-tests-summary-${{ runner.os }}` → keep, but also upload `integration-report`.

Recommendations
---------------
- Producer workflows should upload both the legacy/compat name (for a short migration window) and the canonical name to avoid breaking existing analyzers.
- Analyzer workflows should keep attempting fallbacks but prefer canonical names first.
- When migrating, make small, focused PRs updating one producer workflow at a time and verify analyzer runs succeed.

Next action
-----------
If you want, I will add dual uploads (legacy + canonical) to the key producer workflows (`.github/workflows/integration-only.yml`, `.github/workflows/ci.yml`, `.github/workflows/unit.yml`) so analyzers can immediately find canonical names without breaking existing consumers.
