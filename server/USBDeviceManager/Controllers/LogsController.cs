namespace USBDeviceManager.Controllers
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Threading.Tasks;
    using Microsoft.AspNetCore.Mvc;
    using System.Text.Json.Serialization;
    using USBDeviceManager.Data;
    using USBDeviceManager.Models;
    using Microsoft.AspNetCore.SignalR;
    using USBDeviceManager.Hubs;

    [ApiController]
    [Route("api/logs")]
    public class LogsController : ControllerBase
    {
        private readonly SimRacingContext _ctx;
        private readonly USBDeviceManager.Services.DashboardClient _dashboard;
        private readonly IHubContext<MonitoringHub> _hub;
        private readonly Microsoft.Extensions.Logging.ILogger<LogsController> _logger;

        public LogsController(SimRacingContext ctx, USBDeviceManager.Services.DashboardClient dashboard, IHubContext<MonitoringHub> hub, Microsoft.Extensions.Logging.ILogger<LogsController> logger)
        {
            _ctx = ctx;
            _dashboard = dashboard;
            _hub = hub;
            _logger = logger;
        }

        [HttpGet]
        public IActionResult Get()
        {
            var items = _ctx.DeviceStatuses
                .OrderByDescending(s => s.Timestamp)
                .Take(50)
                .Select(s => new
                {
                    deviceId = s.Device != null ? s.Device.DeviceId : string.Empty,
                    isConnected = s.IsConnected,
                    status = s.Status,
                    timestamp = s.Timestamp
                })
                .ToList();

            return Ok(items);
        }

        public class LogPayload
        {
            [JsonPropertyName("deviceId")]
            public string? DeviceId { get; set; }

            [JsonPropertyName("eventType")]
            public string? EventType { get; set; }

            [JsonPropertyName("message")]
            public string? Message { get; set; }
        }

        [HttpPost]
        public async Task<IActionResult> Post([FromBody] LogPayload payload)
        {
            if (payload == null || string.IsNullOrWhiteSpace(payload.EventType))
            {
                return BadRequest();
            }

            UsbDevice? device = null;
            if (!string.IsNullOrWhiteSpace(payload.DeviceId))
            {
                device = _ctx.UsbDevices.FirstOrDefault(d => d.DeviceId == payload.DeviceId);
            }

            if (device == null && !string.IsNullOrWhiteSpace(payload.DeviceId))
            {
                // Create and persist the device first to avoid FK race conditions
                // where two concurrent requests both attempt to insert the same
                // device and then insert a DeviceStatus referencing a device
                // that isn't yet committed.
                device = new UsbDevice
                {
                    DeviceId = payload.DeviceId,
                    Name = payload.DeviceId,
                };
                _ctx.UsbDevices.Add(device);
                try
                {
                    await _ctx.SaveChangesAsync();
                }
                catch (Microsoft.EntityFrameworkCore.DbUpdateException dbEx)
                {
                    _logger?.LogWarning(dbEx, "Device create SaveChanges failed for DeviceId={DeviceId}", payload?.DeviceId);
                    // Possible unique-index race: another request inserted the
                    // same device concurrently. Try to reload the existing
                    // record and proceed; if not found, rethrow.
                    var existing = _ctx.UsbDevices.FirstOrDefault(d => d.DeviceId == payload.DeviceId);
                    if (existing != null)
                    {
                        device = existing;
                    }
                    else
                    {
                        throw;
                    }
                }
            }

            var status = new DeviceStatus
            {
                Device = device,
                DeviceId = device?.Id,
                IsConnected = string.Equals(payload.EventType, "CONNECTED", System.StringComparison.OrdinalIgnoreCase),
                Status = payload.EventType ?? string.Empty,
                ErrorMessage = payload.Message,
            };

            _ctx.DeviceStatuses.Add(status);

            // Final save of the status record. If this fails due to a FK
            // constraint (possible race where device row wasn't present),
            // attempt a single retry: reload the device and try saving again.
            try
            {
                await _ctx.SaveChangesAsync();
            }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException dbEx)
            {
                // Log payload and FK context to help triage foreign-key failures
                try
                {
                    _logger?.LogError(dbEx, "SaveChanges failed when inserting DeviceStatus. Payload DeviceId={DeviceId} PayloadEventType={EventType} StatusDeviceId={StatusDeviceId}",
                        payload?.DeviceId, payload?.EventType, status?.DeviceId);
                }
                catch { }

                // Try to recover from foreign-key race by ensuring we have
                // the canonical device entity and id, then retry once.
                var existing = !string.IsNullOrWhiteSpace(payload?.DeviceId)
                    ? _ctx.UsbDevices.FirstOrDefault(d => d.DeviceId == payload.DeviceId)
                    : null;

                if (existing != null)
                {
                    status.Device = existing;
                    status.DeviceId = existing.Id;
                    try
                    {
                        await _ctx.SaveChangesAsync();
                        _logger?.LogInformation("Recovery SaveChanges succeeded after reloading existing device. DeviceId={DeviceId}", existing.DeviceId);
                    }
                    catch (Exception retryEx)
                    {
                        _logger?.LogError(retryEx, "Retry SaveChanges failed for DeviceId={DeviceId}", payload?.DeviceId);
                        // If retry fails, rethrow original exception to preserve diagnostics
                        throw;
                    }
                }
                else
                {
                    // No device row found to recover with; attempt to create it
                    if (!string.IsNullOrWhiteSpace(payload?.DeviceId))
                    {
                        try
                        {
                            var newDevice = new UsbDevice
                            {
                                DeviceId = payload.DeviceId,
                                Name = payload.DeviceId,
                            };
                            _ctx.UsbDevices.Add(newDevice);
                            await _ctx.SaveChangesAsync();

                            status.Device = newDevice;
                            status.DeviceId = newDevice.Id;
                            await _ctx.SaveChangesAsync();
                            _logger?.LogInformation("Created device during recovery and saved status. DeviceId={DeviceId}", newDevice.DeviceId);
                        }
                        catch (Exception createEx)
                        {
                            _logger?.LogError(createEx, "Failed to create device during recovery for DeviceId={DeviceId}", payload?.DeviceId);
                            // If creation or retry fails, rethrow the original exception
                            throw;
                        }
                    }
                    else
                    {
                        // No device info available; rethrow to allow diagnostics
                        throw;
                    }
                }
            }

            // Also update the in-memory dashboard recent logs and notify any UI subscribers.
            try
            {
                var line = $"{DateTime.UtcNow:o} [{status.Status}] {device?.DeviceId ?? string.Empty} - {status.ErrorMessage}";

                // Update the scoped DashboardClient for the current request (best-effort)
                try
                {
                    _dashboard.PublishLogLine(line);
                }
                catch { }

                // Broadcast to any SignalR clients in the 'dashboard' group so connected UIs receive the line.
                try
                {
                    await _hub.Clients.Group("dashboard").SendAsync("LogLine", new { Line = line });
                }
                catch
                {
                    // best-effort only; do not fail the API call if broadcasting fails
                }
            }
            catch
            {
                // best-effort only
            }

            return Created(string.Empty, null);
        }

        [HttpGet("recent")]
        public IActionResult GetRecent()
        {
            // Return the in-memory recent logs from the DashboardClient (newest-first)
            var list = new List<string>();
            try
            {
                lock (_dashboard.RecentLogs)
                {
                    list.AddRange(_dashboard.RecentLogs);
                }
            }
            catch
            {
                // best-effort: return empty list on failure
            }

            return Ok(list);
        }
    }
}
