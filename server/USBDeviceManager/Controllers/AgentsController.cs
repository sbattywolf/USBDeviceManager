namespace USBDeviceManager.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;
    using USBDeviceManager.Services;

    [ApiController]
    [Route("api/agents")]
    public class AgentsController : ControllerBase
    {
        private readonly ILogger<AgentsController> logger;
        private readonly StatusService statusService;

        public AgentsController(ILogger<AgentsController> logger, StatusService statusService)
        {
            this.logger = logger;
            this.statusService = statusService;
        }

        [HttpPost("{id:guid}/heartbeat")]
        public IActionResult Heartbeat([FromRoute] System.Guid id)
        {
            // Enforce AgentMode policies: when running in Embedded mode and an embedded
            // agent process is active, reject remote agent heartbeats to maintain
            // single-agent-per-PC semantics. When Disabled, heartbeat should be rejected.
            try
            {
                var cfg = statusService.GetConfig();
                if (cfg != null)
                {
                    var mode = (cfg.AgentMode ?? "External").ToLowerInvariant();
                    if (mode == "embedded")
                    {
                        var procs = statusService.GetRunningProcesses();
                        if (procs.ContainsKey("agent"))
                        {
                            this.logger.LogWarning("Rejecting heartbeat from remote agent {AgentId} because server is in Embedded mode with local agent running.", id);
                            return Conflict(new { status = "conflict", reason = "embedded_agent_active" });
                        }
                    }
                    else if (mode == "disabled")
                    {
                        this.logger.LogWarning("Rejecting heartbeat from agent {AgentId} because agent support is disabled.", id);
                        return Forbid();
                    }
                }
            }
            catch (System.Exception ex)
            {
                this.logger.LogError(ex, "Error while evaluating agent mode for heartbeat from {AgentId}", id);
                // Fail-safe: allow heartbeat if we cannot determine config to avoid locking out agents on unexpected errors.
            }

            this.logger.LogInformation("Received heartbeat from agent {AgentId}", id);
            return Ok(new { status = "ok", agentId = id });
        }
    }
}
