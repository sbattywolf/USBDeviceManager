using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using USBDeviceManager.Data;
using USBDeviceManager.Models;
using USBDeviceManager.Tests.Fixtures;
using USBDeviceManager.Tests.Helpers;

namespace USBDeviceManager.Tests.Integration;

/// <summary>
/// Integration tests for Devices API endpoints
/// Tests full HTTP request/response cycle with database integration
/// </summary>
public class DevicesApiIntegrationTests : IClassFixture<SimRacingTestFactory>
{
    private readonly SimRacingTestFactory _factory;
    private readonly HttpClient _client;

    public DevicesApiIntegrationTests(SimRacingTestFactory factory)
    {
        _factory = factory;
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task GetDevices_EmptyDatabase_ShouldReturnEmptyArray()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Act
        HttpResponseMessage response = await _client.GetAsync("/api/devices");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        UsbDevice[]? devices = await response.Content.ReadFromJsonAsync<UsbDevice[]>();
        devices.Should().NotBeNull();
        devices!.Should().BeEmpty();
    }

    [Fact]
    public async Task GetDevices_WithSeedData_ShouldReturnAllDevices()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        // Act
        HttpResponseMessage response = await _client.GetAsync("/api/devices");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        UsbDevice[]? devices = await response.Content.ReadFromJsonAsync<UsbDevice[]>();
        devices.Should().NotBeNull();
        devices!.Should().HaveCountGreaterThan(0);
        devices.Should().OnlyContain(d => !string.IsNullOrEmpty(d.Name));
        devices.Should().OnlyContain(d => !string.IsNullOrEmpty(d.DeviceId));
    }

    [Fact]
    public async Task CreateDevice_ValidDevice_ShouldReturnCreatedWithLocation()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        var newDevice = new UsbDevice
        {
            DeviceId = "USB\\VID_TEST&PID_1234",
            Name = "Integration Test Device",
            VendorId = "TEST",
            ProductId = "1234",
            Description = "Device created during integration test",
            IsEnabled = true
        };

        // Act
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/devices", newDevice);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Created);
        response.Headers.Location.Should().NotBeNull();

        UsbDevice? createdDevice = await response.Content.ReadFromJsonAsync<UsbDevice>();
        createdDevice.Should().NotBeNull();
        createdDevice!.Id.Should().BeGreaterThan(0);
        createdDevice.Name.Should().Be("Integration Test Device");
        createdDevice.DeviceId.Should().Be("USB\\VID_TEST&PID_1234");

        // Verify device exists in database
        HttpResponseMessage getResponse = await _client.GetAsync($"/api/devices/{createdDevice.Id}");
        getResponse.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task GetDevice_ExistingDevice_ShouldReturnDeviceDetails()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        using SimRacingContext context = _factory.GetDbContext();
        UsbDevice existingDevice = context.UsbDevices.First();

        // Act
        HttpResponseMessage response = await _client.GetAsync($"/api/devices/{existingDevice.Id}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        UsbDevice? device = await response.Content.ReadFromJsonAsync<UsbDevice>();
        device.Should().NotBeNull();
        device!.Id.Should().Be(existingDevice.Id);
        device.Name.Should().Be(existingDevice.Name);
        device.DeviceId.Should().Be(existingDevice.DeviceId);
    }

    [Fact]
    public async Task GetDevice_NonExistentDevice_ShouldReturnNotFound()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Act
        HttpResponseMessage response = await _client.GetAsync("/api/devices/99999");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task UpdateDevice_ValidChanges_ShouldUpdateSuccessfully()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        using SimRacingContext context = _factory.GetDbContext();
        UsbDevice deviceToUpdate = context.UsbDevices.First();

        deviceToUpdate.Name = "Updated Integration Test Name";
        deviceToUpdate.Description = "Updated during integration test";
        deviceToUpdate.IsEnabled = !deviceToUpdate.IsEnabled;

        // Act
        HttpResponseMessage response = await _client.PutAsJsonAsync($"/api/devices/{deviceToUpdate.Id}", deviceToUpdate);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NoContent);

        // Verify changes persisted
        HttpResponseMessage getResponse = await _client.GetAsync($"/api/devices/{deviceToUpdate.Id}");
        UsbDevice? updatedDevice = await getResponse.Content.ReadFromJsonAsync<UsbDevice>();

        updatedDevice.Should().NotBeNull();
        updatedDevice!.Name.Should().Be("Updated Integration Test Name");
        updatedDevice.Description.Should().Be("Updated during integration test");
        updatedDevice.IsEnabled.Should().Be(deviceToUpdate.IsEnabled);
    }

    [Fact]
    public async Task UpdateDevice_MismatchedId_ShouldReturnBadRequest()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        device.Id = 123;

        // Act
        HttpResponseMessage response = await _client.PutAsJsonAsync("/api/devices/456", device);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task DeleteDevice_ExistingDevice_ShouldDeleteSuccessfully()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        using SimRacingContext context = _factory.GetDbContext();
        UsbDevice deviceToDelete = context.UsbDevices.First();

        // Act
        HttpResponseMessage deleteResponse = await _client.DeleteAsync($"/api/devices/{deviceToDelete.Id}");

        // Assert
        deleteResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        // Verify device no longer exists
        HttpResponseMessage getResponse = await _client.GetAsync($"/api/devices/{deviceToDelete.Id}");
        getResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task DeleteDevice_NonExistentDevice_ShouldReturnNotFound()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Act
        HttpResponseMessage response = await _client.DeleteAsync("/api/devices/99999");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task ToggleDevice_EnableDisable_ShouldUpdateState()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        using SimRacingContext context = _factory.GetDbContext();
        UsbDevice device = context.UsbDevices.First();
        var originalState = device.IsEnabled;

        // Act - Toggle to opposite state
        HttpResponseMessage toggleResponse = await _client.PostAsJsonAsync($"/api/devices/{device.Id}/toggle", !originalState);

        // Assert
        toggleResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        System.Text.Json.JsonElement toggleJson = System.Text.Json.JsonDocument.Parse(await toggleResponse.Content.ReadAsStringAsync()).RootElement;
        toggleJson.GetProperty("enabled").GetBoolean().Should().Be(!originalState);

        // Verify state changed in database
        HttpResponseMessage getResponse = await _client.GetAsync($"/api/devices/{device.Id}");
        UsbDevice? updatedDevice = await getResponse.Content.ReadFromJsonAsync<UsbDevice>();

        updatedDevice.Should().NotBeNull();
        updatedDevice!.IsEnabled.Should().Be(!originalState);
    }

    [Fact]
    public async Task ScanForDevices_ShouldReturnSuccessResponse()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Act
        HttpResponseMessage response = await _client.PostAsync("/api/devices/scan", null);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        System.Text.Json.JsonElement scanJson = System.Text.Json.JsonDocument.Parse(await response.Content.ReadAsStringAsync()).RootElement;
        scanJson.GetProperty("message").GetString().Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public async Task GetDeviceStatus_ExistingDevice_ShouldReturnLatestStatus()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        using SimRacingContext context = _factory.GetDbContext();
        UsbDevice device = context.UsbDevices.First();

        // Add some status entries
        DeviceStatus[] statuses =
        [
            new DeviceStatus
            {
                DeviceId = device.Id,
                IsConnected = false,
                Status = "Disconnected",
                Timestamp = DateTime.UtcNow.AddHours(-1)
            },
            new DeviceStatus
            {
                DeviceId = device.Id,
                IsConnected = true,
                Status = "Connected",
                Timestamp = DateTime.UtcNow
            }
        ];

        context.DeviceStatuses.AddRange(statuses);
        await context.SaveChangesAsync();

        // Act
        HttpResponseMessage response = await _client.GetAsync($"/api/devices/{device.Id}/status");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        DeviceStatus? status = await response.Content.ReadFromJsonAsync<DeviceStatus>();
        status.Should().NotBeNull();
        status!.IsConnected.Should().BeTrue();
        status.Status.Should().Be("Connected");
    }

    [Fact]
    public async Task GetDeviceStatusHistory_WithTimeFilter_ShouldReturnFilteredResults()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        using SimRacingContext context = _factory.GetDbContext();
        UsbDevice device = context.UsbDevices.First();

        DateTime now = DateTime.UtcNow;
        DeviceStatus[] statuses =
        [
            new DeviceStatus { DeviceId = device.Id, Status = "Old", Timestamp = now.AddHours(-25) },
            new DeviceStatus { DeviceId = device.Id, Status = "Recent1", Timestamp = now.AddHours(-12) },
            new DeviceStatus { DeviceId = device.Id, Status = "Recent2", Timestamp = now.AddHours(-6) },
            new DeviceStatus { DeviceId = device.Id, Status = "Current", Timestamp = now }
        ];

        context.DeviceStatuses.AddRange(statuses);
        await context.SaveChangesAsync();

        // Act
        HttpResponseMessage response = await _client.GetAsync($"/api/devices/{device.Id}/status/history?hours=24");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        DeviceStatus[]? history = await response.Content.ReadFromJsonAsync<DeviceStatus[]>();
        history.Should().NotBeNull();
        history!.Should().HaveCount(3); // Should exclude the 25-hour old entry
        history.Should().OnlyContain(s => s.Timestamp >= now.AddHours(-24));
    }

    [Fact]
    public async Task CreateDevice_InvalidData_ShouldReturnValidationError()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        var invalidDevice = new UsbDevice
        {
            // Missing required fields
            DeviceId = "",
            Name = "",
            IsEnabled = true
        };

        // Act
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/devices", invalidDevice);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task DeviceApiWorkflow_CreateReadUpdateDelete_ShouldWorkEndToEnd()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        var testDevice = new UsbDevice
        {
            DeviceId = "USB\\VID_FLOW&PID_TEST",
            Name = "End-to-End Test Device",
            VendorId = "FLOW",
            ProductId = "TEST",
            Description = "Device for workflow testing",
            IsEnabled = true
        };

        // Act & Assert - Create
        HttpResponseMessage createResponse = await _client.PostAsJsonAsync("/api/devices", testDevice);
        createResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        UsbDevice? createdDevice = await createResponse.Content.ReadFromJsonAsync<UsbDevice>();
        createdDevice.Should().NotBeNull();
        var deviceId = createdDevice!.Id;

        // Act & Assert - Read
        HttpResponseMessage readResponse = await _client.GetAsync($"/api/devices/{deviceId}");
        readResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        UsbDevice? readDevice = await readResponse.Content.ReadFromJsonAsync<UsbDevice>();
        readDevice!.Name.Should().Be("End-to-End Test Device");

        // Act & Assert - Update
        readDevice.Name = "Updated End-to-End Device";
        readDevice.IsEnabled = false;

        HttpResponseMessage updateResponse = await _client.PutAsJsonAsync($"/api/devices/{deviceId}", readDevice);
        updateResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        // Verify update
        HttpResponseMessage verifyResponse = await _client.GetAsync($"/api/devices/{deviceId}");
        UsbDevice? verifiedDevice = await verifyResponse.Content.ReadFromJsonAsync<UsbDevice>();
        verifiedDevice!.Name.Should().Be("Updated End-to-End Device");
        verifiedDevice.IsEnabled.Should().BeFalse();

        // Act & Assert - Delete
        HttpResponseMessage deleteResponse = await _client.DeleteAsync($"/api/devices/{deviceId}");
        deleteResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        // Verify deletion
        HttpResponseMessage finalResponse = await _client.GetAsync($"/api/devices/{deviceId}");
        finalResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task ConcurrentDeviceOperations_ShouldHandleGracefully()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        // Act - Perform multiple concurrent operations
        var tasks = new List<Task<HttpResponseMessage>>();

        // Multiple GET requests
        for (var i = 0; i < 5; i++)
        {
            tasks.Add(_client.GetAsync("/api/devices"));
        }

        // Multiple scan requests
        for (var i = 0; i < 3; i++)
        {
            tasks.Add(_client.PostAsync("/api/devices/scan", null));
        }

        HttpResponseMessage[] responses = await Task.WhenAll(tasks);

        // Assert
        responses.Should().OnlyContain(r => r.IsSuccessStatusCode);

        // Verify all GET requests returned valid data
        IEnumerable<HttpResponseMessage> getResponses = responses.Take(5);
        foreach (HttpResponseMessage? response in getResponses)
        {
            UsbDevice[]? devices = await response.Content.ReadFromJsonAsync<UsbDevice[]>();
            devices.Should().NotBeNull();
        }
    }
}
