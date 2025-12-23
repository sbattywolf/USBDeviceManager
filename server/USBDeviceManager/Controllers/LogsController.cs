namespace USBDeviceManager.Controllers
{
    using System.Linq;
    using System.Threading.Tasks;
    using Microsoft.AspNetCore.Mvc;
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
            public string? deviceId { get; set; }
            public string? eventType { get; set; }
            public string? message { get; set; }
        }

        [HttpPost]
        public async Task<IActionResult> Post([FromBody] LogPayload payload)
        {
            if (payload == null || string.IsNullOrWhiteSpace(payload.eventType))
            {
                return BadRequest();
            }

            UsbDevice? device = null;
            if (!string.IsNullOrWhiteSpace(payload.deviceId))
            {
                device = _ctx.UsbDevices.FirstOrDefault(d => d.DeviceId == payload.deviceId);
            }

            if (device == null && !string.IsNullOrWhiteSpace(payload.deviceId))
            {
                device = new UsbDevice
                {
                    DeviceId = payload.deviceId,
                    Name = payload.deviceId,
                };
                _ctx.UsbDevices.Add(device);
                await _ctx.SaveChangesAsync();
            }

            var status = new DeviceStatus
            {
                DeviceId = device != null ? device.Id : 0,
                Device = device!,
                IsConnected = string.Equals(payload.eventType, "CONNECTED", System.StringComparison.OrdinalIgnoreCase),
                Status = payload.eventType ?? "",
                ErrorMessage = payload.message,
            };

            _ctx.DeviceStatuses.Add(status);
            await _ctx.SaveChangesAsync();

            return Created(string.Empty, null);
        }
    }
}
