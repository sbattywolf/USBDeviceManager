// <copyright file="CompatController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Controllers
{
    using System.Linq;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.EntityFrameworkCore;
    using USBDeviceManager.Data;
    using USBDeviceManager.DTOs;
    using USBDeviceManager.Models;

    /// <summary>
    /// Compatibility controller exposing legacy flat config and log endpoints.
    /// </summary>
    [ApiController]
    [Route("api")]
    public class CompatController : ControllerBase
    {
        private readonly SimRacingContext context;
        private readonly ILogger<CompatController> logger;

        /// <summary>
        /// Initializes a new instance of the <see cref="CompatController"/> class.
        /// </summary>
        /// <param name="context">Database context.</param>
        /// <param name="logger">Logger instance.</param>
        public CompatController(SimRacingContext context, ILogger<CompatController> logger)
        {
            this.context = context;
            this.logger = logger;
        }

        // GET /api/configs -> map to devices + software + automation rules
        [HttpGet("configs")]
        /// <inheritdoc/>
        public async Task<IActionResult> ListConfigs()
        {
            // USB Device Manager expects a flat config object combining device and software info.
            List<UsbDevice> devices = await this.context.UsbDevices.ToListAsync();
            List<ManagedSoftware> software = await this.context.ManagedSoftware.ToListAsync();
            List<AutomationRule> rules = await this.context.AutomationRules
                .Include(r => r.TriggerDevice)
                .Include(r => r.TargetSoftware)
                .ToListAsync();

            var configs = rules.Select(r => new
            {
                id = r.Id,
                deviceId = r.TriggerDevice?.DeviceId ?? string.Empty,
                friendlyName = r.TriggerDevice?.Name ?? r.Name,
                usbPort = r.TriggerDevice?.Description ?? string.Empty,
                isEnabled = r.IsEnabled,
                softwareId = r.TargetSoftware?.Id,
                softwareName = r.TargetSoftware?.Name ?? string.Empty,
                triggerPath = r.TargetSoftware?.ExecutablePath ?? string.Empty,
                triggerParams = r.TargetSoftware?.StartupArguments ?? string.Empty,
            });

            // also include standalone software entries as configs without device
            var standalone = software
                .Where(s => !rules.Any(r => r.TargetSoftwareId == s.Id))
                .Select(s => new
                {
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

            return this.Ok(configs.Concat(standalone));
        }

        // POST /api/configs -> create a device + software + rule
        [HttpPost("configs")]
        /// <inheritdoc/>
        public async Task<IActionResult> CreateConfig([FromBody] ConfigCreateDto input)
        {
            // Create or find device
            UsbDevice? device = null;
            string deviceId = input.DeviceId ?? string.Empty;
            if (!string.IsNullOrWhiteSpace(deviceId))
            {
                device = await this.context.UsbDevices.FirstOrDefaultAsync(d => d.DeviceId == deviceId);
                if (device == null)
                {
                    device = new UsbDevice
                    {
                        DeviceId = deviceId,
                        Name = input.FriendlyName ?? string.Empty,
                        Description = input.UsbPort ?? string.Empty,
                        VendorId = input.VendorId ?? string.Empty,
                        ProductId = input.ProductId ?? string.Empty,
                        IsEnabled = true,
                        CreatedAt = DateTime.UtcNow,
                        LastSeen = DateTime.UtcNow,
                    };

                    this.context.UsbDevices.Add(device);
                    await this.context.SaveChangesAsync();
                }
            }

            // Create software if provided
            ManagedSoftware? sw = null;
            string triggerPath = input.TriggerPath ?? string.Empty;
            if (!string.IsNullOrWhiteSpace(triggerPath))
            {
                sw = new ManagedSoftware
                {
                    Name = input.SoftwareName ?? (Path.GetFileName(triggerPath) ?? string.Empty),
                    ExecutablePath = triggerPath,
                    StartupArguments = input.TriggerParams ?? string.Empty,
                    WorkingDirectory = input.WorkingDirectory ?? string.Empty,
                    IsEnabled = true,
                    CreatedAt = DateTime.UtcNow,
                };

                this.context.ManagedSoftware.Add(sw);
                await this.context.SaveChangesAsync();
            }

            // Create automation rule linking device -> software
            if (device != null && sw != null)
            {
                var rule = new AutomationRule
                {
                    Name = $"Auto: {device.Name ?? string.Empty} -> {sw.Name ?? string.Empty}",
                    Trigger = AutomationTrigger.DeviceConnected,
                    TriggerDeviceId = device.Id,
                    TargetSoftwareId = sw.Id,
                    Action = AutomationAction.StartSoftware,
                    IsEnabled = input.IsEnabled ?? true,
                    CreatedAt = DateTime.UtcNow,
                };

                this.context.AutomationRules.Add(rule);
                await this.context.SaveChangesAsync();
                return this.Created($"/api/configs/{rule.Id}", rule);
            }

            // If only software created, return it
            if (sw != null)
            {
                return this.Created($"/api/configs/{sw.Id}", new { softwareId = sw.Id });
            }

            return this.BadRequest(new { message = "Invalid config payload" });
        }

        // GET /api/logs -> map device/software statuses to logs
        [HttpGet("logs")]
        /// <inheritdoc/>
        public async Task<IActionResult> GetLogs()
        {
            List<DeviceStatus> deviceStatuses = await this.context.DeviceStatuses
                .OrderByDescending(s => s.Timestamp)
                .Take(500)
                .ToListAsync();

            List<SoftwareStatus> softwareStatuses = await this.context.SoftwareStatuses
                .OrderByDescending(s => s.Timestamp)
                .Take(500)
                .ToListAsync();

            // Normalize into a simple log shape
            var logs = deviceStatuses.Select(s => new
            {
                timestamp = s.Timestamp,
                type = "device",
                id = s.DeviceId,
                message = s.IsConnected ? "connected" : "disconnected",
            })
            .Concat(softwareStatuses.Select(s => new
            {
                timestamp = s.Timestamp,
                type = "software",
                id = s.SoftwareId,
                message = s.Status,
            }))
            .OrderByDescending(l => l.timestamp)
            .Take(1000);

            return this.Ok(logs);
        }

        // POST /api/logs -> accept client logs (store as DeviceStatus entries)
        [HttpPost("logs")]
        /// <inheritdoc/>
        public async Task<IActionResult> CreateLog([FromBody] System.Text.Json.JsonElement payload)
        {
            try
            {
                var deviceId = string.Empty;
                var eventType = string.Empty;

                if (payload.ValueKind == System.Text.Json.JsonValueKind.Object)
                {
                    if (payload.TryGetProperty("deviceId", out System.Text.Json.JsonElement did) && did.ValueKind == System.Text.Json.JsonValueKind.String)
                    {
                        deviceId = did.GetString() ?? string.Empty;
                    }

                    if (payload.TryGetProperty("eventType", out System.Text.Json.JsonElement et) && et.ValueKind == System.Text.Json.JsonValueKind.String)
                    {
                        eventType = et.GetString() ?? string.Empty;
                    }
                }

                if (!string.IsNullOrWhiteSpace(deviceId))
                {
                    UsbDevice? device = await this.context.UsbDevices.FirstOrDefaultAsync(d => d.DeviceId == deviceId);
                    if (device != null)
                    {
                        var ds = new DeviceStatus
                        {
                            DeviceId = device.Id,
                            IsConnected = (eventType ?? string.Empty).ToUpperInvariant() == "CONNECTED",
                            Status = string.IsNullOrWhiteSpace(eventType) ? "log" : eventType,
                            Timestamp = DateTime.UtcNow,
                        };

                        this.context.DeviceStatuses.Add(ds);
                        await this.context.SaveChangesAsync();
                    }
                }

                return this.Created(string.Empty, payload);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Failed to store log");
                return this.StatusCode(500, new { error = ex.Message });
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
                return this.File(bytes, "application/octet-stream", "SimRacingAgent.ps1");
            }

            // fallback: return a small placeholder script
            var placeholder = "# Agent script not found on server\nWrite-Output \"Agent not available\"";
            return this.File(System.Text.Encoding.UTF8.GetBytes(placeholder), "text/plain", "agent.ps1");
        }
    }
}
