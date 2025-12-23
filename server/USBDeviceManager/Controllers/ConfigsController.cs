// <copyright file="ConfigsController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Controllers
{
    using System.Text.Json.Serialization;
    using Microsoft.AspNetCore.Mvc;
    using USBDeviceManager.Data;
    using USBDeviceManager.Models;

    [ApiController]
    [Route("api/configs")]
    public class ConfigsController : ControllerBase
    {
        private readonly SimRacingContext context;

        public ConfigsController(SimRacingContext context)
        {
            this.context = context;
        }

        [HttpGet]
        public IActionResult GetConfigs()
        {
            return this.Ok(Array.Empty<object>());
        }

        public class ConfigPayload
        {
            public string? DeviceId { get; set; }
            public string? FriendlyName { get; set; }
            public string? UsbPort { get; set; }
            public string? VendorId { get; set; }
            public string? ProductId { get; set; }
            public string? TriggerPath { get; set; }
            public string? SoftwareName { get; set; }
            public string? TriggerParams { get; set; }
            public string? WorkingDirectory { get; set; }
            public bool? IsEnabled { get; set; }
        }

        [HttpPost]
        public async Task<IActionResult> PostConfig([FromBody] ConfigPayload payload)
        {
            // Require at least a deviceId (device+rule) or triggerPath+softwareName (standalone software)
            bool hasDevice = !string.IsNullOrWhiteSpace(payload?.DeviceId);
            bool hasSoftware = !string.IsNullOrWhiteSpace(payload?.SoftwareName) && !string.IsNullOrWhiteSpace(payload?.TriggerPath);

            if (!hasDevice && !hasSoftware)
            {
                return this.BadRequest();
            }

            if (hasDevice)
            {
                var device = new UsbDevice
                {
                    DeviceId = payload!.DeviceId!,
                    Name = payload.FriendlyName ?? payload.DeviceId!,
                    VendorId = payload.VendorId,
                    ProductId = payload.ProductId,
                    Description = payload.UsbPort,
                    IsEnabled = payload.IsEnabled ?? true,
                    CreatedAt = DateTime.UtcNow,
                    LastSeen = DateTime.UtcNow,
                };

                this.context.UsbDevices.Add(device);
                await this.context.SaveChangesAsync();

                if (!string.IsNullOrWhiteSpace(payload.SoftwareName) && !string.IsNullOrWhiteSpace(payload.TriggerPath))
                {
                    var sw = new ManagedSoftware
                    {
                        Name = payload.SoftwareName!,
                        ExecutablePath = payload.TriggerPath!,
                        StartupArguments = payload.TriggerParams,
                        WorkingDirectory = payload.WorkingDirectory,
                        IsEnabled = payload.IsEnabled ?? true,
                        CreatedAt = DateTime.UtcNow,
                    };

                    this.context.ManagedSoftware.Add(sw);
                    await this.context.SaveChangesAsync();

                    var rule = new AutomationRule
                    {
                        Name = $"Auto rule for {device.DeviceId} -> {sw.Name}",
                        Trigger = AutomationTrigger.DeviceConnected,
                        Action = AutomationAction.StartSoftware,
                        TriggerDeviceId = device.Id,
                        TargetSoftwareId = sw.Id,
                        IsEnabled = payload.IsEnabled ?? true,
                        CreatedAt = DateTime.UtcNow,
                    };

                    this.context.AutomationRules.Add(rule);
                    await this.context.SaveChangesAsync();
                }

                return this.Created(string.Empty, null);
            }

            // standalone software
            var standalone = new ManagedSoftware
            {
                Name = payload!.SoftwareName!,
                ExecutablePath = payload.TriggerPath!,
                StartupArguments = payload.TriggerParams,
                WorkingDirectory = payload.WorkingDirectory,
                IsEnabled = payload.IsEnabled ?? true,
                CreatedAt = DateTime.UtcNow,
            };

            this.context.ManagedSoftware.Add(standalone);
            await this.context.SaveChangesAsync();

            return this.Created(string.Empty, null);
        }
    }
}
