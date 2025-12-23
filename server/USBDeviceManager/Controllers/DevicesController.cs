// <copyright file="DevicesController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Controllers;

using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using USBDeviceManager.Data;
using USBDeviceManager.DTOs;
using USBDeviceManager.Models;
using USBDeviceManager.Services;

/// <summary>
/// Controller for managing USB devices.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class DevicesController : ControllerBase
{
    private readonly SimRacingContext context;
    private readonly ILogger<DevicesController> logger;
    private readonly IDateTime clock;

    /// <summary>
    /// Initializes a new instance of the <see cref="DevicesController"/> class.
    /// </summary>
    /// <param name="context">The database context.</param>
    /// <param name="logger">Logger instance.</param>
    /// <param name="clock">Clock abstraction.</param>
    public DevicesController(SimRacingContext context, ILogger<DevicesController> logger, IDateTime clock)
    {
        this.context = context;
        this.logger = logger;
        this.clock = clock;
    }

    /// <summary>
    /// Get all USB devices.
    /// </summary>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<UsbDevice>>> GetDevices()
    {
        return await this.context.UsbDevices.ToListAsync();
    }

    /// <summary>
    /// Get specific USB device by ID.
    /// </summary>
    /// <param name="id">The device identifier.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("{id}")]
    public async Task<ActionResult<UsbDevice>> GetDevice(int id)
    {
        UsbDevice? device = await this.context.UsbDevices.FindAsync(id);

        if (device == null)
        {
            return this.NotFound();
        }

        return device;
    }

    /// <summary>
    /// Add a new USB device to monitoring.
    /// </summary>
    /// <param name="dto">The device create DTO.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost]
    public async Task<ActionResult<UsbDevice>> CreateDevice([FromBody] DeviceCreateDto dto)
    {
        if (!this.ModelState.IsValid)
        {
            return this.BadRequest(this.ModelState);
        }

        UsbDevice device = dto.ToModel();
        device.CreatedAt = this.clock.UtcNow;
        device.LastSeen = this.clock.UtcNow;

        this.context.UsbDevices.Add(device);
        await this.context.SaveChangesAsync();

        return this.CreatedAtAction(nameof(this.GetDevice), new { id = device.Id }, device);
    }

    /// <summary>
    /// Update USB device configuration.
    /// </summary>
    /// <param name="id">The id of the device to update.</param>
    /// <param name="dto">The device create DTO containing updated values.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateDevice(int id, [FromBody] DeviceCreateDto dto)
    {
        UsbDevice? device = await this.context.UsbDevices.FindAsync(id);
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
    /// <param name="id">The id of the device to remove.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteDevice(int id)
    {
        UsbDevice? device = await this.context.UsbDevices.FindAsync(id);
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
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("{id}/status")]
    public async Task<ActionResult<DeviceStatus>> GetDeviceStatus(int id)
    {
        DeviceStatus? status = await this.context.DeviceStatuses
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
    /// <param name="id">The id of the device.</param>
    /// <param name="hours">Time window in hours to include in history.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("{id}/status/history")]
    public async Task<ActionResult<IEnumerable<DeviceStatus>>> GetDeviceStatusHistory(int id, [FromQuery] int hours = 24)
    {
        DateTime cutoff = this.clock.UtcNow.AddHours(-hours);

        List<DeviceStatus> history = await this.context.DeviceStatuses
            .Where(s => s.DeviceId == id && s.Timestamp >= cutoff)
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        return history;
    }

    /// <summary>
    /// Scan for new USB devices.
    /// </summary>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost("scan")]
    public Task<ActionResult<IEnumerable<UsbDevice>>> ScanForDevices()
    {
        // This would typically call a service to scan for USB devices
        // For now, return a placeholder response
        this.logger.LogInformation("USB device scan requested");

        // TODO: Implement actual USB device scanning
        return Task.FromResult<ActionResult<IEnumerable<UsbDevice>>>(this.Ok(new { message = "Device scan initiated", timestamp = this.clock.UtcNow }));
    }

    /// <summary>
    /// Enable/disable a USB device.
    /// </summary>
    /// <param name="id">The id of the device to toggle.</param>
    /// <param name="enabled">True to enable, false to disable.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost("{id}/toggle")]
    public async Task<IActionResult> ToggleDevice(int id, [FromBody] bool enabled)
    {
        UsbDevice? device = await this.context.UsbDevices.FindAsync(id);
        if (device == null)
        {
            return this.NotFound();
        }

        device.IsEnabled = enabled;
        await this.context.SaveChangesAsync();

        this.logger.LogInformation("Device {DeviceId} {Action}", id, enabled ? "enabled" : "disabled");

        return this.Ok(new { deviceId = id, enabled, timestamp = this.clock.UtcNow });
    }

    private bool DeviceExists(int id)
    {
        return this.context.UsbDevices.Any(e => e.Id == id);
    }
}
