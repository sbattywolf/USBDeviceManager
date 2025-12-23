// <copyright file="MonitoringController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Controllers;

using System.Diagnostics;
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
    public async Task<ActionResult<object>> GetHealthCheck()
    {
        var checks = new List<object>();

        try
        {
            // Database connectivity check
            var dbCheck = await this.context.Database.CanConnectAsync();
            checks.Add(new { name = "Database", status = dbCheck ? "healthy" : "unhealthy" });

            // Device monitoring check
            var deviceCount = await this.context.UsbDevices.CountAsync();
            checks.Add(new { name = "Device Monitoring", status = "healthy", deviceCount });

            // Software management check
            var softwareCount = await this.context.ManagedSoftware.CountAsync();
            checks.Add(new { name = "Software Management", status = "healthy", softwareCount });

            // Automation check
            var activeRulesCount = await this.context.AutomationRules.CountAsync(r => r.IsEnabled);
            checks.Add(new { name = "Automation", status = "healthy", activeRulesCount });

            // System resources check
            var process = Process.GetCurrentProcess();
            var memoryUsage = process.WorkingSet64 / (1024 * 1024); // MB
            checks.Add(new { name = "Memory Usage", status = "healthy", memoryMB = memoryUsage });

            return this.Ok(new
            {
                status = "healthy",
                checks,
                timestamp = DateTime.UtcNow,
            });
        }
        catch (Exception ex)
        {
            this.logger.LogError(ex, "Health check failed");
            return this.StatusCode(500, new
            {
                status = "unhealthy",
                error = ex.Message,
                timestamp = DateTime.UtcNow,
            });
        }
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

        // Calculate disk usage (simplified for C: drive)
        var driveInfo = new DriveInfo("C");
        var diskUsage = ((double)(driveInfo.TotalSize - driveInfo.AvailableFreeSpace) / driveInfo.TotalSize) * 100;

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
