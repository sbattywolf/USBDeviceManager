# USB Device Manager: Overview & Scope

## Purpose
USB Device Manager is a lightweight home-user focused service + agent to monitor USB racing hardware, manage important sim-related software, and provide simple automation rules (e.g., start game when wheel connects).

Design goals:
- Simplicity first: minimal configuration and minimal surface area for users.
- Low resource usage: the server and agent should be tiny on CPU, memory, and no GPU dependency.
- Reliable for single-machine/home use: predictable behavior, straightforward recovery, and minimal external services.

## Target user and scenarios
- Home sim racing enthusiasts who want: device presence detection, start/stop management for racing titles and telemetry apps, and simple automation rules.
- Typical scenarios:
  - Auto-launch a game when a wheel connects.
  - Disable a device on error or notify the user.
  - Keep a small dashboard with connected devices and running software.

## Key features
- USB device discovery and status tracking.
- Managed software list (executable path, autostart flag, enable/disable).
- Simple automation rules linking device events and software actions.
- REST API + minimal Blazor dashboard for local UI.
- Lightweight tests using file-based SQLite for near-real behavior during development.

## High-level architecture
- Agent (PowerShell module): optional helper tooling and installers for Windows.
- Server (ASP.NET Core): API controllers, EF Core-backed persistence, Razor/Blazor UI, SignalR hub for live updates.
- Test harness: xUnit + WebApplicationFactory for integration/functional tests; uses temporary SQLite DB files with WAL for concurrency.

## Constraints and trade-offs (principled)
- Simplicity vs. completeness: prefer simpler, well-tested behavior over adding many automation rule types. Keep rule execution deterministic and observable.
- Resource constraints: avoid background heavy polling or complicated native libs. Favor event-driven detection and small memory footprints.
- Reliability: prefer file-based SQLite for local durability over in-memory stores. Keep tests deterministic but lean (introduce small abstractions where helpful).

## Performance goals
- Server: < 50MB resident memory under typical small deployments; single-digit percent CPU on idle.
- Agent: small PowerShell modules with minimal recurring CPU and memory impact.
- Tests: fast to run locally; avoid long-running waits and heavy setup unless necessary.

## Security & privacy
- Local-first design: no telemetry or cloud sync by default. Any remote integrations must be opt-in.
- Keep secrets out of source (no PATs in repo or chat). Use OS-level credential stores for tokens.

## Config & conventions
- Environment variables and `appsettings.*` for configurable behavior. Test-specific env var: `SIMRACING_TEST_DB_EXPIRATION_HOURS`.
- Tests: xUnit with assembly-level control to avoid flaky concurrency on SQLite.
- Coding style: prefer explicit error handling, small methods, XML doc comments on public APIs.

## Roadmap (next priorities)
1. Consolidate docs and add `docs/testing.md` describing test DB lifecycle and env vars.
2. Apply small, safe code cleanups (remove hard Id assignments, narrow `catch` blocks, add logging where currently swallowed).
3. Introduce DTOs for API input to avoid coupling tests to EF entities.
4. Add `.editorconfig` and basic analyzers; add `dotnet format` step in CI.
5. Add a CONTRIBUTING guide and PR checklist.

## Acceptance criteria for this phase (what "done" looks like)
- `docs/overview.md` exists and explains scope, goals and trade-offs.
- A short prioritized cleanup list exists and first safe patches applied.
- Tests run locally and remain green after applied safe patches.
- Documentation skeleton for consolidation is present (`docs/` directory).

---

Next step I will implement the first safe patches listed in the roadmap: remove explicit `Id` assignments in the test data generator and replace silent `catch {}` blocks with logging in the test factory, then run the tests.
