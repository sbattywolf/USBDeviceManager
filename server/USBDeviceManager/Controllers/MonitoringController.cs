// <copyright file="MonitoringController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Controllers;

using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using USBDeviceManager.Data;
using USBDeviceManager.Models;

/// <summary>
/// Controller for retrieving monitoring and health information.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class MonitoringController : ControllerBase
{
    private readonly SimRacingContext context;
    private readonly ILogger<MonitoringController> logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="MonitoringController"/> class.
    /// </summary>
    /// <param name="context">Database context.</param>
    /// <param name="logger">Logger instance.</param>
    public MonitoringController(SimRacingContext context, ILogger<MonitoringController> logger)
    {
        this.context = context;
        this.logger = logger;
    }

    /// <summary>
    /// Get current system status.
    /// </summary>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("status")]
    public async Task<ActionResult<SystemStatus>> GetSystemStatus()
    {
        SystemStatus? status = await this.context.SystemStatuses
            .OrderByDescending(s => s.Timestamp)
            .FirstOrDefaultAsync();

        if (status == null)
        {
            // Generate current status if none exists
            status = await this.GenerateCurrentSystemStatus();
            this.context.SystemStatuses.Add(status);
            await this.context.SaveChangesAsync();
        }

        return status;
    }

    /// <summary>
    /// Get system status history.
    /// </summary>
    /// <param name="hours">Time window in hours to include in history.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("status/history")]
    public async Task<ActionResult<IEnumerable<SystemStatus>>> GetSystemStatusHistory([FromQuery] int hours = 24)
    {
        DateTime cutoff = DateTime.UtcNow.AddHours(-hours);

        List<SystemStatus> history = await this.context.SystemStatuses
            .Where(s => s.Timestamp >= cutoff)
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        return history;
    }

    /// <summary>
    /// Get all health metrics.
    /// </summary>
    /// <param name="hours">Time window in hours to include in metrics.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("metrics")]
    public async Task<ActionResult<IEnumerable<HealthMetric>>> GetHealthMetrics([FromQuery] int hours = 24)
    {
        DateTime cutoff = DateTime.UtcNow.AddHours(-hours);

        List<HealthMetric> metrics = await this.context.HealthMetrics
            .Where(m => m.Timestamp >= cutoff)
            .OrderByDescending(m => m.Timestamp)
            .ToListAsync();

        return metrics;
    }

    /// <summary>
    /// Get specific health metric by name.
    /// </summary>
    /// <param name="metricName">Name of the health metric.</param>
    /// <param name="hours">Time window in hours to include in metric history.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("metrics/{metricName}")]
    public async Task<ActionResult<IEnumerable<HealthMetric>>> GetHealthMetric(string metricName, [FromQuery] int hours = 24)
    {
        DateTime cutoff = DateTime.UtcNow.AddHours(-hours);

        List<HealthMetric> metrics = await this.context.HealthMetrics
            .Where(m => m.MetricName == metricName && m.Timestamp >= cutoff)
            .OrderByDescending(m => m.Timestamp)
            .ToListAsync();

        return metrics;
    }

    /// <summary>
    /// Record a new health metric.
    /// </summary>
    /// <param name="metric">The health metric to record.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost("metrics")]
    public async Task<ActionResult<HealthMetric>> RecordMetric(HealthMetric metric)
    {
        metric.Timestamp = DateTime.UtcNow;
        this.context.HealthMetrics.Add(metric);
        await this.context.SaveChangesAsync();

        return this.CreatedAtAction(nameof(this.GetHealthMetric), new { metricName = metric.MetricName }, metric);
    }

    /// <summary>
    /// Get dashboard summary data.
    /// </summary>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("dashboard")]
    public async Task<ActionResult<object>> GetDashboardSummary()
    {
        DateTime currentTime = DateTime.UtcNow;
        DateTime last24Hours = currentTime.AddHours(-24);

        // Get current system status
        SystemStatus systemStatus = await this.GenerateCurrentSystemStatus();

        // Get recent device activity
        var recentDeviceActivity = await this.context.DeviceStatuses
            .Where(s => s.Timestamp >= last24Hours)
            .GroupBy(s => s.DeviceId)
            .Select(g => new
            {
                DeviceId = g.Key,
                LastActivity = g.Max(s => s.Timestamp),
                g.OrderByDescending(s => s.Timestamp).First().IsConnected,
            })
            .ToListAsync();

        // Get recent software activity
        var recentSoftwareActivity = await this.context.SoftwareStatuses
            .Where(s => s.Timestamp >= last24Hours)
            .GroupBy(s => s.SoftwareId)
            .Select(g => new
            {
                SoftwareId = g.Key,
                LastActivity = g.Max(s => s.Timestamp),
                g.OrderByDescending(s => s.Timestamp).First().IsRunning,
            })
            .ToListAsync();

        // Get recent rule executions
        var recentRuleExecutions = await this.context.RuleExecutions
            .Where(e => e.ExecutedAt >= last24Hours)
            .GroupBy(e => e.Success)
            .Select(g => new
            {
                Success = g.Key,
                Count = g.Count(),
            })
            .ToListAsync();

        // Get latest health metrics
        var latestMetrics = await this.context.HealthMetrics
            .Where(m => m.Timestamp >= last24Hours)
            .GroupBy(m => m.MetricName)
            .Select(g => new
            {
                MetricName = g.Key,
                LatestValue = g.OrderByDescending(m => m.Timestamp).First().Value,
                Timestamp = g.Max(m => m.Timestamp),
            })
            .ToListAsync();

        return this.Ok(new
        {
            systemStatus,
            deviceSummary = new
            {
                totalDevices = recentDeviceActivity.Count,
                connectedDevices = recentDeviceActivity.Count(d => d.IsConnected),
                recentActivity = recentDeviceActivity.Count(d => d.LastActivity >= currentTime.AddHours(-1)),
            },
            softwareSummary = new
            {
                totalSoftware = recentSoftwareActivity.Count,
                runningSoftware = recentSoftwareActivity.Count(s => s.IsRunning),
                recentActivity = recentSoftwareActivity.Count(s => s.LastActivity >= currentTime.AddHours(-1)),
            },
            automationSummary = new
            {
                totalExecutions = recentRuleExecutions.Sum(r => r.Count),
                successfulExecutions = recentRuleExecutions.Where(r => r.Success).Sum(r => r.Count),
                failedExecutions = recentRuleExecutions.Where(r => !r.Success).Sum(r => r.Count),
            },
            healthMetrics = latestMetrics,
            timestamp = currentTime,
        });
    }

    /// <summary>
    /// Get system health check.
    /// </summary>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("health")]
    public IActionResult Health()
    {
        // Provide a lightweight health/compatibility endpoint expected by older clients.
        return this.Ok(new { status = "healthy" });
    }


    /// <summary>
    /// Refresh system status.
    /// </summary>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost("status/refresh")]
    public async Task<ActionResult<SystemStatus>> RefreshSystemStatus()
    {
        SystemStatus status = await this.GenerateCurrentSystemStatus();
        this.context.SystemStatuses.Add(status);
        await this.context.SaveChangesAsync();

        this.logger.LogInformation("System status refreshed");

        return status;
    }

    private async Task<SystemStatus> GenerateCurrentSystemStatus()
    {
        // Get current system metrics
        var process = Process.GetCurrentProcess();

        // Calculate CPU usage (simplified)
        var cpuUsage = 0.0; // This would need a proper CPU counter implementation

        // Calculate memory usage
        var memoryUsage = (process.WorkingSet64 / (1024.0 * 1024.0 * 1024.0)) * 100; // Convert to percentage

        // Calculate disk usage (choose a sensible root per-platform and guard failures)
        double diskUsage = 0.0;
        try
        {
            string driveRoot;
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                driveRoot = Path.GetPathRoot(Environment.GetFolderPath(Environment.SpecialFolder.System)) ?? "C:\\";
            }
            else
            {
                driveRoot = Path.GetPathRoot(Environment.CurrentDirectory) ?? "/";
            }

            var driveInfo = new DriveInfo(driveRoot);
            if (driveInfo.TotalSize > 0)
            {
                diskUsage = ((double)(driveInfo.TotalSize - driveInfo.AvailableFreeSpace) / driveInfo.TotalSize) * 100;
            }
        }
        catch (Exception ex)
        {
            this.logger.LogWarning(ex, "Failed to compute disk usage for drive; defaulting to 0.");
            diskUsage = 0.0;
        }

        // Count connected devices
        var connectedDevices = await this.context.DeviceStatuses
            .Where(s => s.IsConnected)
            .Select(s => s.DeviceId)
            .Distinct()
            .CountAsync();

        // Count running software
        var runningSoftware = await this.context.SoftwareStatuses
            .Where(s => s.IsRunning)
            .Select(s => s.SoftwareId)
            .Distinct()
            .CountAsync();

        // Count active rules
        var activeRules = await this.context.AutomationRules.CountAsync(r => r.IsEnabled);

        return new SystemStatus
        {
            CpuUsage = cpuUsage,
            MemoryUsage = Math.Round(memoryUsage, 2),
            DiskUsage = Math.Round(diskUsage, 2),
            ConnectedDevices = connectedDevices,
            RunningSoftware = runningSoftware,
            ActiveRules = activeRules,
            Timestamp = DateTime.UtcNow,
        };
    }
}
