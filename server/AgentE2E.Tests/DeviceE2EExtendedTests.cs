using System;
using System.Linq;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

[Trait("Category","E2E")]
    public class DeviceE2EExtendedTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> factory;

    public DeviceE2EExtendedTests(WebApplicationFactory<Program> factory)
    {
        this.factory = factory;
    }

    [Fact]
    public async Task MultipleDevices_CreateAndToggleStatuses()
    {
        using var client = factory.CreateClient();

        string[] deviceIds = Enumerable.Range(1, 3).Select(i => "SIMDEV-" + Guid.NewGuid().ToString("N").Substring(0, 8)).ToArray();

        foreach (var did in deviceIds)
        {
            var p = new { deviceId = did, eventType = "CONNECTED", message = "e2e connect" };
            var r = await client.PostAsJsonAsync("/api/logs", p);
            r.EnsureSuccessStatusCode();
        }

        var devices = await client.GetFromJsonAsync<JsonElement[]>("/api/devices");
        Assert.NotNull(devices);

        foreach (var did in deviceIds)
        {
            var match = devices.FirstOrDefault(d => d.GetProperty("deviceId").GetString() == did);
            Assert.True(match.ValueKind != JsonValueKind.Undefined);

            int id = match.GetProperty("id").GetInt32();
            var status = await client.GetFromJsonAsync<JsonElement>($"/api/devices/{id}/status");
            Assert.True(status.GetProperty("isConnected").GetBoolean());
        }

        // Disconnect one device
        var dis = new { deviceId = deviceIds[1], eventType = "DISCONNECTED", message = "e2e disconnect" };
        var r2 = await client.PostAsJsonAsync("/api/logs", dis);
        r2.EnsureSuccessStatusCode();

        // Confirm disconnected
        var devicesAfter = await client.GetFromJsonAsync<JsonElement[]>("/api/devices");
        var m = devicesAfter.First(d => d.GetProperty("deviceId").GetString() == deviceIds[1]);
        int mid = m.GetProperty("id").GetInt32();
        var s2 = await client.GetFromJsonAsync<JsonElement>($"/api/devices/{mid}/status");
        Assert.False(s2.GetProperty("isConnected").GetBoolean());
    }

    [Fact]
    public async Task RapidConnectDisconnect_StressTest()
    {
        using var client = factory.CreateClient();
        string deviceId = "SIMDEV-" + Guid.NewGuid().ToString("N").Substring(0, 8);

        // ensure created
        for (int i = 0; i < 40; i++)
        {
            var ev = (i % 2 == 0) ? "CONNECTED" : "DISCONNECTED";
            var p = new { deviceId = deviceId, eventType = ev, message = $"pulse {i}" };
            var r = await client.PostAsJsonAsync("/api/logs", p);
            r.EnsureSuccessStatusCode();
        }

        // get device id
        var devices = await client.GetFromJsonAsync<JsonElement[]>("/api/devices");
        var found = devices.First(d => d.GetProperty("deviceId").GetString() == deviceId);
        int id = found.GetProperty("id").GetInt32();

        var status = await client.GetFromJsonAsync<JsonElement>($"/api/devices/{id}/status");
        // last iteration 39 -> odd -> DISCONNECTED
        Assert.False(status.GetProperty("isConnected").GetBoolean());
    }

    [Fact]
    public async Task LogBroadcasts_AppearInRecentLogs()
    {
        using var client = factory.CreateClient();
        string deviceId = "SIMDEV-" + Guid.NewGuid().ToString("N").Substring(0, 8);

        var p = new { deviceId = deviceId, eventType = "CONNECTED", message = "broadcast test" };
        var r = await client.PostAsJsonAsync("/api/logs", p);
        r.EnsureSuccessStatusCode();

        // The server's /api/logs returns recent DeviceStatus entries from the DB; verify the device shows up there.
        bool found = false;
        for (int attempt = 0; attempt < 30; attempt++)
        {
            var list = await client.GetFromJsonAsync<JsonElement[]>("/api/logs");
            if (list != null && list.Any(it => it.TryGetProperty("deviceId", out var dv) && dv.GetString() == deviceId))
            {
                found = true;
                break;
            }

            await Task.Delay(100);
        }

        Assert.True(found, "Expected /api/logs to contain an entry for the device within timeout");
    }
}
