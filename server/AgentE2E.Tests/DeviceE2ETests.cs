using System;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

[Trait("Category","E2E")]
    public class DeviceE2ETests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> factory;

    public DeviceE2ETests(WebApplicationFactory<Program> factory)
    {
        this.factory = factory;
    }

    [Fact]
    public async Task DeviceConnectDisconnectFlows()
    {
        using var client = factory.CreateClient();

        string deviceId = "SIMDEV-" + Guid.NewGuid().ToString("N").Substring(0, 8);

        // Simulate device connected via logs endpoint
        var connectPayload = new { deviceId = deviceId, eventType = "CONNECTED", message = "e2e connect" };
        var res = await client.PostAsJsonAsync("/api/logs", connectPayload);
        res.EnsureSuccessStatusCode();

        // Find created device
        JsonElement[] devices = await client.GetFromJsonAsync<JsonElement[]>("/api/devices");
        Assert.NotNull(devices);

        int? createdId = null;
        foreach (var d in devices)
        {
            if (d.TryGetProperty("deviceId", out var dv) && dv.GetString() == deviceId)
            {
                if (d.TryGetProperty("id", out var idProp) && idProp.TryGetInt32(out var iid))
                {
                    createdId = iid;
                    break;
                }
            }
        }

        Assert.NotNull(createdId);

        // Check status is connected
        JsonElement status = await client.GetFromJsonAsync<JsonElement>($"/api/devices/{createdId}/status");
        Assert.True(status.GetProperty("isConnected").GetBoolean());

        // Simulate device disconnected
        var disconnectPayload = new { deviceId = deviceId, eventType = "DISCONNECTED", message = "e2e disconnect" };
        var res2 = await client.PostAsJsonAsync("/api/logs", disconnectPayload);
        res2.EnsureSuccessStatusCode();

        JsonElement status2 = await client.GetFromJsonAsync<JsonElement>($"/api/devices/{createdId}/status");
        Assert.False(status2.GetProperty("isConnected").GetBoolean());
    }
}
