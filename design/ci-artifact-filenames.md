CI artifact filenames and log-splitting — design
=============================================

Goal
----
- Make per-job artifacts (logs, reports, TRX/html, DB dumps) uniquely identifiable and non-colliding across jobs and reruns.
- Improve signal-to-noise for triage by splitting artifacts by severity (errors/warnings vs debug/trace).
- Keep the final report generation robust to both new prefixed artifacts and older formats during a rollout.

Constraints
-----------
- Work must be safe to roll out incrementally (small PRs preferred).
- GitHub Actions artifact names must be unique per workflow run to avoid 409 conflicts.
- Minimal runner-side processing overhead.

Proposed filename scheme
------------------------
- Prefix all per-job files and folders with a short correlated identifier composed of the run and job metadata, for example:

  <runId>-<job>-<os>

  Example prefix (GitHub Actions expressions):

  ${{ github.run_id }}-${{ github.job }}-${{ runner.os }}

- Use descriptive suffixes for file type and severity. Example full filenames:

  - artifacts/enriched/<prefix>/tests-enriched-errors.txt
  - artifacts/enriched/<prefix>/tests-enriched-debug.txt
  - artifacts/enriched/<prefix>/final-report.html
  - artifacts/trx/<prefix>/UnitTests.trx
  - artifacts/db-dumps/<prefix>/server.db.dump

- When uploading artifacts via `actions/upload-artifact`, use a matching artifact `name:` that includes the prefix so uploads from different jobs don't clash, e.g.: `name: enriched-${{ github.run_id }}-${{ github.job }}-${{ runner.os }}`

Log splitting
-------------
- Produce two (or three) logical files per analyzer/job:
  - *-errors.txt*: errors and warnings, limited size (first N lines) — the primary triage file.
  - *-debug.txt*: verbose logs, full context (optional, larger) — used for deeper debugging.
  - (optional) *-metrics.txt*: lightweight numeric metrics or failure counters for dashboards.

- Generation pattern (bash example) — append important excerpts to the errors file and the full log to the debug file:

  set -euo pipefail
  mkdir -p artifacts/enriched/${PREFIX}
  # concise error snippet
  grep -RIn --binary-files=text -E "Exception|ERROR|Timeout|Assertion|404|Not Found" . | sed -n '1,400p' > artifacts/enriched/${PREFIX}/tests-enriched-errors.txt || true
  # full debug trace (optional)
  cat full-run.log > artifacts/enriched/${PREFIX}/tests-enriched-debug.txt || true

Workflow & script changes required
---------------------------------
1. Emit prefixed files/folders from per-job analyzers and test runners.
2. Upload artifacts using artifact names that include the same prefix (artifact `name:` and/or path), e.g. `enriched-${{ github.run_id }}-${{ github.job }}-${{ runner.os }}`.
3. Update `scripts/extract-failures.ps1` and the extractor flow to copy job logs into `artifacts/enriched/<prefix>` and to generate both `*-errors.txt` and `*-debug.txt` variants.
4. Update the `final-report` job to `download-artifact` with wildcard discovery or to iterate all enriched artifact names for the run and rehydrate them into `artifacts/enriched/<prefix>` for aggregation.
5. Make `scripts/generate-final-report-html.py` tolerant of multiple per-job enriched files (prefer `*-errors.txt` for summary and link to `*-debug.txt` for context).

Backward compatibility and rollout
---------------------------------
- Stepwise rollout recommended:
  1. Design PR (this document) reviewed and merged.
  2. Small PR: emit prefixed `*-errors.txt` alongside existing `*-enriched-report.txt` (do not stop producing legacy filenames). Update uploads to include prefixed artifact names. This avoids breaking the final-report job while enabling new artifacts to appear.
  3. Update `final-report` to discover prefixed artifacts when present (fall back to legacy names if not found).
  4. After verification, remove legacy artifact names in a subsequent PR.

Validation & tests
------------------
- Unit tests: verify `scripts/generate-final-report-html.py` can parse both legacy and prefixed files.
- CI smoke run: confirm multiple matrix jobs can upload artifacts concurrently without 409.
- Manual verification: download a completed run's artifacts and confirm `artifacts/enriched/<prefix>` folders exist for each job and include both `*-errors.txt` and `*-debug.txt`.

Rollout checklist (PRs)
----------------------
- Emit prefixed `*-errors.txt` next to existing outputs (non-breaking).
- Upload artifacts with artifact names including prefix.
- Update extractor to produce separate files.
- Update final-report aggregator to prefer `*-errors.txt` and link to `*-debug.txt` where present.
- Add a simple test that `generate-final-report-html.py` lists and includes prefixed artifacts.

Notes and rationale
-------------------
- Prefixing by `run_id` ensures uniqueness across reruns and multiple concurrent runs.
- Including `job` and `runner.os` makes it obvious which job produced the artifact and helps correlate artifacts during triage.
- Splitting errors vs debug improves speed of triage: most cases need only `*-errors.txt` to identify the root cause.

Examples
--------
- `actions/upload-artifact` example fragment:

  - name: Upload tests enriched errors
    uses: actions/upload-artifact@v4
    with:
      name: enriched-${{ github.run_id }}-${{ github.job }}-${{ runner.os }}
      path: artifacts/enriched/${{ github.run_id }}-${{ github.job }}-${{ runner.os }}/tests-enriched-errors.txt

Next steps
----------
- If you agree with this design I will prepare a small non-breaking PR that emits the prefixed `*-errors.txt` files and uploads them (step 2 of rollout). After that we can update the aggregator and remove legacy names.
