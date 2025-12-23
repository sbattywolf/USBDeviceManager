using AutoFixture;
using Bogus;
using USBDeviceManager.Models;

namespace USBDeviceManager.Tests.Helpers;

/// <summary>
/// Test data generator using Bogus for realistic test data
/// Follows same patterns as PowerShell agent test data generation
/// </summary>
public static class TestDataGenerator
{
    private static readonly Fixture _fixture = new();

    /// <summary>
    /// Generate realistic USB devices for testing
    /// </summary>
    public static List<UsbDevice> GenerateTestDevices(int count = 5)
    {
        var deviceFaker = new Faker<UsbDevice>()
            .RuleFor(d => d.DeviceId, f => $"USB\\VID_{f.Random.Hexadecimal(4, "").ToUpper()}&PID_{f.Random.Hexadecimal(4, "").ToUpper()}")
            .RuleFor(d => d.Name, f => f.PickRandom(new[]
            {
                "Logitech G29 Racing Wheel",
                "Thrustmaster T300 RS",
                "Fanatec ClubSport Wheel Base",
                "Logitech G27 Racing Wheel",
                "Thrustmaster TMX Force Feedback",
                "Fanatec CSL Elite Pedals",
                "SimRacing Hardware Handbrake",
                "USB Gaming Controller",
                "Racing Pedal Set",
                "Steering Wheel Base"
            }))
            .RuleFor(d => d.VendorId, f => f.Random.Hexadecimal(4, "").ToUpper())
            .RuleFor(d => d.ProductId, f => f.Random.Hexadecimal(4, "").ToUpper())
            .RuleFor(d => d.Description, f => f.Lorem.Sentence(3, 8))
            .RuleFor(d => d.IsEnabled, f => f.Random.Bool(0.8f))
            .RuleFor(d => d.LastSeen, f => f.Date.Recent(7))
            .RuleFor(d => d.CreatedAt, f => f.Date.Past(1));

        return deviceFaker.Generate(count);
    }

    /// <summary>
    /// Generate realistic software entries for testing
    /// </summary>
    public static List<ManagedSoftware> GenerateTestSoftware(int count = 3)
    {
        var softwareFaker = new Faker<ManagedSoftware>()
            .RuleFor(s => s.Name, f => f.PickRandom(new[]
            {
                "iRacing",
                "Assetto Corsa Competizione",
                "F1 23",
                "Dirt Rally 2.0",
                "rFactor 2",
                "Project CARS 3",
                "Gran Turismo 7",
                "Forza Horizon 5",
                "BeamNG.drive",
                "SimHub"
            }))
            .RuleFor(s => s.ExecutablePath, (f, s) => GenerateExecutablePath(s.Name))
            .RuleFor(s => s.StartupArguments, f => f.Random.Bool(0.3f) ? string.Join(" ", f.Lorem.Words(3)) : null)
            .RuleFor(s => s.WorkingDirectory, (f, s) => Path.GetDirectoryName(s.ExecutablePath))
            .RuleFor(s => s.AutoStart, f => f.Random.Bool(0.2f))
            .RuleFor(s => s.IsEnabled, f => f.Random.Bool(0.9f))
            .RuleFor(s => s.CreatedAt, f => f.Date.Past(1));

        return softwareFaker.Generate(count);
    }

    /// <summary>
    /// Generate automation rules with proper relationships
    /// </summary>
    public static List<AutomationRule> GenerateTestAutomationRules(int count, List<UsbDevice> devices, List<ManagedSoftware> software)
    {
        var ruleFaker = new Faker<AutomationRule>()
            .RuleFor(r => r.Name, f => f.PickRandom(new[]
            {
                "Start iRacing when G29 connects",
                "Launch SimHub on system startup",
                "Stop all racing games when wheel disconnects",
                "Auto-start Assetto Corsa on wheel connection",
                "Launch telemetry software on game start",
                "Emergency stop on device disconnect"
            }))
            .RuleFor(r => r.Description, f => f.Lorem.Sentence(5, 15))
            .RuleFor(r => r.Trigger, f => f.PickRandom<AutomationTrigger>())
            .RuleFor(r => r.Action, f => f.PickRandom<AutomationAction>())
            .RuleFor(r => r.TriggerDeviceId, f => devices.Any() ? f.PickRandom(devices).Id : null)
            .RuleFor(r => r.TargetSoftwareId, f => software.Any() ? f.PickRandom(software).Id : null)
            .RuleFor(r => r.IsEnabled, f => f.Random.Bool(0.85f))
            .RuleFor(r => r.CreatedAt, f => f.Date.Past(1));

        return ruleFaker.Generate(count);
    }

    /// <summary>
    /// Generate device status entries
    /// </summary>
    public static List<DeviceStatus> GenerateDeviceStatuses(IEnumerable<UsbDevice> devices, int entriesPerDevice = 5)
    {
        var statusFaker = new Faker<DeviceStatus>()
            .RuleFor(s => s.IsConnected, f => f.Random.Bool(0.7f))
            .RuleFor(s => s.Status, (f, s) => s.IsConnected ? "Connected" : f.PickRandom("Disconnected", "Error", "Timeout"))
            .RuleFor(s => s.ErrorMessage, (f, s) => !s.IsConnected && f.Random.Bool(0.3f) ? f.Lorem.Sentence() : null)
            .RuleFor(s => s.Timestamp, f => f.Date.Recent(1));

        var statuses = new List<DeviceStatus>();
        var deviceList = devices.ToList();

        foreach (var device in deviceList)
        {
            var deviceStatuses = statusFaker
                .RuleFor(s => s.DeviceId, device.Id)
                .Generate(entriesPerDevice);

            statuses.AddRange(deviceStatuses);
        }

        return statuses;
    }

