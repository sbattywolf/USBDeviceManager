namespace USBDeviceManager.Controllers
{
    using Microsoft.AspNetCore.Mvc;

    [ApiController]
    [Route("api/agent")]
    public class AgentController : ControllerBase
    {
        [HttpGet("download")]
        public IActionResult Download()
        {
            // Temporary shim for agent download endpoint used by smoke tests.
            // Return 200 OK with a small payload in case callers expect a body.
            return Ok(new { message = "agent download placeholder" });
        }
    }
}
