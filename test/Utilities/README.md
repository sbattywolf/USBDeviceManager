# Test Utilities

This folder contains small reusable helpers for tests.

Health check helper
- `test/Utilities/HealthCheck` contains `HealthPoller` and `HealthTestFixture`.

Usage examples

From an xUnit test that uses `WebApplicationFactory<Program>`:

```csharp
using var factory = new WebApplicationFactory<Program>();
using var client = factory.CreateClient();
var fixture = new USBDeviceManager.TestUtilities.HealthCheck.HealthTestFixture(client);
var ok = await fixture.WaitForHealthAsync("/health", TimeSpan.FromSeconds(30), TimeSpan.FromMilliseconds(200));
Assert.True(ok, "Server did not become healthy in time");
```

From scripts / orchestration
- The repository also contains PowerShell scripts in `scripts/` to start the server and poll `/health` from the shell. Use those when you prefer orchestration outside the test process.
