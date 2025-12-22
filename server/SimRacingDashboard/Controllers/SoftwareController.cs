using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SimRacingDashboard.Data;
using SimRacingDashboard.Models;
using System.Diagnostics;

namespace SimRacingDashboard.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SoftwareController : ControllerBase
{
    private readonly SimRacingContext _context;
    private readonly ILogger<SoftwareController> _logger;

    public SoftwareController(SimRacingContext context, ILogger<SoftwareController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Get all managed software
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ManagedSoftware>>> GetSoftware()
    {
        return await _context.ManagedSoftware.ToListAsync();
    }

    /// <summary>
    /// Get specific software by ID
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<ManagedSoftware>> GetSoftware(int id)
    {
        var software = await _context.ManagedSoftware.FindAsync(id);
        
        if (software == null)
        {
            return NotFound();
        }

        return software;
    }

    /// <summary>
    /// Add new software to management
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<ManagedSoftware>> CreateSoftware(ManagedSoftware software)
    {
        _context.ManagedSoftware.Add(software);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetSoftware), new { id = software.Id }, software);
    }

    /// <summary>
    /// Update software configuration
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateSoftware(int id, ManagedSoftware software)
    {
        if (id != software.Id)
        {
            return BadRequest();
        }

        _context.Entry(software).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!SoftwareExists(id))
            {
                return NotFound();
            }
            throw;
        }

        return NoContent();
    }

    /// <summary>
    /// Remove software from management
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteSoftware(int id)
    {
        var software = await _context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return NotFound();
        }

        _context.ManagedSoftware.Remove(software);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    /// <summary>
    /// Start software
    /// </summary>
    [HttpPost("{id}/start")]
    public async Task<IActionResult> StartSoftware(int id)
    {
        var software = await _context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return NotFound();
        }

        if (!software.IsEnabled)
        {
            return BadRequest("Software is disabled");
        }

        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = software.ExecutablePath,
                Arguments = software.StartupArguments ?? "",
                WorkingDirectory = software.WorkingDirectory ?? Path.GetDirectoryName(software.ExecutablePath) ?? "",
                UseShellExecute = false
            };

            var process = Process.Start(startInfo);
            if (process == null)
            {
                throw new InvalidOperationException("Failed to start process");
            }

            // Log status
            var status = new SoftwareStatus
            {
                SoftwareId = id,
                IsRunning = true,
                ProcessId = process.Id,
                Status = "Running",
                LastStarted = DateTime.UtcNow,
                Timestamp = DateTime.UtcNow
            };

            _context.SoftwareStatuses.Add(status);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Started software {SoftwareName} with PID {ProcessId}", software.Name, process.Id);

            return Ok(new { 
                softwareId = id, 
                processId = process.Id, 
                status = "started", 
                timestamp = DateTime.UtcNow 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start software {SoftwareName}", software.Name);
            
            var status = new SoftwareStatus
            {
                SoftwareId = id,
                IsRunning = false,
                Status = "Failed",
                ErrorMessage = ex.Message,
                Timestamp = DateTime.UtcNow
            };

            _context.SoftwareStatuses.Add(status);
            await _context.SaveChangesAsync();

            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Stop software
    /// </summary>
    [HttpPost("{id}/stop")]
    public async Task<IActionResult> StopSoftware(int id)
    {
        var software = await _context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return NotFound();
        }

        try
        {
            // Find running process
            var currentStatus = await _context.SoftwareStatuses
                .Where(s => s.SoftwareId == id && s.IsRunning)
                .OrderByDescending(s => s.Timestamp)
                .FirstOrDefaultAsync();

            if (currentStatus?.ProcessId != null)
            {
                try
                {
                    var process = Process.GetProcessById(currentStatus.ProcessId.Value);
                    process.Kill();
                    process.WaitForExit(5000); // Wait up to 5 seconds
                }
                catch (ArgumentException)
                {
                    // Process doesn't exist, that's fine
                }
                catch (InvalidOperationException)
                {
                    // Process already exited, that's fine
                }
            }

            // Log status
            var status = new SoftwareStatus
            {
                SoftwareId = id,
                IsRunning = false,
                Status = "Stopped",
                LastStopped = DateTime.UtcNow,
                Timestamp = DateTime.UtcNow
            };

            _context.SoftwareStatuses.Add(status);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Stopped software {SoftwareName}", software.Name);

            return Ok(new { 
                softwareId = id, 
                status = "stopped", 
                timestamp = DateTime.UtcNow 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to stop software {SoftwareName}", software.Name);
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Restart software
    /// </summary>
    [HttpPost("{id}/restart")]
    public async Task<IActionResult> RestartSoftware(int id)
    {
        // Stop first
        await StopSoftware(id);
        
        // Wait a moment
        await Task.Delay(1000);
        
        // Start again
        return await StartSoftware(id);
    }

    /// <summary>
    /// Get software status
    /// </summary>
    [HttpGet("{id}/status")]
    public async Task<ActionResult<SoftwareStatus>> GetSoftwareStatus(int id)
    {
        var status = await _context.SoftwareStatuses
            .Where(s => s.SoftwareId == id)
            .OrderByDescending(s => s.Timestamp)
            .FirstOrDefaultAsync();

        if (status == null)
        {
            return NotFound();
        }

        return status;
    }

    /// <summary>
    /// Get software status history
    /// </summary>
    [HttpGet("{id}/status/history")]
    public async Task<ActionResult<IEnumerable<SoftwareStatus>>> GetSoftwareStatusHistory(int id, [FromQuery] int hours = 24)
    {
        var cutoff = DateTime.UtcNow.AddHours(-hours);
        
        var history = await _context.SoftwareStatuses
            .Where(s => s.SoftwareId == id && s.Timestamp >= cutoff)
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        return history;
    }

    /// <summary>
    /// Enable/disable software
    /// </summary>
    [HttpPost("{id}/toggle")]
    public async Task<IActionResult> ToggleSoftware(int id, [FromBody] bool enabled)
    {
        var software = await _context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return NotFound();
        }

        software.IsEnabled = enabled;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Software {SoftwareName} {Action}", software.Name, enabled ? "enabled" : "disabled");

        return Ok(new { softwareId = id, enabled = enabled, timestamp = DateTime.UtcNow });
    }

    private bool SoftwareExists(int id)
    {
        return _context.ManagedSoftware.Any(e => e.Id == id);
    }
}