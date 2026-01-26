# Contributing

Thanks for helping improve USB Device Manager.

Quick checklist for contributors:

- Fork the repository and create a feature branch named `feat/<short-desc>` or `chore/<short-desc>`.
- Run the full test suite locally before opening a PR:

```powershell
# server tests
dotnet test server/USBDeviceManager.Tests/USBDeviceManager.Tests.csproj
# agent tests (PowerShell)
cd agent/SimRacingAgent.Tests
./TestRunner.ps1
```

- Run the formatter and linters locally:

```powershell
dotnet tool restore
dotnet format USBDeviceManager.sln
```

- Keep commits small and focused. Use conventional commit prefixes: `feat:`, `fix:`, `chore:`, `docs:`.
- Ensure CI passes (build, tests, `dotnet format --verify-no-changes`).

PR checklist:

- [ ] Code builds locally and tests pass
- [ ] Formatting applied (`dotnet format`)
- [ ] No sensitive tokens or secrets
- [ ] PR description explains the change and any migration steps
- [ ] Add/update tests for behaviour changes

Coding style notes:

- Project uses .editorconfig for basic formatting.
- Roslyn analyzers and StyleCop are enabled for non-test projects; keep tests exempt to reduce noise.
- Prefer small, well-tested changes.

If you need help, open an issue describing the problem or join the discussion in the repository.
