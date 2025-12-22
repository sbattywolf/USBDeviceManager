using System.ComponentModel.DataAnnotations;

namespace SimRacingDashboard.Models;

public class UsbDevice
{
    public int Id { get; set; }
    
    [Required]
    public string DeviceId { get; set; } = string.Empty;
    
    [Required]
    public string Name { get; set; } = string.Empty;
    
    public string? VendorId { get; set; }
    
    public string? ProductId { get; set; }
    
    public string? Description { get; set; }
    
    public bool IsEnabled { get; set; } = true;
    
    public DateTime LastSeen { get; set; } = DateTime.UtcNow;
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class DeviceStatus
{
    public int Id { get; set; }
    
    public int DeviceId { get; set; }
    
    public UsbDevice Device { get; set; } = null!;
    
    public bool IsConnected { get; set; }
    
    public string Status { get; set; } = "Unknown";
    
    public string? ErrorMessage { get; set; }
    
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

public class ManagedSoftware
{
    public int Id { get; set; }
    
    [Required]
    public string Name { get; set; } = string.Empty;
    
    [Required]
    public string ExecutablePath { get; set; } = string.Empty;
    
    public string? StartupArguments { get; set; }
    
    public string? WorkingDirectory { get; set; }
    
    public bool AutoStart { get; set; } = false;
    
    public bool IsEnabled { get; set; } = true;
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class SoftwareStatus
{
    public int Id { get; set; }
    
    public int SoftwareId { get; set; }
    
    public ManagedSoftware Software { get; set; } = null!;
    
    public bool IsRunning { get; set; }
    
    public int? ProcessId { get; set; }
    
    public string Status { get; set; } = "Stopped";
    
    public DateTime LastStarted { get; set; }
    
    public DateTime LastStopped { get; set; }
    
    public string? ErrorMessage { get; set; }
    
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

public class AutomationRule
{
    public int Id { get; set; }
    
    [Required]
    public string Name { get; set; } = string.Empty;
    
    public string? Description { get; set; }
    
    public AutomationTrigger Trigger { get; set; }
    
    public AutomationAction Action { get; set; }
    
    public int? TriggerDeviceId { get; set; }
    
    public UsbDevice? TriggerDevice { get; set; }
    
    public int? TargetSoftwareId { get; set; }
    
    public ManagedSoftware? TargetSoftware { get; set; }
    
    public bool IsEnabled { get; set; } = true;
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class RuleExecution
{
    public int Id { get; set; }
    
    public int RuleId { get; set; }
    
    public AutomationRule Rule { get; set; } = null!;
    
    public bool Success { get; set; }
    
    public string? ErrorMessage { get; set; }
    
    public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;
}

public class SystemStatus
{
    public int Id { get; set; }
    
    public double CpuUsage { get; set; }
    
    public double MemoryUsage { get; set; }
    
    public double DiskUsage { get; set; }
    
    public int ConnectedDevices { get; set; }
    
    public int RunningSoftware { get; set; }
    
    public int ActiveRules { get; set; }
    
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

public class HealthMetric
{
    public int Id { get; set; }
    
    [Required]
    public string MetricName { get; set; } = string.Empty;
    
    public double Value { get; set; }
    
    public string? Source { get; set; }
    
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

public enum AutomationTrigger
{
    DeviceConnected,
    DeviceDisconnected,
    SoftwareStarted,
    SoftwareStopped,
    SystemStartup,
    SystemShutdown,
    Manual
}

public enum AutomationAction
{
    StartSoftware,
    StopSoftware,
    RestartSoftware,
    EnableDevice,
    DisableDevice,
    SendNotification,
    RunScript
}