namespace USBDeviceManager.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;

    [ApiController]
    [Route("api/agents")]
    public class AgentsController : ControllerBase
    {
        private readonly ILogger<AgentsController> logger;

        public AgentsController(ILogger<AgentsController> logger)
        {
            this.logger = logger;
        }

        [HttpPost("{id:guid}/heartbeat")]
        public IActionResult Heartbeat([FromRoute] System.Guid id)
        {
            // Minimal shim: accept heartbeat POSTs from agents used in tests and local runs.
            this.logger.LogInformation("Received heartbeat from agent {AgentId}", id);
            return Ok(new { status = "ok", agentId = id });
        }
    }
}
