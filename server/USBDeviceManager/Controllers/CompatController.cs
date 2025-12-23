// CompatController — single clean implementation
namespace USBDeviceManager.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using USBDeviceManager.Data;

    [ApiController]
    [Route("api")]
    public class CompatController : ControllerBase
    {
        private readonly SimRacingContext context;
        private readonly ILogger<CompatController> logger;

        public CompatController(SimRacingContext context, ILogger<CompatController> logger)
        {
            this.context = context;
            this.logger = logger;
        }

        [HttpGet("health")]
        public IActionResult Health() => this.Ok(new { status = "ok" });
    }
}
