# Testing guide

This project uses xUnit and integration tests via `WebApplicationFactory<Program>`.

Key points about the test infrastructure:

- Tests use a temporary file-based SQLite database per test run to exercise EF Core relational behavior.
- Test DB files are created under the system temp directory with names like `SimRacingTest_YYYYMMDDHHMMSS_<pid>.db`.
- Startup cleanup removes old `SimRacingTest_*.db` files older than `SIMRACING_TEST_DB_EXPIRATION_HOURS` (default 6).
- The test factory applies `PRAGMA journal_mode=WAL` and `PRAGMA busy_timeout=10000` to help with concurrency.
- xUnit parallelization is disabled at the assembly level to avoid SQLite concurrency races.

Running tests locally:

```powershell
# run all tests
dotnet test

# run only server tests
dotnet test server\USBDeviceManager.Tests\USBDeviceManager.Tests.csproj
```

Troubleshooting:
- If you see SQLite native registration errors, ensure the tests are not running in parallel and retry.
- If you see duplicate key / tracking errors, check that test data generators do not preassign `Id` values for entities persisted by EF.

Environment variables:
- `SIMRACING_TEST_DB_EXPIRATION_HOURS` - number of hours after which old temp DB files are deleted (integer). Set to `0` to skip deletion.

For more details, see the test factory at `server/USBDeviceManager.Tests/Fixtures/SimRacingTestFactory.cs`.
