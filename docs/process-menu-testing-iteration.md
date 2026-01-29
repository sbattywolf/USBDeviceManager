**Process-Menu Iteration & Testing Procedure**

Purpose
- Provide a repeatable, safety-first process for testing and debugging interactive menu scripts (example: `scripts/process-menu.ps1`).
- Supply a template TODO that can be reused for similar interactive scenarios.

Audience
- Test engineers, devs, CI maintainers who must iterate on interactive scripts safely and automate acceptance checks.

Principles
- CI-safe by default: prefer mock/dry-run modes and marker-based assertions.
- Minimize destructive actions: require explicit env gating (`PROCESS_MENU_ALLOW_SIGNAL`, `PROCESS_MENU_REAL_TEST`).
- Isolate changes: run the interactive script in a child process and capture stdout/stderr to logs.
- Fast feedback loop: small edits, parse-check, isolated run, examine markers/logs, fix, repeat.

Prerequisites
- PowerShell (pwsh or Windows PowerShell) available on test machine/runner.
- `scripts/ci/isolated_test_process_menu.ps1` harness or equivalent.
- Access to workspace root and write permissions to `artifacts/`.

Iteration Procedure (step-by-step)
1. Reproduce
   - Start from a clean workspace (or ensure artifacts marker log rotated).
   - Run quick parse check: `.	ools\run_parse_check.ps1` or `powershell -NoProfile -Command { [scriptblock]::Create((Get-Content .\\scripts\\process-menu.ps1 -Raw)).Ast }` to catch syntax errors.
2. Isolate
   - Use `scripts/ci/isolated_test_process_menu.ps1` or `run_interactive_tests.ps1` with `PROCESS_MENU_MOCK=1` to avoid launching real processes.
   - Provide queued test inputs via `PROCESS_MENU_TEST_INPUTS_FILE` or harness `-Inputs`.
3. Run (fast)
   - Execute the harness in a child PowerShell process and capture stdout/stderr to `artifacts/interactive-<tag>.log`.
   - Example (local):
     ```powershell
     $env:PROCESS_MENU_MOCK='1'; $env:PROCESS_MENU_ENABLE_AUTO_ADVANCE='1'; pwsh -NoProfile -File .\scripts\ci\run_interactive_tests.ps1
     ```
4. Verify (markers & logs)
   - Check `PROCESS_MENU_TEST_MARKER` (or `artifacts/` logs) for expected mock markers like `MOCK_MARK Start-ServerDetached`.
   - Grep combined log for error strings and for `FAILED`/`FAIL_MARK` entries.
5. Debug
   - If parse errors, fix immediately and repeat parse-check.
   - If harness shows marker missing, reproduce the exact interactive choices (use inputs file) and rerun in verbose mode.
   - If logs are locked, rely on marker files for assertions; add retry/backoff when reading logs in tests.
6. Harden & Add Tests
   - Implement dry-run guards and marker writes in code paths changed.
   - Add an acceptance test script under `scripts/ci/` for the specific scenario (mock + input sequence) and assert by inspecting markers.
7. CI Integration
   - Add a CI workflow that runs the mock acceptance runner on push/PR and uploads `artifacts/` for inspection.
   - Keep real-mode tests gated by `PROCESS_MENU_REAL_TEST=1` and require elevated runner or manual run.
8. Post-fix regression
   - Re-run the full interactive test runner (`scripts/ci/run_interactive_tests.ps1`) and ensure all tests pass.

Regression test: no-auto-advance
- There is a focused regression script that verifies the menu does NOT auto-advance by default:
   - Script: `scripts/ci/test_process_menu_regression_no_auto_advance.ps1`
   - Behavior: runs `process-menu.ps1` in mock-mode without `PROCESS_MENU_ENABLE_AUTO_ADVANCE` and asserts the process remains running (awaiting input) for a short interval.
   - Runner integration: the test is executed as part of `scripts/ci/run_interactive_tests.ps1` (it runs before the timeout acceptance test).
   - CI: included in the mock-mode CI workflow (`.github/workflows/interactive-tests.yml`) so regressions are caught on push/PR.

Automation checklist (what to automate)
- Parse-only syntax checks before running tests.
- Isolated harness that accepts an inputs file and environment flags.
- Marker writes from mock/dry-run code paths for reliable, lock-free assertions.
- CI workflow to run mock acceptance suite and upload artifacts.
- Small wrapper that converts harness output into a TRX/JUnit artifact (optional).

Template TODO for an interactive iteration (copy into a new PR)

- [ ] Parse-check `scripts/process-menu.ps1` (syntax ok)
- [ ] Add or update mock-mode marker writes for changed code paths
- [ ] Create `scripts/ci/test_<scenario>_mock.ps1` that runs the harness with inputs and asserts markers
- [ ] Run `scripts/ci/isolated_test_process_menu.ps1` locally and save `artifacts/<scenario>-log.txt`
- [ ] Fix any syntax or runtime issues discovered
- [ ] Add/adjust CI workflow or runner entry for this scenario (mock-mode)
- [ ] Run full `scripts/ci/run_interactive_tests.ps1` and confirm PASS
- [ ] If changes add destructive behavior, add gating env var and update docs

Diagnostics & common fixes
- Syntax errors: run parse-check and inspect AST parse exceptions; fix unmatched braces/quotes.
- Locked logs: use marker files; offer retries with exponential backoff when reading logs in tests.
- Missing marker: ensure `PROCESS_MENU_TEST_MARKER` env var is set in harness; add marker writes in code where mock/dry-run branch returns early.
- Unexpected real starts: add `PROCESS_MENU_DRY_RUN` guard and `PROCESS_MENU_ASSUME_DRYRUN` fallback.

Example quick commands

```powershell
# parse check
powershell -NoProfile -Command "[scriptblock]::Create((Get-Content .\\scripts\\process-menu.ps1 -Raw)).Ast"

# run single acceptance test (mock)
$env:PROCESS_MENU_MOCK='1'; $env:PROCESS_MENU_TEST_MARKER='artifacts/pmm.marker'; pwsh -NoProfile -File .\scripts\ci\test_process_menu_acceptance_mock.ps1

# full interactive runner (mock)
$env:PROCESS_MENU_MOCK='1'; pwsh -NoProfile -File .\scripts\ci\run_interactive_tests.ps1
```

Maintenance notes
- Keep tests small and focused: one scenario per acceptance script.
- Use markers for assertability; avoid brittle log parsing.
- Add a `scripts/ci/parse_check.ps1` if not present to surface syntax issues early.
- Document gating env vars in `docs/process-menu-spec.md` and `TESTING.md`.

Where to store the template
- This doc includes a copyable TODO template; for direct reuse, copy the checklist into a new `scripts/ci/<scenario>-todo.md` per work item.

Contact / owner
- Tests and harness maintained by the team owning `scripts/process-menu.ps1` (add owner in repo docs).

---
Created as part of the interactive test improvements; use as a canonical iteration guide and copy the template TODO for future interactive menu scenarios.
