namespace USBDeviceManager.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;

    [ApiController]
    [Route("api")]
    public class LegacyCompatController : ControllerBase
    {
        private readonly ILogger<LegacyCompatController> logger;

        public LegacyCompatController(ILogger<LegacyCompatController> logger)
        {
            this.logger = logger;
        }

        // Compatibility endpoint for legacy heartbeat POSTs used by older tests/agents
        [HttpPost("heartbeat")]
        public IActionResult HeartbeatLegacy([FromBody] object payload)
        {
            try
            {
                this.logger.LogInformation("Legacy heartbeat received: {Payload}", payload);
            }
            catch
            {
                // swallow logging errors to keep compatibility shim robust
            }

            return Ok(new { status = "ok" });
        }

        // Compatibility endpoint for legacy agent registration used by older agent versions
        [HttpPost("agents/register")]
        public IActionResult RegisterAgent([FromBody] object payload)
        {
            try
            {
                this.logger.LogInformation("Legacy agent registration received: {Payload}", payload);
            }
            catch
            {
                // ignore logging failures
            }

            // Return a minimal success response expected by older agents
            return Created(string.Empty, new { status = "registered", agentId = System.Guid.NewGuid() });
        }

        // Note: health endpoint is provided by the existing CompatController to avoid
        // ambiguous route matches. This controller only exposes the legacy heartbeat
        // compatibility endpoint used by older agents/tests.
    }
}
