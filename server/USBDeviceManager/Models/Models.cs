// <copyright file="Models.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

// </copyright>
namespace USBDeviceManager.Models;

using System.ComponentModel.DataAnnotations;

/// <summary>
/// Represents a USB device tracked by the system.
/// </summary>
public class UsbDevice
{
    /// <summary>
    /// Gets or sets the primary key identifier.
    /// </summary>
    public int Id
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the device identifier string reported by the platform.
    /// </summary>
    [Required]
    public string DeviceId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the display name for the device.
    /// </summary>
    [Required]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the vendor identifier (if available).
    /// </summary>
    public string? VendorId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the product identifier (if available).
    /// </summary>
    public string? ProductId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets an optional description for the device.
    /// </summary>
    public string? Description
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets a value indicating whether the device is enabled for automation.
    /// </summary>
    public bool IsEnabled { get; set; } = true;

    /// <summary>
    /// Gets or sets the last time the device was observed connected.
    /// </summary>
    public DateTime LastSeen { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Gets or sets the creation timestamp for the device record.
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Represents the current or historical connection status of a USB device.
/// </summary>
public class DeviceStatus
{
    /// <summary>
    /// Gets or sets the primary key identifier.
    /// </summary>
    public int Id
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the related device identifier.
    /// </summary>
    public int? DeviceId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the related `UsbDevice` instance.
    /// </summary>
    public UsbDevice? Device { get; set; }

    /// <summary>
    /// Gets or sets a value indicating whether the device is currently connected.
    /// </summary>
    public bool IsConnected
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets a short textual status description.
    /// </summary>
    public string Status { get; set; } = "Unknown";

    /// <summary>
    /// Gets or sets an optional error message associated with the status.
    /// </summary>
    public string? ErrorMessage
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the timestamp when the status was recorded.
    /// </summary>
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Represents a software entry managed by the system.
/// </summary>
public class ManagedSoftware
{
    /// <summary>
    /// Gets or sets the primary key identifier.
    /// </summary>
    public int Id
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the display name for the software.
    /// </summary>
    [Required]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the full path to the executable.
    /// </summary>
    [Required]
    public string ExecutablePath { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets optional startup arguments.
    /// </summary>
    public string? StartupArguments
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the working directory for the process.
    /// </summary>
    public string? WorkingDirectory
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets a value indicating whether the software should auto-start.
    /// </summary>
    public bool AutoStart { get; set; } = false;

    /// <summary>
    /// Gets or sets a value indicating whether the software entry is enabled.
    /// </summary>
    public bool IsEnabled { get; set; } = true;

    /// <summary>
    /// Gets or sets the creation timestamp for the software record.
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Represents the runtime status of a managed software entry.
/// </summary>
public class SoftwareStatus
{
    /// <summary>
    /// Gets or sets the primary key identifier.
    /// </summary>
    public int Id
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the related software identifier.
    /// </summary>
    public int SoftwareId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the related `ManagedSoftware` instance.
    /// </summary>
    public ManagedSoftware Software { get; set; } = null!;

    /// <summary>
    /// Gets or sets a value indicating whether the software is currently running.
    /// </summary>
    public bool IsRunning
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the process identifier when running.
    /// </summary>
    public int? ProcessId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets a short textual status description.
    /// </summary>
    public string Status { get; set; } = "Stopped";

    /// <summary>
    /// Gets or sets the last started timestamp.
    /// </summary>
    public DateTime LastStarted
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the last stopped timestamp.
    /// </summary>
    public DateTime LastStopped
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets an optional error message associated with the runtime state.
    /// </summary>
    public string? ErrorMessage
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the timestamp when the status was recorded.
    /// </summary>
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Defines a rule that performs an action when a trigger condition is met.
/// </summary>
public class AutomationRule
{
    /// <summary>
    /// Gets or sets the primary key identifier.
    /// </summary>
    public int Id
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the rule name.
    /// </summary>
    [Required]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets an optional description for the rule.
    /// </summary>
    public string? Description
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the trigger that causes the rule to run.
    /// </summary>
    public AutomationTrigger Trigger
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the action performed when the rule triggers.
    /// </summary>
    public AutomationAction Action
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets an optional device id used by the trigger.
    /// </summary>
    public int? TriggerDeviceId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the device associated with the trigger (if loaded).
    /// </summary>
    public UsbDevice? TriggerDevice
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets an optional target software id for the action.
    /// </summary>
    public int? TargetSoftwareId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the target software associated with the action (if loaded).
    /// </summary>
    public ManagedSoftware? TargetSoftware
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets a value indicating whether the rule is enabled.
    /// </summary>
    public bool IsEnabled { get; set; } = true;

    /// <summary>
    /// Gets or sets the creation timestamp for the rule.
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Records a single execution attempt of an automation rule.
/// </summary>
public class RuleExecution
{
    /// <summary>
    /// Gets or sets the primary key identifier.
    /// </summary>
    public int Id
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the automation rule identifier.
    /// </summary>
    public int RuleId
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the referenced automation rule.
    /// </summary>
    public AutomationRule Rule { get; set; } = null!;

    /// <summary>
    /// Gets or sets a value indicating whether the execution succeeded.
    /// </summary>
    public bool Success
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets an optional error message if execution failed.
    /// </summary>
    public string? ErrorMessage
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the timestamp when the rule was executed.
    /// </summary>
    public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Aggregated system status information (metrics and counts).
/// </summary>
public class SystemStatus
{
    /// <summary>
    /// Gets or sets the primary key identifier.
    /// </summary>
    public int Id
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets CPU usage as a percentage (0-100).
    /// </summary>
    public double CpuUsage
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets memory usage as a percentage (0-100).
    /// </summary>
    public double MemoryUsage
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets disk usage as a percentage (0-100).
    /// </summary>
    public double DiskUsage
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the number of connected devices.
    /// </summary>
    public int ConnectedDevices
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the number of running software entries.
    /// </summary>
    public int RunningSoftware
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the number of active automation rules.
    /// </summary>
    public int ActiveRules
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the timestamp when the metrics were sampled.
    /// </summary>
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// A single health metric sampled from the system.
/// </summary>
public class HealthMetric
{
    /// <summary>
    /// Gets or sets the primary key identifier.
    /// </summary>
    public int Id
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the metric name (e.g., "gpu_temperature").
    /// </summary>
    [Required]
    public string MetricName { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the numeric value for the metric.
    /// </summary>
    public double Value
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets an optional source identifier for the metric.
    /// </summary>
    public string? Source
    {
        get; set;
    }

    /// <summary>
    /// Gets or sets the timestamp when the metric was recorded.
    /// </summary>
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Triggers that cause an automation rule to execute.
/// </summary>
public enum AutomationTrigger
{
    /// <summary>
    /// Triggered when a device is connected.
    /// </summary>
    DeviceConnected,

    /// <summary>
    /// Triggered when a device is disconnected.
    /// </summary>
    DeviceDisconnected,

    /// <summary>
    /// Triggered when software starts.
    /// </summary>
    SoftwareStarted,

    /// <summary>
    /// Triggered when software stops.
    /// </summary>
    SoftwareStopped,

    /// <summary>
    /// Triggered on system startup.
    /// </summary>
    SystemStartup,

    /// <summary>
    /// Triggered on system shutdown.
    /// </summary>
    SystemShutdown,

    /// <summary>
    /// Manual trigger invoked by a user or external process.
    /// </summary>
    Manual,
}

/// <summary>
/// Actions that an automation rule can perform.
/// </summary>
public enum AutomationAction
{
    /// <summary>
    /// Start the target software.
    /// </summary>
    StartSoftware,

    /// <summary>
    /// Stop the target software.
    /// </summary>
    StopSoftware,

    /// <summary>
    /// Restart the target software.
    /// </summary>
    RestartSoftware,

    /// <summary>
    /// Enable the specified device.
    /// </summary>
    EnableDevice,

    /// <summary>
    /// Disable the specified device.
    /// </summary>
    DisableDevice,

    /// <summary>
    /// Send a notification (e.g., user-facing message).
    /// </summary>
    SendNotification,

    /// <summary>
    /// Run a script or command.
    /// </summary>
    RunScript,
}
