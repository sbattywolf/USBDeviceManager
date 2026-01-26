# Archival Preservation

This repository now contains an archive of UI mockups and runtime screenshots under `artifacts/mockups` collected from multiple branches. These files are retained for historical review, debugging, and compliance purposes.

- DO NOT DELETE: `artifacts/mockups` must be preserved and excluded from automated cleanup or pruning operations.
- Removal of temporary scripts: The temporary image-extraction scripts that were used to collect these files have been removed from the repository to avoid accidental re-use. To re-run extraction, recover the scripts from Git history or contact the CI maintainer to request a supported archival workflow.
- Recommended cleanup policy: When performing repo cleanup, always exclude `artifacts/mockups` and the canonical test TRX artifacts (e.g., `artifacts/test-results/all-tests.trx`). Consider compressing archives for long-term storage instead of deleting.

If you want me to add a short pointer to this note in `docs/ci-activity-log.md` and `docs/ci-polling.md`, I can patch those files next.