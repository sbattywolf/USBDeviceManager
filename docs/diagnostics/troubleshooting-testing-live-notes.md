# Live Notes — Troubleshooting & Testing

Date: 2026-01-25

- Observed an intermittent PowerShell log entry during CI and local wrapper runs:
  - "true : The term 'true' is not recognized as the name of a cmdlet..."
  - This arises when wrapper commands include the POSIX no-op `; true;` in a single-line command chain executed from PowerShell.

- Impact:
  - Benign when the preceding command succeeds (exit code remains 0), but noisy in logs and confusing to readers and automated parsers.
  - Caused an `apply_patch` context issue while attempting to update `docs/diagnostics/troubleshooting-testing.md`.

- Recommended action (TODO id 14):
  - Search the repo for occurrences of `; true;`, `|| true`, or similar POSIX-only constructs used inside PowerShell contexts.
  - Replace with PowerShell-safe equivalents, or ensure those commands run under bash/sh explicitly when POSIX semantics are required.

- Next steps:
  - Sweep and fix wrappers in `scripts/`, `scripts/tmp/`, CI job steps, and any helper scripts invoked from PowerShell.
  - Re-attempt updating `docs/diagnostics/troubleshooting-testing.md` once the repo is stable or append via this live-notes file.

CI trigger note: 2026-01-25T12:00:00Z — small repo change committed to trigger Windows CI verification job.
