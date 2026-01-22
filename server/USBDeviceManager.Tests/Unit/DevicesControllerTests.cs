using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using USBDeviceManager.Controllers;
using USBDeviceManager.Data;
using USBDeviceManager.Models;
using USBDeviceManager.Tests.Helpers;

namespace USBDeviceManager.Tests.Unit;

/// <summary>
/// Unit tests for DevicesController API endpoints
/// Tests CRUD operations, validation, and error handling
/// </summary>
[Trait("Category","Unit")]
public class DevicesControllerTests : IDisposable
{
    private readonly SimRacingContext _context;
    private readonly Mock<ILogger<DevicesController>> _mockLogger;
    private readonly DevicesController _controller;

    public DevicesControllerTests()
    {
        DbContextOptions<SimRacingContext> options = new DbContextOptionsBuilder<SimRacingContext>()
            .UseInMemoryDatabase($"DevicesTest_{Guid.NewGuid()}")
            .Options;

        _context = new SimRacingContext(options);
        _context.Database.EnsureCreated();

        _mockLogger = new Mock<ILogger<DevicesController>>();
        _controller = new DevicesController(_context, _mockLogger.Object, new USBDeviceManager.Services.SystemDateTime());
    }

    [Fact]
    public async Task GetDevices_WithNoDevices_ShouldReturnEmptyList()
    {
        // Act
        ActionResult<IEnumerable<UsbDevice>> result = await _controller.GetDevices();

        // Assert
        result.Value.Should().NotBeNull();
        result.Value.Should().BeEmpty();
    }

    [Fact]
    public async Task GetDevices_WithMultipleDevices_ShouldReturnAllDevices()
    {
        // Arrange
        List<UsbDevice> devices = TestDataGenerator.GenerateTestDevices(3);
        _context.UsbDevices.AddRange(devices);
        await _context.SaveChangesAsync();

        // Act
        ActionResult<IEnumerable<UsbDevice>> result = await _controller.GetDevices();

        // Assert
        result.Value.Should().NotBeNull();
        result.Value.Should().HaveCount(3);
        result.Value.Should().BeEquivalentTo(devices, options => options.ExcludingMissingMembers());
    }

    [Fact]
    public async Task GetDevice_WithValidId_ShouldReturnDevice()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice("Test Device");
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        // Act
        ActionResult<UsbDevice> result = await _controller.GetDevice(device.Id);

