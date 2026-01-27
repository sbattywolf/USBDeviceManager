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

                // Allow CI to override the server executable directly via TEST_SERVER_EXE
                var overrideExe = Environment.GetEnvironmentVariable("TEST_SERVER_EXE");
                Process? proc = null;
                ProcessStartInfo? psi = null;

                if (!string.IsNullOrWhiteSpace(overrideExe))
                {
                    // start provided executable path
                    var exePath = Path.GetFullPath(overrideExe);
                    psi = new ProcessStartInfo(exePath)
                    {
                        WorkingDirectory = Path.GetDirectoryName(exePath) ?? projectDir,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true,
                    };
                    proc = Process.Start(psi);
                }
                else
                {
                    // prefer Release build output, fall back to Debug if present
                    var releaseExe = Path.Combine(projectDir, "bin", "Release", "net8.0", "SMServer.exe");
                    var debugExe = Path.Combine(projectDir, "bin", "Debug", "net8.0", "SMServer.exe");
                    if (File.Exists(releaseExe))
                    {
                        psi = new ProcessStartInfo(releaseExe)
                        {
                            WorkingDirectory = Path.GetDirectoryName(releaseExe) ?? projectDir,
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                            UseShellExecute = false,
                            CreateNoWindow = true,
                        };
                        proc = Process.Start(psi);
                    }
                    else if (File.Exists(debugExe))
                    {
                        psi = new ProcessStartInfo(debugExe)
                        {
                            WorkingDirectory = Path.GetDirectoryName(debugExe) ?? projectDir,
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                            UseShellExecute = false,
                            CreateNoWindow = true,
                        };
                        proc = Process.Start(psi);
                    }
                    else
                    {
                        // fallback: run via `dotnet run` using Release config to match CI build
                        psi = new ProcessStartInfo("dotnet", "run --no-build -c Release --urls http://localhost:5006")
                        {
                            WorkingDirectory = projectDir,
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                            UseShellExecute = false,
                            CreateNoWindow = true,
                        };
                        proc = Process.Start(psi);
                    }
                }

                using (proc!)
                {
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
                            var attempted = psi is not null ? psi.FileName : "(unknown)";
                            throw new Exception($"server did not start in time and respond to /api/configs. attempted: {attempted}\n\nstdout:\n{outText}\n\nstderr:\n{errText}");
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

}


