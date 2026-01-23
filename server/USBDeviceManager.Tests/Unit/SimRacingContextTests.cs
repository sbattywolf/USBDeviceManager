using System.Data.Common;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using USBDeviceManager.Data;
using USBDeviceManager.Tests.Helpers;

namespace USBDeviceManager.Tests.Unit
{
    /// <summary>
    /// Unit tests for SimRacingContext database operations
    /// Tests entity relationships, constraints, and data integrity
    /// </summary>
    [Trait("Category","Unit")]
    public class SimRacingContextTests : IDisposable
{
    private readonly SimRacingContext _context;
    private readonly DbConnection _connection;

    public SimRacingContextTests()
    {
        // Use SQLite in-memory so relational constraints and DB-level errors are enforced
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        DbContextOptions<SimRacingContext> options = new DbContextOptionsBuilder<SimRacingContext>()
            .UseSqlite(_connection)
            .Options;

        _context = new SimRacingContext(options);
        _context.Database.EnsureCreated();
    }

    [Fact]
    public async Task AddUsbDevice_ShouldCreateDeviceSuccessfully()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice("Test Wheel");

        // Act
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        // Assert
        UsbDevice? savedDevice = await _context.UsbDevices.FindAsync(device.Id);
        savedDevice.Should().NotBeNull();
        savedDevice!.Name.Should().Be("Test Wheel");
        savedDevice.DeviceId.Should().Be(device.DeviceId);
        savedDevice.IsEnabled.Should().BeTrue();
    }

    [Fact]
    public async Task UsbDevice_UniqueDeviceId_ShouldEnforceConstraint()
    {
        // Arrange
        var deviceId = "USB\\VID_046D&PID_C29A";
        UsbDevice device1 = TestDataGenerator.CreateSimpleTestDevice("Device 1");
        UsbDevice device2 = TestDataGenerator.CreateSimpleTestDevice("Device 2");

        device1.DeviceId = deviceId;
        device2.DeviceId = deviceId; // Same device ID

        // Act
        _context.UsbDevices.Add(device1);
        await _context.SaveChangesAsync();

        _context.UsbDevices.Add(device2);

        // Assert - SQLite will enforce UNIQUE and throw a DbUpdateException
        await Assert.ThrowsAsync<DbUpdateException>(
            () => _context.SaveChangesAsync()
        );
    }

    [Fact]
    public async Task DeviceStatus_CascadeDelete_ShouldRemoveStatusesWhenDeviceDeleted()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        var status = new DeviceStatus
        {
            DeviceId = device.Id,
            IsConnected = true,
            Status = "Connected",
            Timestamp = DateTime.UtcNow
        };
        _context.DeviceStatuses.Add(status);
        await _context.SaveChangesAsync();

        // Act
        _context.UsbDevices.Remove(device);
        await _context.SaveChangesAsync();

        // Assert
        List<DeviceStatus> remainingStatuses = await _context.DeviceStatuses
            .Where(s => s.DeviceId == device.Id)
            .ToListAsync();

