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

        public LogsController(SimRacingContext ctx, USBDeviceManager.Services.DashboardClient dashboard, IHubContext<MonitoringHub> hub)
        {
            _ctx = ctx;
            _dashboard = dashboard;
            _hub = hub;
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
                device = new UsbDevice
                {
                    DeviceId = payload.DeviceId,
                    Name = payload.DeviceId,
                };
                _ctx.UsbDevices.Add(device);
                await _ctx.SaveChangesAsync();
            }

            var status = new DeviceStatus
            {
                DeviceId = device != null ? device.Id : 0,
                Device = device!,
                IsConnected = string.Equals(payload.EventType, "CONNECTED", System.StringComparison.OrdinalIgnoreCase),
                Status = payload.EventType ?? string.Empty,
                ErrorMessage = payload.Message,
            };

            _ctx.DeviceStatuses.Add(status);
            await _ctx.SaveChangesAsync();

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
