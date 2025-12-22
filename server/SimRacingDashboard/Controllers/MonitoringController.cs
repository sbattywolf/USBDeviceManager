using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SimRacingDashboard.Data;
using SimRacingDashboard.Models;
using System.Diagnostics;

namespace SimRacingDashboard.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MonitoringController : ControllerBase
{
    private readonly SimRacingContext _context;
    private readonly ILogger<MonitoringController> _logger;

    public MonitoringController(SimRacingContext context, ILogger<MonitoringController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Get current system status
    /// </summary>
    [HttpGet("status")]
    public async Task<ActionResult<SystemStatus>> GetSystemStatus()
    {
        var status = await _context.SystemStatuses
            .OrderByDescending(s => s.Timestamp)
            .FirstOrDefaultAsync();

        if (status == null)
        {
            // Generate current status if none exists
            status = await GenerateCurrentSystemStatus();
            _context.SystemStatuses.Add(status);
            await _context.SaveChangesAsync();
        }

        return status;
    }

    /// <summary>
    /// Get system status history
    /// </summary>
    [HttpGet("status/history")]
    public async Task<ActionResult<IEnumerable<SystemStatus>>> GetSystemStatusHistory([FromQuery] int hours = 24)
    {
        var cutoff = DateTime.UtcNow.AddHours(-hours);
        
        var history = await _context.SystemStatuses
            .Where(s => s.Timestamp >= cutoff)
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        return history;
    }

    /// <summary>
    /// Get all health metrics
    /// </summary>
    [HttpGet("metrics")]
    public async Task<ActionResult<IEnumerable<HealthMetric>>> GetHealthMetrics([FromQuery] int hours = 24)
    {
        var cutoff = DateTime.UtcNow.AddHours(-hours);
        
        var metrics = await _context.HealthMetrics
            .Where(m => m.Timestamp >= cutoff)
            .OrderByDescending(m => m.Timestamp)
            .ToListAsync();

        return metrics;
    }

    /// <summary>
    /// Get specific health metric by name
    /// </summary>
    [HttpGet("metrics/{metricName}")]
    public async Task<ActionResult<IEnumerable<HealthMetric>>> GetHealthMetric(string metricName, [FromQuery] int hours = 24)
    {
        var cutoff = DateTime.UtcNow.AddHours(-hours);
        
        var metrics = await _context.HealthMetrics
            .Where(m => m.MetricName == metricName && m.Timestamp >= cutoff)
            .OrderByDescending(m => m.Timestamp)
            .ToListAsync();

        return metrics;
    }

    /// <summary>
    /// Record a new health metric
    /// </summary>
    [HttpPost("metrics")]
    public async Task<ActionResult<HealthMetric>> RecordMetric(HealthMetric metric)
    {
        metric.Timestamp = DateTime.UtcNow;
        _context.HealthMetrics.Add(metric);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetHealthMetric), new { metricName = metric.MetricName }, metric);
    }

    /// <summary>
    /// Get dashboard summary data
    /// </summary>
    [HttpGet("dashboard")]
    public async Task<ActionResult<object>> GetDashboardSummary()
    {
        var currentTime = DateTime.UtcNow;
        var last24Hours = currentTime.AddHours(-24);

        // Get current system status
        var systemStatus = await GenerateCurrentSystemStatus();

        // Get recent device activity
        var recentDeviceActivity = await _context.DeviceStatuses
            .Where(s => s.Timestamp >= last24Hours)
            .GroupBy(s => s.DeviceId)
            .Select(g => new
            {
                DeviceId = g.Key,
                LastActivity = g.Max(s => s.Timestamp),
                IsConnected = g.OrderByDescending(s => s.Timestamp).First().IsConnected
            })
            .ToListAsync();

        // Get recent software activity
        var recentSoftwareActivity = await _context.SoftwareStatuses
            .Where(s => s.Timestamp >= last24Hours)
            .GroupBy(s => s.SoftwareId)
            .Select(g => new
            {
                SoftwareId = g.Key,
                LastActivity = g.Max(s => s.Timestamp),
                IsRunning = g.OrderByDescending(s => s.Timestamp).First().IsRunning
            })
            .ToListAsync();

        // Get recent rule executions
        var recentRuleExecutions = await _context.RuleExecutions
            .Where(e => e.ExecutedAt >= last24Hours)
            .GroupBy(e => e.Success)
            .Select(g => new
            {
                Success = g.Key,
                Count = g.Count()
            })
            .ToListAsync();

        // Get latest health metrics
        var latestMetrics = await _context.HealthMetrics
            .Where(m => m.Timestamp >= last24Hours)
            .GroupBy(m => m.MetricName)
            .Select(g => new
            {
                MetricName = g.Key,
                LatestValue = g.OrderByDescending(m => m.Timestamp).First().Value,
                Timestamp = g.Max(m => m.Timestamp)
            })
            .ToListAsync();

        return Ok(new
        {
            systemStatus,
            deviceSummary = new
            {
                totalDevices = recentDeviceActivity.Count,
                connectedDevices = recentDeviceActivity.Count(d => d.IsConnected),
                recentActivity = recentDeviceActivity.Count(d => d.LastActivity >= currentTime.AddHours(-1))
            },
            softwareSummary = new
            {
                totalSoftware = recentSoftwareActivity.Count,
                runningSoftware = recentSoftwareActivity.Count(s => s.IsRunning),
                recentActivity = recentSoftwareActivity.Count(s => s.LastActivity >= currentTime.AddHours(-1))
            },
            automationSummary = new
            {
                totalExecutions = recentRuleExecutions.Sum(r => r.Count),
                successfulExecutions = recentRuleExecutions.Where(r => r.Success).Sum(r => r.Count),
                failedExecutions = recentRuleExecutions.Where(r => !r.Success).Sum(r => r.Count)
            },
            healthMetrics = latestMetrics,
            timestamp = currentTime
        });
    }

    /// <summary>
    /// Get system health check
    /// </summary>
    [HttpGet("health")]
    public async Task<ActionResult<object>> GetHealthCheck()
    {
        var checks = new List<object>();

        try
        {
            // Database connectivity check
            var dbCheck = await _context.Database.CanConnectAsync();
            checks.Add(new { name = "Database", status = dbCheck ? "healthy" : "unhealthy" });

            // Device monitoring check
            var deviceCount = await _context.UsbDevices.CountAsync();
            checks.Add(new { name = "Device Monitoring", status = "healthy", deviceCount });

            // Software management check
            var softwareCount = await _context.ManagedSoftware.CountAsync();
            checks.Add(new { name = "Software Management", status = "healthy", softwareCount });

            // Automation check
            var activeRulesCount = await _context.AutomationRules.CountAsync(r => r.IsEnabled);
            checks.Add(new { name = "Automation", status = "healthy", activeRulesCount });

            // System resources check
            var process = Process.GetCurrentProcess();
            var memoryUsage = process.WorkingSet64 / (1024 * 1024); // MB
            checks.Add(new { name = "Memory Usage", status = "healthy", memoryMB = memoryUsage });

            return Ok(new
            {
                status = "healthy",
                checks,
                timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Health check failed");
            return StatusCode(500, new
            {
                status = "unhealthy",
                error = ex.Message,
                timestamp = DateTime.UtcNow
            });
        }
    }

    /// <summary>
    /// Refresh system status
    /// </summary>
    [HttpPost("status/refresh")]
    public async Task<ActionResult<SystemStatus>> RefreshSystemStatus()
    {
        var status = await GenerateCurrentSystemStatus();
        _context.SystemStatuses.Add(status);
        await _context.SaveChangesAsync();

        _logger.LogInformation("System status refreshed");

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
        var connectedDevices = await _context.DeviceStatuses
            .Where(s => s.IsConnected)
            .Select(s => s.DeviceId)
            .Distinct()
            .CountAsync();

        // Count running software
        var runningSoftware = await _context.SoftwareStatuses
            .Where(s => s.IsRunning)
            .Select(s => s.SoftwareId)
            .Distinct()
            .CountAsync();

        // Count active rules
        var activeRules = await _context.AutomationRules.CountAsync(r => r.IsEnabled);

        return new SystemStatus
        {
            CpuUsage = cpuUsage,
            MemoryUsage = Math.Round(memoryUsage, 2),
            DiskUsage = Math.Round(diskUsage, 2),
            ConnectedDevices = connectedDevices,
            RunningSoftware = runningSoftware,
            ActiveRules = activeRules,
            Timestamp = DateTime.UtcNow
        };
    }
}