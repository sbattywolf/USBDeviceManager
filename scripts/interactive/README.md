Interactive prompt helpers
==========================

This folder contains a small PowerShell helper to make interactive prompts deterministic
for local debugging and reproducible test runs.

Files
- `PromptHelper.ps1` — functions to read validated non-empty strings and file paths.
- `RunReproWithPrompt.ps1` — example script that demonstrates how to use the helper.

Quick usage
1. Dot-source the helper in your PowerShell session:

```powershell
. .\scripts\interactive\PromptHelper.ps1
```

2. Use the helpers in scripts or manual runs:

```powershell
$value = Read-NonEmptyString -Prompt "Enter DB path (or press Enter to use default)" -Default ""
$path = Read-ValidatedPath -Prompt "Enter path to existing DB" -MustExist
```

Behavior
- If the user types `cancel` the helpers throw a terminating error (so scripts can abort).
- `Read-NonEmptyString` returns `$Default` when specified and the user provides empty input.
- `Read-ValidatedPath -MustExist` enforces that the provided path exists.

New behaviors and recommended defaults
- Pressing Enter (empty input) uses the supplied `-Default` when provided. This makes local runs and CI consistent.
- Use `-ValidateRegex` to enforce simple input formats (example: `^[a-zA-Z0-9._-]+$`).
- Use `-RetryCount` and `-FallbackToDefault` so scripts either retry user input or safely fall back.
- For paths, `-CreateIfMissing` will create parent folders and a placeholder file when the user accepts a default or the script auto-accepts in non-interactive mode.

Example (non-interactive friendly):
```powershell
# Use defaults in CI/noninteractive mode; create folder when needed.
$env:NONINTERACTIVE = '1'
. .\scripts\interactive\PromptHelper.ps1
$path = Read-ValidatedPath -Prompt 'Enter workspace path (or Enter to accept default)' -Default 'artifacts/workspace' -CreateIfMissing -RetryCount 3 -FallbackToDefault
```

Integration notes
- Prefer dot-sourcing in CI-adjacent local runs so the functions are available.
- Use these helpers in any interactive script used during debugging or local repro runs to avoid accidental empty entries.