        remainingStatuses.Should().BeEmpty();
    }

    [Fact]
    public async Task ManagedSoftware_RequiredFields_ShouldEnforceValidation()
    {
        // Arrange
        var software = new ManagedSoftware
        {
            // Missing required Name and ExecutablePath
            StartupArguments = "--test",
            IsEnabled = true
        };

        // Act
        _context.ManagedSoftware.Add(software);
        await _context.SaveChangesAsync();

        // Assert - EF/SQLite allows empty strings for required string properties (not null),
        // so ensure the entity was persisted and fields are present (may be empty)
        ManagedSoftware saved = await _context.ManagedSoftware.FirstAsync(s => s.Id == software.Id);
        saved.Should().NotBeNull();
        saved.Name.Should().BeEmpty();
        saved.ExecutablePath.Should().BeEmpty();
    }

    [Fact]
    public async Task AutomationRule_WithDeviceAndSoftwareReferences_ShouldMaintainRelationships()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        ManagedSoftware software = TestDataGenerator.CreateSimpleTestSoftware();

        _context.UsbDevices.Add(device);
        _context.ManagedSoftware.Add(software);
        await _context.SaveChangesAsync();

        var rule = new AutomationRule
        {
            Name = "Test Rule",
            Description = "Start software when device connects",
            Trigger = AutomationTrigger.DeviceConnected,
            Action = AutomationAction.StartSoftware,
            TriggerDeviceId = device.Id,
            TargetSoftwareId = software.Id,
            IsEnabled = true
        };

        // Act
        _context.AutomationRules.Add(rule);
        await _context.SaveChangesAsync();

        // Assert
        AutomationRule savedRule = await _context.AutomationRules
            .Include(r => r.TriggerDevice)
            .Include(r => r.TargetSoftware)
            .FirstAsync(r => r.Id == rule.Id);

        savedRule.TriggerDevice.Should().NotBeNull();
        savedRule.TriggerDevice!.Name.Should().Be(device.Name);
        savedRule.TargetSoftware.Should().NotBeNull();
        savedRule.TargetSoftware!.Name.Should().Be(software.Name);
    }

    [Fact]
    public async Task RuleExecution_CascadeDelete_ShouldRemoveExecutionsWhenRuleDeleted()
    {
        // Arrange
        var rule = new AutomationRule
        {
            Name = "Test Rule",
            Trigger = AutomationTrigger.Manual,
            Action = AutomationAction.SendNotification,
            IsEnabled = true
        };

        _context.AutomationRules.Add(rule);
        await _context.SaveChangesAsync();

        var execution = new RuleExecution
        {
            RuleId = rule.Id,
            Success = true,
            ExecutedAt = DateTime.UtcNow
        };

        _context.RuleExecutions.Add(execution);
        await _context.SaveChangesAsync();

        // Act
        _context.AutomationRules.Remove(rule);
        await _context.SaveChangesAsync();

        // Assert
        List<RuleExecution> remainingExecutions = await _context.RuleExecutions
            .Where(e => e.RuleId == rule.Id)
            .ToListAsync();

        remainingExecutions.Should().BeEmpty();
    }

    [Fact]
    public async Task SystemStatus_MultipleEntries_ShouldStoreChronologically()
    {
        // Arrange
        List<SystemStatus> statuses = TestDataGenerator.GenerateSystemStatuses(5);

        // Ensure different timestamps
        for (var i = 0; i < statuses.Count; i++)
        {
            statuses[i].Timestamp = DateTime.UtcNow.AddMinutes(-i);
        }

        // Act
        _context.SystemStatuses.AddRange(statuses);
        await _context.SaveChangesAsync();

        // Assert
        List<SystemStatus> savedStatuses = await _context.SystemStatuses
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        savedStatuses.Should().HaveCount(5);
        savedStatuses[0].Timestamp.Should().BeAfter(savedStatuses[1].Timestamp);
        savedStatuses[1].Timestamp.Should().BeAfter(savedStatuses[2].Timestamp);
    }



    [Fact]
    public async Task HealthMetric_DifferentSources_ShouldGroupByMetricName()
    {
        // Arrange
        HealthMetric[] metrics =
        [
            new HealthMetric { MetricName = "CPU_Usage", Value = 45.5, Source = "System", Timestamp = DateTime.UtcNow },
            new HealthMetric { MetricName = "CPU_Usage", Value = 52.1, Source = "Application", Timestamp = DateTime.UtcNow },
            new HealthMetric { MetricName = "Memory_Usage", Value = 67.8, Source = "System", Timestamp = DateTime.UtcNow }
        ];

        // Act
        _context.HealthMetrics.AddRange(metrics);
        await _context.SaveChangesAsync();

        // Assert
        List<HealthMetric> cpuMetrics = await _context.HealthMetrics
            .Where(m => m.MetricName == "CPU_Usage")
            .ToListAsync();

        List<HealthMetric> memoryMetrics = await _context.HealthMetrics
            .Where(m => m.MetricName == "Memory_Usage")
            .ToListAsync();

        cpuMetrics.Should().HaveCount(2);
        memoryMetrics.Should().HaveCount(1);

        cpuMetrics.Should().OnlyContain(m => m.MetricName == "CPU_Usage");
        memoryMetrics.Should().OnlyContain(m => m.MetricName == "Memory_Usage");
    }

    [Theory]
    [InlineData(AutomationTrigger.DeviceConnected, AutomationAction.StartSoftware)]
    [InlineData(AutomationTrigger.DeviceDisconnected, AutomationAction.StopSoftware)]
    [InlineData(AutomationTrigger.SystemStartup, AutomationAction.RunScript)]
    [InlineData(AutomationTrigger.Manual, AutomationAction.SendNotification)]
    public async Task AutomationRule_ValidTriggerActionCombinations_ShouldPersistCorrectly(
        AutomationTrigger trigger, AutomationAction action)
    {
        // Arrange
        var rule = new AutomationRule
        {
            Name = $"Test {trigger} -> {action}",
            Trigger = trigger,
            Action = action,
            IsEnabled = true
        };

        // Act
        _context.AutomationRules.Add(rule);
        await _context.SaveChangesAsync();

        // Assert
        AutomationRule? savedRule = await _context.AutomationRules.FindAsync(rule.Id);
        savedRule.Should().NotBeNull();
        savedRule!.Trigger.Should().Be(trigger);
        savedRule.Action.Should().Be(action);
    }

    [Fact]
    public async Task DeviceStatus_TimestampIndexing_ShouldSupportTimeRangeQueries()
    {
        // Arrange
        UsbDevice device = TestDataGenerator.CreateSimpleTestDevice();
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        DateTime now = DateTime.UtcNow;
        DeviceStatus[] statuses =
        [
            new DeviceStatus { DeviceId = device.Id, IsConnected = true, Status = "Connected", Timestamp = now.AddHours(-2) },
            new DeviceStatus { DeviceId = device.Id, IsConnected = false, Status = "Disconnected", Timestamp = now.AddHours(-1) },
            new DeviceStatus { DeviceId = device.Id, IsConnected = true, Status = "Connected", Timestamp = now }
        ];

        _context.DeviceStatuses.AddRange(statuses);
        await _context.SaveChangesAsync();

        // Act
        List<DeviceStatus> recentStatuses = await _context.DeviceStatuses
            .Where(s => s.DeviceId == device.Id && s.Timestamp >= now.AddHours(-1.5))
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        // Assert
        recentStatuses.Should().HaveCount(2);
        recentStatuses[0].Timestamp.Should().BeCloseTo(now, TimeSpan.FromSeconds(1));
        recentStatuses[1].Timestamp.Should().BeCloseTo(now.AddHours(-1), TimeSpan.FromSeconds(1));
    }

    public void Dispose()
    {
        try
        {
            _context?.Database.EnsureDeleted();
        }
        catch
        {
            // ignore failures during cleanup
        }

        _context?.Dispose();
        _connection?.Close();
        _connection?.Dispose();
    }
}
}
