# Troubleshooting Notes — PowerShell parse errors (2026-01-25)

Symptom
- CI `ps-parsecheck` reported parse errors: `InvalidVariableReferenceWithDrive Variable reference is not valid. ':' was not followed by a valid variable name`.

Root cause
- Unescaped variable interpolations followed immediately by punctuation (e.g. `$id:`, `$max:`) can be parsed as invalid "variable-with-drive" tokens by PowerShell's parser on non-Windows runners.

Fixes applied
- Replace risky interpolations with either:
  - explicit subexpression: `"$($var): ..."`
  - or format operator: `"... {0}: {1}" -f $var, $val`
- Files patched in this change set:
  - `scripts/poll-pr28.ps1`
  - `workspace_restart.ps1`
  - `.tools/find-herestring-markers.ps1`
  - `scripts/run_full_debug.ps1`
  - `scripts/start-server-and-wait.ps1`

Quick local checks
- Run the repository parse-check helper locally:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass .\scripts\ci\ps-parsecheck.ps1 -Paths (Get-ChildItem -Path scripts -Filter '*.ps1' -Recurse | ForEach-Object { $_.FullName })
```

- Expect to see `PARSE_OK` for each file. If a file reports parse errors, open it and replace `$var:` with `"$($var):"` or use the format operator as shown above.

Notes
- I pushed fixes and triggered CI; one run is currently in progress. When the run finishes I'll download logs and confirm `ps-parsecheck` success and that the Windows `dotnet publish` step produced `SMServer.exe` in the expected path.
