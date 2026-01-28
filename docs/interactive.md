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