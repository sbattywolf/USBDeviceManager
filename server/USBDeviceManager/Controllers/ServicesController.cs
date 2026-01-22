using Microsoft.AspNetCore.Mvc;
using USBDeviceManager.Services;

namespace USBDeviceManager.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ServicesController : ControllerBase
    {
        private readonly StatusService _status;

        public ServicesController(StatusService status)
        {
            _status = status;
        }

        [HttpGet("running")]
        public IActionResult GetRunning()
        {
            return Ok(_status.GetRunningProcesses());
        }

        [HttpGet("config")]
        public IActionResult GetConfig()
        {
            return Ok(_status.GetConfig());
        }

        [HttpPost("config")]
        public async Task<IActionResult> SaveConfig([FromBody] ServiceConfig cfg)
        {
            if (cfg == null) return BadRequest();
            await _status.SetConfigAsync(cfg);
            return Ok(cfg);
        }

        [HttpPost("start/server")]
        public async Task<IActionResult> StartServer([FromBody] StartRequest req)
        {
            int port = req?.Port ?? _status.ServerPort;
            var id = await _status.StartServerAsync(port);
            _status.SetPorts(port, _status.AgentPort);
            return Ok(new { pid = id, port });
        }

        [HttpPost("start/agent")]
        public async Task<IActionResult> StartAgent([FromBody] StartRequest req)
        {
            int port = req?.Port ?? _status.AgentPort;
            try
            {
                var id = await _status.StartAgentAsync(port);
                _status.SetPorts(_status.ServerPort, port);
                return Ok(new { pid = id, port });
            }
            catch (InvalidOperationException ex)
            {
                // Likely an agent is already running
                return Conflict(new { error = ex.Message });
            }
        }

        [HttpPost("stop/{name}")]
        public async Task<IActionResult> Stop(string name)
        {
            var ok = await _status.StopServiceAsync(name);
            if (ok) return Ok();
            return NotFound();
        }

        [HttpGet("logs/{name}")]
        public IActionResult GetLogs(string name, [FromQuery] int maxLines = 500)
        {
            var logs = _status.GetProcessLogs(name, maxLines);
            return Ok(logs);
        }

        [HttpPost("logs/{name}/clear")]
        public IActionResult ClearLogs(string name)
        {
            _status.ClearProcessLogs(name);
            return Ok();
        }

        public class StartRequest
        {
            public int? Port { get; set; }
        }
    }
}