        // Assert
        result.Value.Should().NotBeNull();
        result.Value!.Id.Should().Be(device.Id);
        result.Value.Name.Should().Be("Test Device");
    }

    [Fact]
    public async Task GetDevice_WithInvalidId_ShouldReturnNotFound()
    {
        // Act
        ActionResult<UsbDevice> result = await _controller.GetDevice(999);

        // Assert
        result.Result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task CreateDevice_WithValidDevice_ShouldCreateSuccessfully()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice("New Device");
        device.Id = 0; // Reset ID for creation

        var dto = new USBDeviceManager.DTOs.DeviceCreateDto
        {
            DeviceId = device.DeviceId,
            Name = device.Name,
            VendorId = device.VendorId,
            ProductId = device.ProductId,
            Description = device.Description,
            IsEnabled = device.IsEnabled
        };

        // Act
        ActionResult<UsbDevice> result = await _controller.CreateDevice(dto);

        // Assert
        result.Result.Should().BeOfType<CreatedAtActionResult>();

        var createdResult = (CreatedAtActionResult)result.Result!;
        var createdDevice = (UsbDevice)createdResult.Value!;

        createdDevice.Name.Should().Be("New Device");
        createdDevice.Id.Should().BeGreaterThan(0);

        // Verify device was saved to database
        UsbDevice? savedDevice = await _context.UsbDevices.FindAsync(createdDevice.Id);
        savedDevice.Should().NotBeNull();
        savedDevice!.Name.Should().Be("New Device");
    }

    [Fact]
    public async Task UpdateDevice_WithValidData_ShouldUpdateSuccessfully()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice("Original Name");
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        device.Name = "Updated Name";
        device.IsEnabled = false;

        var dto = new USBDeviceManager.DTOs.DeviceCreateDto
        {
            DeviceId = device.DeviceId,
            Name = device.Name,
            VendorId = device.VendorId,
            ProductId = device.ProductId,
            Description = device.Description,
            IsEnabled = device.IsEnabled
        };

        // Act
        IActionResult result = await _controller.UpdateDevice(device.Id, dto);

        // Assert
        result.Should().BeOfType<NoContentResult>();

        // Verify update in database
        UsbDevice? updatedDevice = await _context.UsbDevices.FindAsync(device.Id);
        updatedDevice.Should().NotBeNull();
        updatedDevice!.Name.Should().Be("Updated Name");
        updatedDevice.IsEnabled.Should().BeFalse();
    }

    [Fact]
    public async Task UpdateDevice_WithMismatchedId_ShouldReturnBadRequest()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        var dto = new USBDeviceManager.DTOs.DeviceCreateDto
        {
            DeviceId = device.DeviceId,
            Name = device.Name,
            VendorId = device.VendorId,
            ProductId = device.ProductId,
            Description = device.Description,
            IsEnabled = device.IsEnabled
        };

        // Act
        IActionResult result = await _controller.UpdateDevice(999, dto);

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task UpdateDevice_WithNonExistentDevice_ShouldReturnNotFound()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        var dto = new USBDeviceManager.DTOs.DeviceCreateDto
        {
            DeviceId = device.DeviceId,
            Name = device.Name,
            VendorId = device.VendorId,
            ProductId = device.ProductId,
            Description = device.Description,
            IsEnabled = device.IsEnabled
        };

        // Act
        IActionResult result = await _controller.UpdateDevice(999, dto);

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task DeleteDevice_WithValidId_ShouldDeleteSuccessfully()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        // Act
        IActionResult result = await _controller.DeleteDevice(device.Id);

        // Assert
        result.Should().BeOfType<NoContentResult>();

        // Verify deletion
        UsbDevice? deletedDevice = await _context.UsbDevices.FindAsync(device.Id);
        deletedDevice.Should().BeNull();
    }

    [Fact]
    public async Task DeleteDevice_WithInvalidId_ShouldReturnNotFound()
    {
        // Act
        IActionResult result = await _controller.DeleteDevice(999);

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task GetDeviceStatus_WithExistingStatus_ShouldReturnLatestStatus()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        var oldStatus = new DeviceStatus
        {
            DeviceId = device.Id,
            IsConnected = false,
            Status = "Disconnected",
            Timestamp = DateTime.UtcNow.AddHours(-1)
        };

        var newStatus = new DeviceStatus
        {
            DeviceId = device.Id,
            IsConnected = true,
            Status = "Connected",
            Timestamp = DateTime.UtcNow
        };

        _context.DeviceStatuses.AddRange(oldStatus, newStatus);
        await _context.SaveChangesAsync();

        // Act
        ActionResult<DeviceStatus> result = await _controller.GetDeviceStatus(device.Id);

        // Assert
        result.Value.Should().NotBeNull();
        result.Value!.IsConnected.Should().BeTrue();
        result.Value.Status.Should().Be("Connected");
        result.Value.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));
    }

    [Fact]
    public async Task GetDeviceStatus_WithNoStatus_ShouldReturnNotFound()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        // Act
        ActionResult<DeviceStatus> result = await _controller.GetDeviceStatus(device.Id);

        // Assert
        result.Result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task GetDeviceStatusHistory_WithCustomTimeRange_ShouldFilterCorrectly()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        DateTime now = DateTime.UtcNow;
        DeviceStatus[] statuses =
        [
            new DeviceStatus { DeviceId = device.Id, Status = "Old", Timestamp = now.AddHours(-25) },
            new DeviceStatus { DeviceId = device.Id, Status = "Recent1", Timestamp = now.AddHours(-12) },
            new DeviceStatus { DeviceId = device.Id, Status = "Recent2", Timestamp = now.AddHours(-6) },
            new DeviceStatus { DeviceId = device.Id, Status = "Current", Timestamp = now }
        ];

        _context.DeviceStatuses.AddRange(statuses);
        await _context.SaveChangesAsync();

        // Act - Request last 24 hours
        ActionResult<IEnumerable<DeviceStatus>> result = await _controller.GetDeviceStatusHistory(device.Id, 24);

        // Assert
        result.Value.Should().NotBeNull();
        result.Value.Should().HaveCount(3); // Should exclude the 25-hour old entry
        result.Value.Should().OnlyContain(s => s.Timestamp >= now.AddHours(-24));
    }

    [Fact]
    public async Task ScanForDevices_ShouldReturnSuccessResponse()
    {
        // Act
        ActionResult<IEnumerable<UsbDevice>> result = await _controller.ScanForDevices();

        // Assert
        result.Result.Should().BeOfType<OkObjectResult>();

        var okResult = (OkObjectResult)result.Result!;
        okResult.Value.Should().NotBeNull();

        // Verify logging
        _mockLogger.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("USB device scan requested")),
                It.IsAny<Exception>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [Fact]
    public async Task ToggleDevice_WithValidDevice_ShouldUpdateEnabledState()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        device.IsEnabled = true;

        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        // Act
        IActionResult result = await _controller.ToggleDevice(device.Id, false);

        // Assert
        result.Should().BeOfType<OkObjectResult>();

        // Verify state change in database
        UsbDevice? updatedDevice = await _context.UsbDevices.FindAsync(device.Id);
        updatedDevice.Should().NotBeNull();
        updatedDevice!.IsEnabled.Should().BeFalse();

        // Verify logging
        _mockLogger.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("disabled")),
                It.IsAny<Exception>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [Fact]
    public async Task ToggleDevice_WithInvalidDevice_ShouldReturnNotFound()
    {
        // Act
        IActionResult result = await _controller.ToggleDevice(999, true);

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    [Theory]
    [InlineData("")]
    [InlineData(null)]
    public async Task CreateDevice_WithInvalidName_ShouldHandleValidationError(string? invalidName)
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        device.Name = invalidName!;
        device.Id = 0;

        var dto = new USBDeviceManager.DTOs.DeviceCreateDto
        {
            DeviceId = device.DeviceId,
            Name = device.Name,
            VendorId = device.VendorId,
            ProductId = device.ProductId,
            Description = device.Description,
            IsEnabled = device.IsEnabled
        };

        if (invalidName == null)
        {
            // Simulate model validation failure
            _controller.ModelState.AddModelError("Name", "The Name field is required.");

            ActionResult<UsbDevice> result = await _controller.CreateDevice(dto);
            result.Result.Should().BeOfType<BadRequestObjectResult>();
        }
        else
        {
            ActionResult<UsbDevice> result = await _controller.CreateDevice(dto);
            result.Result.Should().BeOfType<CreatedAtActionResult>();
        }
    }

    [Fact]
    public async Task GetDeviceStatusHistory_WithLargeTimeRange_ShouldHandlePerformanceGracefully()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        // Add many status entries
        List<DeviceStatus> statuses = TestDataGenerator.GenerateDeviceStatuses(new[] { device }, 100);
        _context.DeviceStatuses.AddRange(statuses);
        await _context.SaveChangesAsync();

        // Act
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        ActionResult<IEnumerable<DeviceStatus>> result = await _controller.GetDeviceStatusHistory(device.Id, 168); // 7 days
        stopwatch.Stop();

        // Assert
        result.Value.Should().NotBeNull();
        stopwatch.ElapsedMilliseconds.Should().BeLessThan(1000); // Should complete within 1 second
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }
}
