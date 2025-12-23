// <copyright file="CompatController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using USBDeviceManager.Data;

    /// <summary>
    /// Compatibility controller exposing a small legacy health endpoint used by older
    /// integrations. This controller is intentionally minimal while the compatibility
    /// surface is maintained incrementally.
    /// </summary>
    [ApiController]
    [Route("api")]
    public class CompatController : ControllerBase
    {
        private readonly SimRacingContext context;
        private readonly ILogger<CompatController> logger;

        /// <summary>
        /// Initializes a new instance of the <see cref="CompatController"/> class.
        /// </summary>
        /// <param name="context">The <see cref="SimRacingContext"/> database context.</param>
        /// <param name="logger">The logger instance for the controller.</param>
        public CompatController(SimRacingContext context, ILogger<CompatController> logger)
        {
            this.context = context;
            this.logger = logger;
        }

        /// <summary>
        /// Health check endpoint used by legacy clients.
        /// </summary>
        /// <returns>An OK result with a simple status object.</returns>
        [HttpGet("health")]
        public IActionResult Health()
        {
            return this.Ok(new { status = "ok" });
        }
    }
}
