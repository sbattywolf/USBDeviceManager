using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using USBDeviceManager.Data;
using USBDeviceManager.Models;
using USBDeviceManager.Tests.Fixtures;

namespace USBDeviceManager.Tests.Integration;

public class CompatControllerIntegrationTests : IClassFixture<SimRacingTestFactory>
{
    private readonly SimRacingTestFactory _factory;
    private readonly HttpClient _client;

    public CompatControllerIntegrationTests(SimRacingTestFactory factory)
    {
        _factory = factory;
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task GetConfigs_EmptyDatabase_ShouldReturnEmptyArray()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Act
        HttpResponseMessage response = await _client.GetAsync("/api/configs");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var json = await response.Content.ReadAsStringAsync();
        json.Should().NotBeNull();
        // expect an empty JSON array when no rules/software exist
        json.Trim().Should().StartWith("[");
    }

    [Fact]
    public async Task PostLogs_WithKnownDeviceId_ShouldCreateDeviceStatus()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        // pick an existing device from seeded data
        using SimRacingContext ctx = _factory.GetDbContext();
        UsbDevice device = ctx.UsbDevices.First();

        var payload = new
        {
            deviceId = device.DeviceId,
            eventType = "CONNECTED",
            message = "integration test"
        };

        // Act
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/logs", payload);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);

        // Verify entry exists in DB
        using SimRacingContext verifyCtx = _factory.GetDbContext();
        DeviceStatus? status = verifyCtx.DeviceStatuses.OrderByDescending(s => s.Timestamp).FirstOrDefault(s => s.DeviceId == device.Id);
        status.Should().NotBeNull();
        status!.IsConnected.Should().BeTrue();
        status.Status.Should().Contain("CONNECTED");
    }
}
