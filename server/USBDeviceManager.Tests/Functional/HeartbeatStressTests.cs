using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using System.Collections.Concurrent;
using System.IO;
using USBDeviceManager.Tests.Fixtures;
using Xunit;

namespace USBDeviceManager.Tests.Functional;

public class HeartbeatStressTests : IClassFixture<SimRacingTestFactory>
{
    private readonly SimRacingTestFactory _factory;

    public HeartbeatStressTests(SimRacingTestFactory factory)
    {
        _factory = factory;
    }

    [Fact(DisplayName = "HeartbeatStress_SmallBurst_ShouldReturnSuccesses")]
    public async Task HeartbeatStress_SmallBurst_ShouldReturnSuccesses()
    {
        using var client = _factory.CreateAuthenticatedClient();

        // Small default burst to exercise legacy heartbeat handling.
        int total = 30; // small and fast by default
        int concurrency = 6;

        var payload = new
        {
            deviceId = "USB\\VID_TEST&PID_0001",
            status = "OK",
            timestamp = DateTime.UtcNow
        };

        var options = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

        var tasks = new List<Task<HttpResponseMessage>>();

        // concurrent-safe collection to capture per-request diagnostics
        var responseDiagnostics = new ConcurrentBag<string>();

        for (int i = 0; i < total; i++)
        {
            // throttle concurrency
            while (tasks.Count >= concurrency)
            {
                var finished = await Task.WhenAny(tasks);
                tasks.Remove(finished);
            }

            // capture index for closure
            int idx = i;
            tasks.Add(Task.Run(async () =>
            {
                try
                {
                    var resp = await client.PostAsJsonAsync("/api/heartbeat", payload, options);
                    string body = string.Empty;
                    try
                    {
                        body = await resp.Content.ReadAsStringAsync();
                        if (body.Length > 16_384) body = body.Substring(0, 16_384) + "...";
                    }
                    catch { /* ignore body read errors */ }

                    responseDiagnostics.Add($"[{DateTime.UtcNow:O}] #{idx} {((int)resp.StatusCode)} {resp.ReasonPhrase} - {body}");
                    return resp;
                }
                catch (Exception ex)
                {
                    responseDiagnostics.Add($"[{DateTime.UtcNow:O}] #{idx} EXCEPTION {ex.GetType().Name}: {ex.Message}");
                    throw;
                }
            }));
        }

        // wait remaining
        HttpResponseMessage[] responses = Array.Empty<HttpResponseMessage>();
        try
        {
            responses = await Task.WhenAll(tasks);
        }
        finally
        {
            // always write diagnostics to an artifact file for CI triage
            try
            {
                // Try to write into the test project's TestResults/artifacts directory.
                string artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                // If running from bin, try to resolve relative to the test assembly base directory
                if (!Directory.Exists(artifactsDir))
                {
                    try
                    {
                        var candidate = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "TestResults", "artifacts"));
                        artifactsDir = candidate;
                    }
                    catch { }
                }

                Directory.CreateDirectory(artifactsDir);
                var diagPath = Path.Combine(artifactsDir, "HeartbeatStress_responses.log");
                await File.WriteAllLinesAsync(diagPath, responseDiagnostics.OrderBy(x => x));
            }
            catch { }
        }

        // Determine successes. If responses array is empty (e.g. Task.WhenAll threw),
        // fall back to parsing the diagnostics we wrote to disk.
        int successes = 0;
        if (responses != null && responses.Length == total)
        {
            successes = responses.Count(r => r.IsSuccessStatusCode);
        }
        else
        {
            try
            {
                var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                if (!Directory.Exists(artifactsDir))
                {
                    artifactsDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "TestResults", "artifacts"));
                }

                var diagPath = Path.Combine(artifactsDir, "HeartbeatStress_responses.log");
                if (File.Exists(diagPath))
                {
                    var lines = await File.ReadAllLinesAsync(diagPath);
                    successes = lines.Count(l => l.Contains(" 200 ") || l.Contains(" 200 OK"));
                }
            }
            catch
            {
                // fallback to zero
                successes = 0;
            }
        }

        if (successes < (int)(total * 0.8))
        {
            // On failure, attempt to dump DB snapshot to artifacts for triage
                try
                {
                    string artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                    if (!Directory.Exists(artifactsDir))
                    {
                        try
                        {
                            artifactsDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "TestResults", "artifacts"));
                        }
                        catch { }
                    }

                    Directory.CreateDirectory(artifactsDir);
                    var dumpPath = Path.Combine(artifactsDir, "HeartbeatStress_db-dump.json");
                    try
                    {
                        _factory.DumpDatabaseSnapshot(dumpPath);
                    }
                    catch { }
                }
                catch { }
        }

        Assert.True(successes >= (int)(total * 0.8), $"Expected at least 80% successes, got {successes}/{total}");
    }
}
