// <copyright file="SoftwareController.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace USBDeviceManager.Controllers;

using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using USBDeviceManager.Data;
using USBDeviceManager.DTOs;
using USBDeviceManager.Models;
using USBDeviceManager.Services;

/// <summary>
/// Controller for managing managed software entries and execution.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class SoftwareController : ControllerBase
{
    private readonly SimRacingContext context;
    private readonly ILogger<SoftwareController> logger;
    private readonly IDateTime clock;

    /// <summary>
    /// Initializes a new instance of the <see cref="SoftwareController"/> class.
    /// </summary>
    /// <param name="context">Database context.</param>
    /// <param name="logger">Logger instance.</param>
    /// <param name="clock">Clock abstraction.</param>
    public SoftwareController(SimRacingContext context, ILogger<SoftwareController> logger, IDateTime clock)
    {
        this.context = context;
        this.logger = logger;
        this.clock = clock;
    }

    /// <summary>
    /// Get all managed software.
    /// </summary>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ManagedSoftware>>> GetSoftware()
    {
        return await this.context.ManagedSoftware.ToListAsync();
    }

    /// <summary>
    /// Get specific software by ID.
    /// </summary>
    /// <param name="id">The software identifier.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("{id}")]
    public async Task<ActionResult<ManagedSoftware>> GetSoftware(int id)
    {
        ManagedSoftware? software = await this.context.ManagedSoftware.FindAsync(id);

        if (software == null)
        {
            return this.NotFound();
        }

        return software;
    }

    /// <summary>
    /// Add new software to management.
    /// </summary>
    /// <param name="dto">The software creation DTO.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost]
    public async Task<ActionResult<ManagedSoftware>> CreateSoftware([FromBody] SoftwareCreateDto dto)
    {
        if (!this.ModelState.IsValid)
        {
            return this.BadRequest(this.ModelState);
        }

        ManagedSoftware software = dto.ToModel();
        software.CreatedAt = this.clock.UtcNow;

        this.context.ManagedSoftware.Add(software);
        await this.context.SaveChangesAsync();

        return this.CreatedAtAction(nameof(this.GetSoftware), new { id = software.Id }, software);
    }

    /// <summary>
    /// Update software configuration.
    /// </summary>
    /// <param name="id">The id of the software to update.</param>
    /// <param name="dto">The software create DTO with updated values.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateSoftware(int id, [FromBody] SoftwareCreateDto dto)
    {
        ManagedSoftware? software = await this.context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return this.NotFound();
        }

        // patch fields from DTO
        software.Name = dto.Name;
        software.ExecutablePath = dto.ExecutablePath;
        software.StartupArguments = dto.StartupArguments;
        software.WorkingDirectory = dto.WorkingDirectory;
        software.AutoStart = dto.AutoStart;
        software.IsEnabled = dto.IsEnabled;

        try
        {
            await this.context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!this.SoftwareExists(id))
            {
                return this.NotFound();
            }

            throw;
        }

        return this.NoContent();
    }

    /// <summary>
    /// Remove software from management.
    /// </summary>
    /// <param name="id">The id of the software to remove.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteSoftware(int id)
    {
        ManagedSoftware? software = await this.context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return this.NotFound();
        }

        this.context.ManagedSoftware.Remove(software);
        await this.context.SaveChangesAsync();

        return this.NoContent();
    }

    /// <summary>
    /// Start software.
    /// </summary>
    /// <param name="id">The id of the software to start.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost("{id}/start")]
    public async Task<IActionResult> StartSoftware(int id)
    {
        ManagedSoftware? software = await this.context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return this.NotFound();
        }

        if (!software.IsEnabled)
        {
            return this.BadRequest("Software is disabled");
        }

        // Validate executable path exists before attempting to start.
        if (string.IsNullOrWhiteSpace(software.ExecutablePath) || !System.IO.File.Exists(software.ExecutablePath))
        {
            this.logger.LogWarning("Executable path missing or not found for software {SoftwareName}: {Path}", software.Name, software.ExecutablePath);

            var failedStatus = new SoftwareStatus
            {
                SoftwareId = id,
                IsRunning = false,
                Status = "Failed",
                ErrorMessage = "Executable not found",
                Timestamp = this.clock.UtcNow,
            };

            this.context.SoftwareStatuses.Add(failedStatus);
            await this.context.SaveChangesAsync();

            return this.BadRequest(new { error = "Executable not found", path = software.ExecutablePath });
        }
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = software.ExecutablePath,
                Arguments = software.StartupArguments ?? string.Empty,
                WorkingDirectory = software.WorkingDirectory ?? Path.GetDirectoryName(software.ExecutablePath) ?? string.Empty,
                UseShellExecute = false,
            };

            Process process = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to start process");

            // Log status
            var status = new SoftwareStatus
            {
                SoftwareId = id,
                IsRunning = true,
                ProcessId = process.Id,
                Status = "Running",
                LastStarted = this.clock.UtcNow,
                Timestamp = this.clock.UtcNow,
            };

            this.context.SoftwareStatuses.Add(status);
            await this.context.SaveChangesAsync();

            this.logger.LogInformation("Started software {SoftwareName} with PID {ProcessId}", software.Name, process.Id);

            return this.Ok(new
            {
                softwareId = id,
                processId = process.Id,
                status = "started",
                timestamp = this.clock.UtcNow,
            });
        }
        catch (Exception ex)
        {
            this.logger.LogError(ex, "Failed to start software {SoftwareName}", software.Name);

            var status = new SoftwareStatus
            {
                SoftwareId = id,
                IsRunning = false,
                Status = "Failed",
                ErrorMessage = ex.Message,
                Timestamp = this.clock.UtcNow,
            };

            this.context.SoftwareStatuses.Add(status);
            await this.context.SaveChangesAsync();

            return this.StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Stop software.
    /// </summary>
    /// <param name="id">The id of the software to stop.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost("{id}/stop")]
    public async Task<IActionResult> StopSoftware(int id)
    {
        ManagedSoftware? software = await this.context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return this.NotFound();
        }

        try
        {
            // Find running process
            SoftwareStatus? currentStatus = await this.context.SoftwareStatuses
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
                LastStopped = this.clock.UtcNow,
                Timestamp = this.clock.UtcNow,
            };

            this.context.SoftwareStatuses.Add(status);
            await this.context.SaveChangesAsync();

            this.logger.LogInformation("Stopped software {SoftwareName}", software.Name);

            return this.Ok(new
            {
                softwareId = id,
                status = "stopped",
                timestamp = this.clock.UtcNow,
            });
        }
        catch (Exception ex)
        {
            this.logger.LogError(ex, "Failed to stop software {SoftwareName}", software.Name);
            return this.StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Restart software.
    /// </summary>
    /// <param name="id">The id of the software to restart.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost("{id}/restart")]
    public async Task<IActionResult> RestartSoftware(int id)
    {
        // Stop first
        await this.StopSoftware(id);

        // Wait a moment
        await Task.Delay(1000);

        // Start again
        return await this.StartSoftware(id);
    }

    /// <summary>
    /// Get software status.
    /// </summary>
    /// <param name="id">The id of the software.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("{id}/status")]
    public async Task<ActionResult<SoftwareStatus>> GetSoftwareStatus(int id)
    {
        SoftwareStatus? status = await this.context.SoftwareStatuses
            .Where(s => s.SoftwareId == id)
            .OrderByDescending(s => s.Timestamp)
            .FirstOrDefaultAsync();

        if (status == null)
        {
            return this.NotFound();
        }

        return status;
    }

    /// <summary>
    /// Get software status history.
    /// </summary>
    /// <param name="id">The id of the software.</param>
    /// <param name="hours">Time window in hours to include in history.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpGet("{id}/status/history")]
    public async Task<ActionResult<IEnumerable<SoftwareStatus>>> GetSoftwareStatusHistory(int id, [FromQuery] int hours = 24)
    {
        DateTime cutoff = this.clock.UtcNow.AddHours(-hours);

        List<SoftwareStatus> history = await this.context.SoftwareStatuses
            .Where(s => s.SoftwareId == id && s.Timestamp >= cutoff)
            .OrderByDescending(s => s.Timestamp)
            .ToListAsync();

        return history;
    }

    /// <summary>
    /// Enable/disable software.
    /// </summary>
    /// <param name="id">The id of the software to toggle.</param>
    /// <param name="enabled">True to enable, false to disable.</param>
    /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
    [HttpPost("{id}/toggle")]
    public async Task<IActionResult> ToggleSoftware(int id, [FromBody] bool enabled)
    {
        ManagedSoftware? software = await this.context.ManagedSoftware.FindAsync(id);
        if (software == null)
        {
            return this.NotFound();
        }

        software.IsEnabled = enabled;
        await this.context.SaveChangesAsync();

        this.logger.LogInformation("Software {SoftwareName} {Action}", software.Name, enabled ? "enabled" : "disabled");

        return this.Ok(new { softwareId = id, enabled, timestamp = this.clock.UtcNow });
    }

    private bool SoftwareExists(int id)
    {
        return this.context.ManagedSoftware.Any(e => e.Id == id);
    }
}
