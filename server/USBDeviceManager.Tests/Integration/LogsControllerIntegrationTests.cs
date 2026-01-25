using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using USBDeviceManager.Tests.Fixtures;
using USBDeviceManager.Data;
using USBDeviceManager.Models;

namespace USBDeviceManager.Tests.Integration
{
    [Trait("Category","Integration")]
    public class LogsControllerIntegrationTests : IClassFixture<SimRacingTestFactory>
    {
        private readonly SimRacingTestFactory _factory;
        private readonly HttpClient _client;

        public LogsControllerIntegrationTests(SimRacingTestFactory factory)
        {
            _factory = factory;
            _client = _factory.CreateClient();
        }

        [Fact]
        public async Task PostLog_CreatesDeviceAndStatus_WhenDeviceMissing()
        {
            // Arrange
            await _factory.ResetDatabaseAsync();

            var deviceId = "TEST_DEVICE_12345";
            var payload = new { deviceId = deviceId, eventType = "CONNECTED", message = "integration test" };

            // Act
            var resp = await _client.PostAsJsonAsync("/api/logs", payload);

            // Assert
            resp.StatusCode.Should().Be(HttpStatusCode.Created);

            using var ctx = _factory.GetDbContext();
            var device = ctx.UsbDevices.FirstOrDefault(d => d.DeviceId == deviceId);
            device.Should().NotBeNull();

            var status = ctx.DeviceStatuses.FirstOrDefault(s => s.DeviceId == device.Id);
            status.Should().NotBeNull();
            status.Status.Should().Be("CONNECTED");
        }
    }
}
