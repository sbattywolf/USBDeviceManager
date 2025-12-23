using System.Linq;
using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using USBDeviceManager.Models;
using USBDeviceManager.Tests.Fixtures;

namespace USBDeviceManager.Tests.Integration;

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

        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/configs", payload);
        response.StatusCode.Should().Be(HttpStatusCode.Created);

        using Data.SimRacingContext ctx = _factory.GetDbContext();
        UsbDevice? device = ctx.UsbDevices.FirstOrDefault(d => d.DeviceId == "TEST-DEVICE-123");
        device.Should().NotBeNull();

        ManagedSoftware? sw = ctx.ManagedSoftware.FirstOrDefault(s => s.Name == "TestApp");
        sw.Should().NotBeNull();

        AutomationRule? rule = ctx.AutomationRules.FirstOrDefault(r => r.TriggerDeviceId == device.Id && r.TargetSoftwareId == sw.Id);
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

        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/configs", payload);
        response.StatusCode.Should().Be(HttpStatusCode.Created);

        using Data.SimRacingContext ctx = _factory.GetDbContext();
        ManagedSoftware? sw = ctx.ManagedSoftware.FirstOrDefault(s => s.Name == "StandaloneApp");
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

        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/configs", payload);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}
