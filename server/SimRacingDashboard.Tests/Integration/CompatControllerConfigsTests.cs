using System.Linq;
using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using SimRacingDashboard.Models;
using SimRacingDashboard.Tests.Fixtures;

namespace SimRacingDashboard.Tests.Integration;

public class CompatControllerConfigsTests : IClassFixture<SimRacingTestFactory>
{
    private readonly SimRacingTestFactory _factory;
    private readonly HttpClient _client;

    public CompatControllerConfigsTests(SimRacingTestFactory factory)
    {
        _factory = factory;
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task PostConfigs_CreateDeviceAndSoftware_ShouldReturnCreatedAndPersistRule()
    {
        await _factory.ResetDatabaseAsync();

        var payload = new
        {
            deviceId = "TEST-DEVICE-123",
            friendlyName = "Test Device",
            usbPort = "Port 1",
            vendorId = "1234",
            productId = "5678",
            triggerPath = "C:\\Program Files\\TestApp\\app.exe",
            softwareName = "TestApp",
            triggerParams = "--mode=auto",
            workingDirectory = "C:\\Program Files\\TestApp",
            isEnabled = true
        };

        var response = await _client.PostAsJsonAsync("/api/configs", payload);
        response.StatusCode.Should().Be(HttpStatusCode.Created);

        using var ctx = _factory.GetDbContext();
        var device = ctx.UsbDevices.FirstOrDefault(d => d.DeviceId == "TEST-DEVICE-123");
        device.Should().NotBeNull();

        var sw = ctx.ManagedSoftware.FirstOrDefault(s => s.Name == "TestApp");
        sw.Should().NotBeNull();

        var rule = ctx.AutomationRules.FirstOrDefault(r => r.TriggerDeviceId == device.Id && r.TargetSoftwareId == sw.Id);
        rule.Should().NotBeNull();
    }

    [Fact]
    public async Task PostConfigs_CreateStandaloneSoftware_ShouldReturnCreatedAndPersistSoftware()
    {
        await _factory.ResetDatabaseAsync();

        var payload = new
        {
            triggerPath = "C:\\Tools\\Standalone\\standalone.exe",
            softwareName = "StandaloneApp",
            triggerParams = "",
            workingDirectory = "C:\\Tools\\Standalone",
            isEnabled = true
        };

        var response = await _client.PostAsJsonAsync("/api/configs", payload);
        response.StatusCode.Should().Be(HttpStatusCode.Created);

        using var ctx = _factory.GetDbContext();
        var sw = ctx.ManagedSoftware.FirstOrDefault(s => s.Name == "StandaloneApp");
        sw.Should().NotBeNull();
    }

    [Fact]
    public async Task PostConfigs_InvalidPayload_ShouldReturnBadRequest()
    {
        await _factory.ResetDatabaseAsync();

        var payload = new
        {
            // missing deviceId and triggerPath
            friendlyName = "NoOp",
            isEnabled = true
        };

        var response = await _client.PostAsJsonAsync("/api/configs", payload);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}
