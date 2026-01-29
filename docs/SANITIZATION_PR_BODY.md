Summary
-------

This PR applies repository sanitization to remove local-PC and personal traces from tracked artifacts.

What changed
- Replaced hostname `LITTLE_BEAST` -> `BRNMTHF` across tracked test artifacts and logs.
- Replaced short username `sbatt` -> `Sbatta` across transcripts and TRX files.
- Replaced account owner `sbattywolf` -> `Sbatta` across CI artifacts and docs.
- Redacted `run_details.json` and `run_artifacts.json` (replaced URLs and owner names with placeholders).

Backups
- All original files are backed up under `.sanitize-backup/` at the repository root.

Branch & history
- Changes are committed to branch `ci/sanitize-personal-info` and pushed to origin.
- A prior mirror/history rewrite was performed earlier to remove historic traces (approved separately).

Why
- Remove accidental local-user and hostname leakage from test/trx/log artifacts before merging public history.

Notes for collaborators
- If you have local clones, please run:

  git fetch origin
  git checkout --track origin/ci/sanitize-personal-info

- If we later rewrite history more aggressively, we'll advise a full reclone.

Next steps
- Verify CI runs and TRX aggregation still function as expected.
- Optionally, remove backups after verification.
