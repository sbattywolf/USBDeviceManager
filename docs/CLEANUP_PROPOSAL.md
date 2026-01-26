# Repo Cleanup Proposal

This document proposes a safe, incremental cleanup of the repository to remove or archive generated, temporary, and large artifacts that are not required in version control. The goal is to reduce noise, shrink repo size, and make CI more reliable.

Proposed actions (non-destructive by default):

1. Add a safe cleanup script
   - `scripts/cleanup-repo.ps1` (dry-run by default; `-Apply` to perform actions; `-Archive` to compress matched items into `artifacts/cleanup/<timestamp>`).

2. Candidate items to remove or archive
   - `**/__pycache__/**` and `**/*.pyc` — Python bytecode caches.
   - `**/test-results/**` and top-level `test-results/*.trx` — test run artifacts that should be created by CI artifacts rather than checked in.
   - `**/logs/**` and `**/*.log` — runtime logs and screenshots (archive if needed).
   - `**/*.cache`, `**/*.sqlite` — transient caches and temporary DB files used by tests.
   - Large image assets used only for mockups or debug screenshots could be moved to `design/mockups/` or `artifacts/`.

3. Files we will NOT delete
   - Source files under `server/`, `agent/`, `gui/`, `scripts/`.
   - Any checked-in assets intentionally part of the app (e.g., `wwwroot/` samples).
   - Files listed in `.gitignore` are respected; the cleanup script avoids `.git`.

4. Recommended follow-up
   - Add/extend `.gitignore` to avoid checking in generated test results, logs, caches.
   - Add a CI job or docs step to publish and store test artifacts in GitHub Actions artifacts instead of committing them.
   - Review any large files (images, logs) and move to `artifacts/` if needed.

How to run the safe cleanup (dry run):

```powershell
# dry run - shows candidates only
.\scripts\cleanup-repo.ps1

# actually apply deletions (destructive)
.\scripts\cleanup-repo.ps1 -Apply

# archive matched items into artifacts and then delete originals
.\scripts\cleanup-repo.ps1 -Apply -Archive
```

If you approve, I will create a PR that:
- Adds the `scripts/cleanup-repo.ps1` file
- Adds this `docs/CLEANUP_PROPOSAL.md`
- Optionally updates `.gitignore` as a follow-up commit