    /// <summary>
    /// Generate software status entries
    /// </summary>
    public static List<SoftwareStatus> GenerateSoftwareStatuses(List<ManagedSoftware> software, int entriesPerSoftware = 3)
    {
        var statusFaker = new Faker<SoftwareStatus>()
            // Let EF assign identity Id when persisted
            .RuleFor(s => s.IsRunning, f => f.Random.Bool(0.4f))
            .RuleFor(s => s.ProcessId, (f, s) => s.IsRunning ? f.Random.Int(1000, 9999) : null)
            .RuleFor(s => s.Status, (f, s) => s.IsRunning ? "Running" : f.PickRandom("Stopped", "Failed", "Starting"))
            .RuleFor(s => s.LastStarted, f => f.Date.Recent(7))
            .RuleFor(s => s.LastStopped, f => f.Date.Recent(7))
            .RuleFor(s => s.ErrorMessage, f => f.Random.Bool(0.1f) ? f.Lorem.Sentence() : null)
            .RuleFor(s => s.Timestamp, f => f.Date.Recent(1));

        var statuses = new List<SoftwareStatus>();

        foreach (var sw in software)
        {
            var swStatuses = statusFaker
                .RuleFor(s => s.SoftwareId, sw.Id)
                .Generate(entriesPerSoftware);

            statuses.AddRange(swStatuses);
        }

        return statuses;
    }

    /// <summary>
    /// Generate system status entries
    /// </summary>
    public static List<SystemStatus> GenerateSystemStatuses(int count = 10)
    {
        var statusFaker = new Faker<SystemStatus>()
            // Let EF assign identity Id when persisted
            .RuleFor(s => s.CpuUsage, f => f.Random.Double(5.0, 95.0))
            .RuleFor(s => s.MemoryUsage, f => f.Random.Double(20.0, 85.0))
            .RuleFor(s => s.DiskUsage, f => f.Random.Double(15.0, 75.0))
            .RuleFor(s => s.ConnectedDevices, f => f.Random.Int(0, 10))
            .RuleFor(s => s.RunningSoftware, f => f.Random.Int(0, 5))
            .RuleFor(s => s.ActiveRules, f => f.Random.Int(0, 8))
            .RuleFor(s => s.Timestamp, f => f.Date.Recent(7));

        return statusFaker.Generate(count);
    }

    /// <summary>
    /// Generate health metrics
    /// </summary>
    public static List<HealthMetric> GenerateHealthMetrics(int count = 20)
    {
        var metricFaker = new Faker<HealthMetric>()
            // Let EF assign identity Id when persisted
            .RuleFor(m => m.MetricName, f => f.PickRandom(new[]
            {
                "CPU_Temperature", "Memory_Available", "Disk_Free_Space",
                "Network_Latency", "Process_Count", "Thread_Count",
                "USB_Device_Count", "Active_Connections", "Error_Rate"
            }))
            .RuleFor(m => m.Value, f => f.Random.Double(0.0, 100.0))
            .RuleFor(m => m.Source, f => f.PickRandom("System", "Application", "Hardware", "Network"))
            .RuleFor(m => m.Timestamp, f => f.Date.Recent(1));

        return metricFaker.Generate(count);
    }

    /// <summary>
    /// Create a simple test device for unit tests
    /// </summary>
    public static UsbDevice CreateSimpleTestDevice(string? name = null)
    {
        return new UsbDevice
        {
            // Let EF generate the Id when persisted
            DeviceId = $"USB\\VID_046D&PID_C29A",
            Name = name ?? "Test Racing Wheel",
            VendorId = "046D",
            ProductId = "C29A",
            Description = "Test device for unit testing",
            IsEnabled = true,
            LastSeen = DateTime.UtcNow.AddMinutes(-5),
            CreatedAt = DateTime.UtcNow.AddDays(-1)
        };
    }

    /// <summary>
    /// Create a simple test software for unit tests
    /// </summary>
    public static ManagedSoftware CreateSimpleTestSoftware(string? name = null)
    {
        var softwareName = name ?? "Test Racing Game";

        return new ManagedSoftware
        {
            Name = softwareName,
            ExecutablePath = $@"C:\Games\{softwareName}\{softwareName}.exe",
            StartupArguments = "--test-mode",
            WorkingDirectory = $@"C:\Games\{softwareName}",
            AutoStart = false,
            IsEnabled = true,
            CreatedAt = DateTime.UtcNow.AddDays(-1)
        };
    }

    private static string GenerateExecutablePath(string softwareName)
    {
        var cleanName = softwareName.Replace(" ", "").Replace(":", "");
        var possiblePaths = new[]
        {
            $@"C:\Program Files\{softwareName}\{cleanName}.exe",
            $@"C:\Program Files (x86)\{softwareName}\{cleanName}.exe",
            $@"C:\Games\{softwareName}\{cleanName}.exe",
            $@"D:\SteamLibrary\steamapps\common\{softwareName}\{cleanName}.exe"
        };

        return possiblePaths[new Random().Next(possiblePaths.Length)];
    }
}
