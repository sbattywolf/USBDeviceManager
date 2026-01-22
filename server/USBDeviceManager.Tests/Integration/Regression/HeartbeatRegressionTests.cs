using System.Net;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using USBDeviceManager.Tests.Fixtures;

namespace USBDeviceManager.Tests.Integration.Regression;

[Trait("Category","Integration")]
public class HeartbeatRegressionTests : IClassFixture<SimRacingTestFactory>
{
    private readonly SimRacingTestFactory _factory;
    private readonly HttpClient _client;

    public HeartbeatRegressionTests(SimRacingTestFactory factory)
    {
        _factory = factory;
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task Heartbeat_Post_WithLegacySchema_ShouldReturnOk()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        var payload = new
        {
            deviceId = "USB\\VID_TEST&PID_0001",
            status = "OK",
            timestamp = DateTime.UtcNow
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/heartbeat", payload);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task HealthEndpoint_Compatibility_ShouldReturn200()
    {
        // Act
        var response = await _client.GetAsync("/api/health");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
