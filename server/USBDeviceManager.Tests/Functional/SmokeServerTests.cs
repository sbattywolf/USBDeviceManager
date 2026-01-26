using System.Diagnostics;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;

namespace USBDeviceManager.Tests.Functional
{
    [Trait("Category","Functional")]
    public class SmokeServerTests
    {
        [Fact]
        public async Task RunServerAndSmokeEndpoints()
        {
            // If CI/runner sets SMOKE_USE_TESTSERVER=1 use in-process TestServer for determinism.
            var useTestServer = string.Equals(Environment.GetEnvironmentVariable("SMOKE_USE_TESTSERVER"), "1", StringComparison.OrdinalIgnoreCase);

            if (useTestServer)
            {
                using var factory = new WebApplicationFactory<Program>();
                using var client = factory.CreateClient();

                // basic checks against in-process server
                (await client.GetAsync("/api/configs")).StatusCode.Should().Be(System.Net.HttpStatusCode.OK);
                (await client.GetAsync("/api/logs")).StatusCode.Should().Be(System.Net.HttpStatusCode.OK);
                (await client.GetAsync("/api/agent/download")).StatusCode.Should().Be(System.Net.HttpStatusCode.OK);

                var logPayload = new { deviceId = "SMOKE-DEV", eventType = "CONNECTED", message = "smoke" };
                (await client.PostAsJsonAsync("/api/logs", logPayload)).StatusCode.Should().Be(System.Net.HttpStatusCode.Created);

                var cfgPayload = new { triggerPath = "C:\\Temp\\smoke.exe", softwareName = "SmokeApp" };
                (await client.PostAsJsonAsync("/api/configs", cfgPayload)).StatusCode.Should().Be(System.Net.HttpStatusCode.Created);
            }
            else
            {
                // locate USBDeviceManager project and run as separate process
                var projectDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "USBDeviceManager"));
                var psi = new ProcessStartInfo("dotnet", "run --no-build --urls http://localhost:5006")
                {
                    WorkingDirectory = projectDir,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                };

                using Process proc = Process.Start(psi)!;
                var outBuf = new System.Text.StringBuilder();
                var errBuf = new System.Text.StringBuilder();
                proc.OutputDataReceived += (_, e) => { if (e.Data is not null) outBuf.AppendLine(e.Data); };
                proc.ErrorDataReceived += (_, e) => { if (e.Data is not null) errBuf.AppendLine(e.Data); };
                proc.BeginOutputReadLine();
                proc.BeginErrorReadLine();
                try
                {
                    var client = new HttpClient { BaseAddress = new Uri("http://localhost:5006") };

                    var sw = Stopwatch.StartNew();
                    var ready = false;
                    while (sw.Elapsed.TotalSeconds < 60)
                    {
                        try
                        {
                            HttpResponseMessage r = await client.GetAsync("/api/configs");
                            if (r.IsSuccessStatusCode) { ready = true; break; }
                        }
                        catch
                        {
                            await Task.Delay(500);
                        }
                    }

                    if (!ready)
                    {
                        var outText = outBuf.ToString();
                        var errText = errBuf.ToString();
                        throw new Exception($"server did not start in time and respond to /api/configs. stdout:\n{outText}\n\nstderr:\n{errText}");
                    }

                    // basic checks
                    (await client.GetAsync("/api/configs")).StatusCode.Should().Be(System.Net.HttpStatusCode.OK);
                    (await client.GetAsync("/api/logs")).StatusCode.Should().Be(System.Net.HttpStatusCode.OK);
                    (await client.GetAsync("/api/agent/download")).StatusCode.Should().Be(System.Net.HttpStatusCode.OK);

                    var logPayload = new { deviceId = "SMOKE-DEV", eventType = "CONNECTED", message = "smoke" };
                    (await client.PostAsJsonAsync("/api/logs", logPayload)).StatusCode.Should().Be(System.Net.HttpStatusCode.Created);

                    var cfgPayload = new { triggerPath = "C:\\Temp\\smoke.exe", softwareName = "SmokeApp" };
                    (await client.PostAsJsonAsync("/api/configs", cfgPayload)).StatusCode.Should().Be(System.Net.HttpStatusCode.Created);
                }
                finally
                {
                    if (!proc.HasExited)
                    {
                        try { proc.Kill(true); } catch { }
                    }
                }
            }
        }
    }
}
