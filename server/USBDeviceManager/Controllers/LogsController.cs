namespace USBDeviceManager.Controllers
{
    using System.Linq;
    using System.Threading.Tasks;
    using Microsoft.AspNetCore.Mvc;
    using System.Text.Json.Serialization;
    using USBDeviceManager.Data;
    using USBDeviceManager.Models;

    [ApiController]
    [Route("api/logs")]
    public class LogsController : ControllerBase
    {
        private readonly SimRacingContext _ctx;

        public LogsController(SimRacingContext ctx)
        {
            _ctx = ctx;
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

            return Created(string.Empty, null);
        }
    }
}
