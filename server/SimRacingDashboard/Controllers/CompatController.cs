using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Linq;
using SimRacingDashboard.Data;
using SimRacingDashboard.Models;
using SimRacingDashboard.DTOs;

namespace SimRacingDashboard.Controllers;

[ApiController]
[Route("api")]
public class CompatController : ControllerBase
{
    private readonly SimRacingContext _context;
    private readonly ILogger<CompatController> _logger;

    public CompatController(SimRacingContext context, ILogger<CompatController> logger)
    {
        _context = context;
        _logger = logger;
    }

    // GET /api/configs -> map to devices + software + automation rules
    [HttpGet("configs")]
    public async Task<IActionResult> ListConfigs()
    {
        // Device-Sentinel expects a flat config object combining device and software info.
        var devices = await _context.UsbDevices.ToListAsync();
        var software = await _context.ManagedSoftware.ToListAsync();
        var rules = await _context.AutomationRules.Include(r => r.TriggerDevice).Include(r => r.TargetSoftware).ToListAsync();

            var configs = rules.Select(r => new {
            id = r.Id,
            deviceId = r.TriggerDevice?.DeviceId ?? string.Empty,
            friendlyName = r.TriggerDevice?.Name ?? r.Name,
            	usbPort = r.TriggerDevice?.Description ?? string.Empty,
            isEnabled = r.IsEnabled,
            softwareId = r.TargetSoftware?.Id,
            softwareName = r.TargetSoftware?.Name,
                triggerPath = r.TargetSoftware?.ExecutablePath ?? string.Empty,
                triggerParams = r.TargetSoftware?.StartupArguments ?? string.Empty,
        });

        // also include standalone software entries as configs without device
        var standalone = software.Where(s => !rules.Any(r => r.TargetSoftwareId == s.Id)).Select(s => new {
            id = -s.Id,
            deviceId = string.Empty,
            friendlyName = s.Name,
            usbPort = string.Empty,
            isEnabled = s.IsEnabled,
            softwareId = (int?)s.Id,
            softwareName = s.Name,
            triggerPath = s.ExecutablePath ?? string.Empty,
            triggerParams = s.StartupArguments ?? string.Empty,
        });

        return Ok(configs.Concat(standalone));
    }

    // POST /api/configs -> create a device + software + rule
    [HttpPost("configs")]
    public async Task<IActionResult> CreateConfig([FromBody] ConfigCreateDto input)
    {
        // Create or find device
        UsbDevice device = null;
        if (!string.IsNullOrWhiteSpace(input.deviceId))
        {
            device = await _context.UsbDevices.FirstOrDefaultAsync(d => d.DeviceId == input.deviceId);
            if (device == null)
            {
                device = new UsbDevice
                {
                    DeviceId = input.deviceId,
                    Name = input.friendlyName ?? "",
                    Description = input.usbPort,
                    VendorId = input.vendorId,
                    ProductId = input.productId,
                    IsEnabled = true,
                    CreatedAt = DateTime.UtcNow,
                    LastSeen = DateTime.UtcNow,
                };
                _context.UsbDevices.Add(device);
                await _context.SaveChangesAsync();
            }
        }

        // Create software if provided
        ManagedSoftware sw = null;
        if (!string.IsNullOrWhiteSpace(input.triggerPath))
        {
            sw = new ManagedSoftware
            {
                Name = input.softwareName ?? Path.GetFileName(input.triggerPath),
                ExecutablePath = input.triggerPath,
                StartupArguments = input.triggerParams,
                WorkingDirectory = input.workingDirectory,
                IsEnabled = true,
                CreatedAt = DateTime.UtcNow,
            };
            _context.ManagedSoftware.Add(sw);
            await _context.SaveChangesAsync();
        }

        // Create automation rule linking device -> software
        if (device != null && sw != null)
        {
            var rule = new AutomationRule
            {
                Name = $"Auto: {device.Name} -> {sw.Name}",
                Trigger = AutomationTrigger.DeviceConnected,
                TriggerDeviceId = device.Id,
                TargetSoftwareId = sw.Id,
                Action = AutomationAction.StartSoftware,
                IsEnabled = input.isEnabled ?? true,
                CreatedAt = DateTime.UtcNow,
            };
            _context.AutomationRules.Add(rule);
            await _context.SaveChangesAsync();
            return Created($"/api/configs/{rule.Id}", rule);
        }

        // If only software created, return it
        if (sw != null)
        {
            return Created($"/api/configs/{sw.Id}", new { softwareId = sw.Id });
        }

        return BadRequest(new { message = "Invalid config payload" });
    }

    // GET /api/logs -> map device/software statuses to logs
    [HttpGet("logs")]
    public async Task<IActionResult> GetLogs()
    {
        var deviceStatuses = await _context.DeviceStatuses.OrderByDescending(s => s.Timestamp).Take(500).ToListAsync();
        var softwareStatuses = await _context.SoftwareStatuses.OrderByDescending(s => s.Timestamp).Take(500).ToListAsync();

        // Normalize into a simple log shape
        var logs = deviceStatuses.Select(s => new {
            timestamp = s.Timestamp,
            type = "device",
            id = s.DeviceId,
            message = s.IsConnected ? "connected" : "disconnected",
        }).Concat(softwareStatuses.Select(s => new {
            timestamp = s.Timestamp,
            type = "software",
            id = s.SoftwareId,
            message = s.Status,
        })).OrderByDescending(l => l.timestamp).Take(1000);

        return Ok(logs);
    }

    // POST /api/logs -> accept client logs (store as DeviceStatus entries)
    [HttpPost("logs")]
    public async Task<IActionResult> CreateLog([FromBody] System.Text.Json.JsonElement payload)
    {
        try
        {
            string deviceId = string.Empty;
            string eventType = string.Empty;

            if (payload.ValueKind == System.Text.Json.JsonValueKind.Object)
            {
                if (payload.TryGetProperty("deviceId", out var did) && did.ValueKind == System.Text.Json.JsonValueKind.String)
                {
                    deviceId = did.GetString() ?? string.Empty;
                }

                if (payload.TryGetProperty("eventType", out var et) && et.ValueKind == System.Text.Json.JsonValueKind.String)
                {
                    eventType = et.GetString() ?? string.Empty;
                }
            }

            if (!string.IsNullOrWhiteSpace(deviceId))
            {
                var device = await _context.UsbDevices.FirstOrDefaultAsync(d => d.DeviceId == deviceId);
                if (device != null)
                {
                    var ds = new DeviceStatus
                    {
                        DeviceId = device.Id,
                        IsConnected = (eventType ?? string.Empty).ToUpperInvariant() == "CONNECTED",
                        Status = string.IsNullOrWhiteSpace(eventType) ? "log" : eventType,
                        Timestamp = DateTime.UtcNow,
                    };
                    _context.DeviceStatuses.Add(ds);
                    await _context.SaveChangesAsync();
                }
            }

            return Created(string.Empty, payload);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to store log");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    // GET /api/agent/download -> serve agent script file if exists in repository
    [HttpGet("agent/download")]
    public IActionResult DownloadAgent()
    {
        var agentPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "agent", "SimRacingAgent", "SimRacingAgent.ps1");
        if (System.IO.File.Exists(agentPath))
        {
            var bytes = System.IO.File.ReadAllBytes(agentPath);
            return File(bytes, "application/octet-stream", "SimRacingAgent.ps1");
        }

        // fallback: return a small placeholder script
        var placeholder = "# Agent script not found on server\nWrite-Output \"Agent not available\"";
        return File(System.Text.Encoding.UTF8.GetBytes(placeholder), "text/plain", "agent.ps1");
    }
}
