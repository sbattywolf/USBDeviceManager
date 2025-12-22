// <copyright file="DevicesController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SimRacingDashboard.Data;
using SimRacingDashboard.DTOs;
using SimRacingDashboard.Models;
using SimRacingDashboard.Services;

namespace SimRacingDashboard.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DevicesController : ControllerBase
{
    private readonly SimRacingContext context;
    private readonly ILogger<DevicesController> logger;
    private readonly IDateTime clock;

    public DevicesController(SimRacingContext context, ILogger<DevicesController> logger, IDateTime clock)
    {
        this.context = context;
        this.logger = logger;
        this.clock = clock;
    }

    /// <summary>
    /// Get all USB devices.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<UsbDevice>>> GetDevices()
    {
        return await this.context.UsbDevices.ToListAsync();
    }

    /// <summary>
    /// Get specific USB device by ID.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet("{id}")]
    public async Task<ActionResult<UsbDevice>> GetDevice(int id)
    {
        var device = await this.context.UsbDevices.FindAsync(id);

        if (device == null)
        {
            return this.NotFound();
        }

        return device;
    }

    /// <summary>
    /// Add a new USB device to monitoring.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost]
    public async Task<ActionResult<UsbDevice>> CreateDevice([FromBody] DeviceCreateDto dto)
    {
        if (!this.ModelState.IsValid)
        {
            return this.BadRequest(this.ModelState);
        }

        var device = dto.ToModel();
        device.CreatedAt = this.clock.UtcNow;
        device.LastSeen = this.clock.UtcNow;

        this.context.UsbDevices.Add(device);
        await this.context.SaveChangesAsync();

        return this.CreatedAtAction(nameof(this.GetDevice), new { id = device.Id }, device);
    }

    /// <summary>
    /// Update USB device configuration.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateDevice(int id, [FromBody] DeviceCreateDto dto)
    {
        var device = await this.context.UsbDevices.FindAsync(id);
        if (device == null)
        {
            return this.NotFound();
        }

        // patch fields from DTO
        device.DeviceId = dto.DeviceId;
        device.Name = dto.Name;
        device.VendorId = dto.VendorId;
        device.ProductId = dto.ProductId;
        device.Description = dto.Description;
        device.IsEnabled = dto.IsEnabled;

        try
        {
            await this.context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!this.DeviceExists(id))
            {
                return this.NotFound();
            }

            throw;
        }

        return this.NoContent();
    }

    /// <summary>
    /// Remove USB device from monitoring.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteDevice(int id)
    {
        var device = await this.context.UsbDevices.FindAsync(id);
        if (device == null)
        {
            return this.NotFound();
        }

        this.context.UsbDevices.Remove(device);
        await this.context.SaveChangesAsync();

        return this.NoContent();
    }

    /// <summary>
    /// Get current status of a USB device.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet("{id}/status")]
    public async Task<ActionResult<DeviceStatus>> GetDeviceStatus(int id)
    {
        var status = await this.context.DeviceStatuses
            .Where(s => s.DeviceId == id)
            .OrderByDescending(s => s.Timestamp)
            .FirstOrDefaultAsync();

        if (status == null)
        {
            return this.NotFound();
        }

        return status;
    }

    /// <summary>
    /// Get status history for a USB device.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet("{id}/status/history")]
    public async Task<ActionResult<IEnumerable<DeviceStatus>>> GetDeviceStatusHistory(int id, [FromQuery] int hours = 24)
    {
        var cutoff = this.clock.UtcNow.AddHours(-hours);

        var history = await this.context.DeviceStatuses
            .Where(s => s.DeviceId == id && s.Timestamp >= cutoff)
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        return history;
    }

    /// <summary>
    /// Scan for new USB devices.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("scan")]
    public async Task<ActionResult<IEnumerable<UsbDevice>>> ScanForDevices()
    {
        // This would typically call a service to scan for USB devices
        // For now, return a placeholder response
        this.logger.LogInformation("USB device scan requested");

        // TODO: Implement actual USB device scanning
        return this.Ok(new { message = "Device scan initiated", timestamp = this.clock.UtcNow });
    }

    /// <summary>
    /// Enable/disable a USB device.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("{id}/toggle")]
    public async Task<IActionResult> ToggleDevice(int id, [FromBody] bool enabled)
    {
        var device = await this.context.UsbDevices.FindAsync(id);
        if (device == null)
        {
            return this.NotFound();
        }

        device.IsEnabled = enabled;
        await this.context.SaveChangesAsync();

        this.logger.LogInformation("Device {DeviceId} {Action}", id, enabled ? "enabled" : "disabled");

        return this.Ok(new { deviceId = id, enabled = enabled, timestamp = this.clock.UtcNow });
    }

    private bool DeviceExists(int id)
    {
        return this.context.UsbDevices.Any(e => e.Id == id);
    }
}
