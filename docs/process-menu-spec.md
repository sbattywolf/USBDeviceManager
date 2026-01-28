process-menu.ps1 — Concept & Role

Purpose
- Provide a safe, interactive menu for managing the SimRacing server and local agents during development and for local operators.

Primary users
- Developers: quick control during local development and debugging.
- CI: automated validation of menu flows using a mock mode (no real processes started).
- Operators / installers: first-run configuration and simple local start/stop/status operations.

Runtime modes
- Interactive Real-mode (elevated recommended): actually start/stop server and agents.
- Mock-mode (CI / non-elevated): simulate actions, write markers/log lines for test harnesses, never launch real processes.
- Standalone read-only: query and display process status and logs without making changes.

Actions provided
- Show server status (PID, uptime, start args).
- Start server (detached), Stop server, Tail server log.
- Show agents (network or local), Start local agent, Stop local agent, Tail agent log.
- Configure defaults and persist between runs (installer / user config).

Safety constraints
- Never auto-start real processes when running under CI or non-elevated sessions unless explicitly opted-in.
- Mock-mode must be the default for non-elevated sessions and CI runs.
- Any action that would start/stop system services or background processes requires either elevation or an explicit opt-in env var for test harnesses.

Configuration points
- Env vars used by tests and behavior:
  - `PROCESS_MENU_MOCK` — force mock-mode.
  - `PROCESS_MENU_ENABLE_AUTO_ADVANCE` — enable timeout auto-advance (opt-in).
  - `PROCESS_MENU_TEST_MARKER` — path to marker file the script writes when mock actions occur.
  - `PROCESS_MENU_SKIP_PAUSE` — skip interactive pauses for automated runs.
  - `PROCESS_MENU_INPUT_TIMEOUT` — configurable input timeout in seconds.
  - `PROCESS_MENU_TEST_INPUTS_FILE` — optional file with queued test inputs.
- Installer-time defaults: the installer may write a small JSON file (e.g. `%ProgramData%\SimRacing\process-menu-config.json`) with chosen defaults to be read on startup.

Testability & CI
- The script must be fully exercisable in mock-mode by the CI harness: marker writes or log entries should be sufficient to assert expected flows.
- Provide an isolated test runner that executes the menu in a separate pwsh process with controlled stdin and env.
- Acceptance tests SHOULD cover: menu rendering, selecting start/stop/tail commands, timeout and auto-advance behavior when `PROCESS_MENU_ENABLE_AUTO_ADVANCE` is set, skip-pause behavior, and persistence of installer defaults.

Acceptance criteria (high level)
- Script parses and runs without syntax errors across supported PowerShell hosts (`pwsh` and Windows PowerShell where feasible).
- When run in mock-mode (or non-elevated), no external processes are launched and expected marker entries are written.
- Default-run blocks for user input unless `PROCESS_MENU_ENABLE_AUTO_ADVANCE=1` is set.
- CI harness tests pass consistently (mock-mode), and real-mode tests only run when explicitly opted-in and elevated.

Deliverables
- `docs/process-menu-spec.md` (this file).
- Suggested acceptance tests: list below.
- Docs to update: `INSTALL.md`, `docs/interactive.md`, `TESTING.md` with a short section describing safe defaults and how to opt into real-mode tests.

Suggested acceptance tests (short)
- Mock-mode flow: run script with `PROCESS_MENU_MOCK=1`, `PROCESS_MENU_SKIP_PAUSE=1`, and `PROCESS_MENU_ENABLE_AUTO_ADVANCE=1` and assert marker file contains Start-Server and Start-Agent entries.
- Timeout opt-in: run script with `PROCESS_MENU_ENABLE_AUTO_ADVANCE=1` and a short `PROCESS_MENU_INPUT_TIMEOUT=2` and verify default action executed after timeout.
- Non-elevated safety: run without any env vars in a non-elevated session and assert script reports that mock-mode is active and refuses to start real processes.
- Persistence: write installer defaults JSON, run script and accept default, then re-run and assert default is suggested.

Notes
- Keep the menu UI text concise; tests assert markers/lines, not visual layout.
- Avoid complex background job constructs that can deadlock CI runners; prefer transparent loops/readers for input/timeouts.

-- end
