using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SimRacingDashboard.Data;
using SimRacingDashboard.Models;

namespace SimRacingDashboard.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DevicesController : ControllerBase
{
    private readonly SimRacingContext _context;
    private readonly ILogger<DevicesController> _logger;

    public DevicesController(SimRacingContext context, ILogger<DevicesController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Get all USB devices
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<UsbDevice>>> GetDevices()
    {
        return await _context.UsbDevices.ToListAsync();
    }

    /// <summary>
    /// Get specific USB device by ID
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<UsbDevice>> GetDevice(int id)
    {
        var device = await _context.UsbDevices.FindAsync(id);
        
        if (device == null)
        {
            return NotFound();
        }

        return device;
    }

    /// <summary>
    /// Add a new USB device to monitoring
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<UsbDevice>> CreateDevice(UsbDevice device)
    {
        _context.UsbDevices.Add(device);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetDevice), new { id = device.Id }, device);
    }

    /// <summary>
    /// Update USB device configuration
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateDevice(int id, UsbDevice device)
    {
        if (id != device.Id)
        {
            return BadRequest();
        }

        _context.Entry(device).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!DeviceExists(id))
            {
                return NotFound();
            }
            throw;
        }

        return NoContent();
    }

    /// <summary>
    /// Remove USB device from monitoring
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteDevice(int id)
    {
        var device = await _context.UsbDevices.FindAsync(id);
        if (device == null)
        {
            return NotFound();
        }

        _context.UsbDevices.Remove(device);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    /// <summary>
    /// Get current status of a USB device
    /// </summary>
    [HttpGet("{id}/status")]
    public async Task<ActionResult<DeviceStatus>> GetDeviceStatus(int id)
    {
        var status = await _context.DeviceStatuses
            .Where(s => s.DeviceId == id)
            .OrderByDescending(s => s.Timestamp)
            .FirstOrDefaultAsync();

        if (status == null)
        {
            return NotFound();
        }

        return status;
    }

    /// <summary>
    /// Get status history for a USB device
    /// </summary>
    [HttpGet("{id}/status/history")]
    public async Task<ActionResult<IEnumerable<DeviceStatus>>> GetDeviceStatusHistory(int id, [FromQuery] int hours = 24)
    {
        var cutoff = DateTime.UtcNow.AddHours(-hours);
        
        var history = await _context.DeviceStatuses
            .Where(s => s.DeviceId == id && s.Timestamp >= cutoff)
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        return history;
    }

    /// <summary>
    /// Scan for new USB devices
    /// </summary>
    [HttpPost("scan")]
    public async Task<ActionResult<IEnumerable<UsbDevice>>> ScanForDevices()
    {
        // This would typically call a service to scan for USB devices
        // For now, return a placeholder response
        _logger.LogInformation("USB device scan requested");
        
        // TODO: Implement actual USB device scanning
        return Ok(new { message = "Device scan initiated", timestamp = DateTime.UtcNow });
    }

    /// <summary>
    /// Enable/disable a USB device
    /// </summary>
    [HttpPost("{id}/toggle")]
    public async Task<IActionResult> ToggleDevice(int id, [FromBody] bool enabled)
    {
        var device = await _context.UsbDevices.FindAsync(id);
        if (device == null)
        {
            return NotFound();
        }

        device.IsEnabled = enabled;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Device {DeviceId} {Action}", id, enabled ? "enabled" : "disabled");

        return Ok(new { deviceId = id, enabled = enabled, timestamp = DateTime.UtcNow });
    }

    private bool DeviceExists(int id)
    {
        return _context.UsbDevices.Any(e => e.Id == id);
    }
}