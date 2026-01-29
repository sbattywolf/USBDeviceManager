# Interactive Scripts and Test Strategy

This document describes the test strategy and runtime behavior for interactive scripts such as `scripts/process-menu.ps1` and `scripts/ci/interactive_path_prompt.ps1`.

Principles
- CI should never start or stop real system processes by default.
- Mock-mode is the default in non-elevated sessions and in CI runs.
- Real-mode tests are opt-in and require explicit environment variables and elevation.

Environment variables
- `PROCESS_MENU_MOCK`=1 — run menus in mock-mode (no real processes started). Default when not elevated.
- `PROCESS_MENU_INPUT_TIMEOUT` — seconds before auto-advance (default 10).
- `PROCESS_MENU_DEFAULT_ACTION` — numeric menu option to run on timeout (default '2' = start server).
- `PROCESS_MENU_REAL_TEST`=1 — opt-in to run real-mode tests (must be elevated).

Test placeholders
- `scripts/ci/test_process_menu_mock.ps1` — placeholder to run mock-mode scenarios and verify artifact logs.
- `scripts/ci/test_process_menu_real.ps1` — placeholder to run real-mode scenario; disabled by default and requires `PROCESS_MENU_REAL_TEST=1` and elevation.

Next steps
- Flesh out assertions in the mock test to parse `server.log`/`agent-run.log` for MOCK entries and fail the test if missing.
- Create CI job that runs mock tests only.
- Create `scripts/tools/set-install-defaults.ps1` to record installer-chosen defaults to a config JSON consumed by the menu on first-run.

Please follow these guidelines when adding more interactive tests or changing behavior.

## `process-menu.ps1` mock-mode and CI harness

- The interactive menu `scripts/process-menu.ps1` supports a CI-safe mock mode. When `PROCESS_MENU_MOCK=1` the script will not start real processes; instead it emits small, deterministic artifacts that tests can assert on:
	- `scripts/ci/process-menu-run.marker` — appended lines describing mock actions (sanitized, single-line entries).
	- `scripts/ci/mock_server.pid` and `scripts/ci/mock_agent.pid` — written by helper scripts or by the menu when started in mock-mode.

- Key environment variables used by the harness:
	- `PROCESS_MENU_MOCK=1` — enable mock-mode (recommended for CI and non-elevated runs).
	- `PROCESS_MENU_ENABLE_AUTO_ADVANCE=1` — opt-in to auto-run a default menu action and exit (useful for CI).
	- `PROCESS_MENU_DEFAULT_ACTION` — default menu action number for auto-advance (e.g., `2` start server, `6` start agent).
	- `PROCESS_MENU_TEST_MARKER` — path to marker file. When set the script writes `MOCK_MARK` lines into this file.

## CI wrapper and assertion helpers

Use the helper scripts under `scripts/ci` to run the menu in mock-mode and assert results automatically:

- `run_process_menu_once.ps1 -Action <2|6>` — run the menu once and perform the selected auto-action (2=server, 6=agent).
- `make_pids_from_marker.ps1` — parse the marker file and write `mock_server.pid` and `mock_agent.pid` so subsequent tooling can query process presence.
- `assert_process_menu_mock_results.ps1 -Role <server|agent|both>` — assert marker entries and pid file presence; exits non-zero on failure and suitable for CI.
- `run_process_menu_mock_capture.ps1` — convenience wrapper that runs the menu once and prints an escaped, single-line marker for easy CI log capture.

Example CI sequence (mock-mode):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_process_menu_once.ps1 -Action 2
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_process_menu_once.ps1 -Action 6
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\make_pids_from_marker.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\assert_process_menu_mock_results.ps1 -Role both
```

Archive `scripts/ci/process-menu-run.marker` and any log output from `run_process_menu_mock_capture.ps1` as CI artifacts for debugging failed runs.

Notes

- Marker writing is sanitized to avoid embedded newlines; assert scripts parse the marker programmatically (prefer `Get-Content -Raw`).
- Real-mode acceptance tests are intentionally gated and require explicit environment flags and elevation — do not enable them in shared CI.
