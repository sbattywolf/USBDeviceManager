// <copyright file="AutomationController.cs" company="PlaceholderCompany">
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
public class AutomationController : ControllerBase
{
    private readonly SimRacingContext context;
    private readonly ILogger<AutomationController> logger;
    private readonly IDateTime clock;

    public AutomationController(SimRacingContext context, ILogger<AutomationController> logger, IDateTime clock)
    {
        this.context = context;
        this.logger = logger;
        this.clock = clock;
    }

    /// <summary>
    /// Get all automation rules.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<AutomationRule>>> GetRules()
    {
        return await this.context.AutomationRules
            .Include(r => r.TriggerDevice)
            .Include(r => r.TargetSoftware)
            .ToListAsync();
    }

    /// <summary>
    /// Get specific automation rule by ID.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet("{id}")]
    public async Task<ActionResult<AutomationRule>> GetRule(int id)
    {
        var rule = await this.context.AutomationRules
            .Include(r => r.TriggerDevice)
            .Include(r => r.TargetSoftware)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (rule == null)
        {
            return this.NotFound();
        }

        return rule;
    }

    /// <summary>
    /// Create new automation rule.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost]
    public async Task<ActionResult<AutomationRule>> CreateRule([FromBody] AutomationRuleCreateDto dto)
    {
        var rule = dto.ToModel();

        if (rule.TriggerDeviceId.HasValue)
        {
            var device = await this.context.UsbDevices.FindAsync(rule.TriggerDeviceId.Value);
            if (device == null)
            {
                return this.BadRequest(new { error = "Trigger device not found" });
            }

            rule.TriggerDevice = device;
        }

        if (rule.TargetSoftwareId.HasValue)
        {
            var sw = await this.context.ManagedSoftware.FindAsync(rule.TargetSoftwareId.Value);
            if (sw == null)
            {
                return this.BadRequest(new { error = "Target software not found" });
            }

            rule.TargetSoftware = sw;
        }

        rule.CreatedAt = this.clock.UtcNow;

        this.context.AutomationRules.Add(rule);
        await this.context.SaveChangesAsync();

        return this.CreatedAtAction(nameof(this.GetRule), new { id = rule.Id }, rule);
    }

    /// <summary>
    /// Update automation rule.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateRule(int id, AutomationRule rule)
    {
        if (id != rule.Id)
        {
            return this.BadRequest();
        }

        this.context.Entry(rule).State = EntityState.Modified;

        try
        {
            await this.context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!this.RuleExists(id))
            {
                return this.NotFound();
            }

            throw;
        }

        return this.NoContent();
    }

    /// <summary>
    /// Delete automation rule.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteRule(int id)
    {
        var rule = await this.context.AutomationRules.FindAsync(id);
        if (rule == null)
        {
            return this.NotFound();
        }

        this.context.AutomationRules.Remove(rule);
        await this.context.SaveChangesAsync();

        return this.NoContent();
    }

    /// <summary>
    /// Execute automation rule manually.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("{id}/execute")]
    public async Task<IActionResult> ExecuteRule(int id)
    {
        var rule = await this.context.AutomationRules
            .Include(r => r.TriggerDevice)
            .Include(r => r.TargetSoftware)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (rule == null)
        {
            return this.NotFound();
        }

        if (!rule.IsEnabled)
        {
            return this.BadRequest("Rule is disabled");
        }

        try
        {
            var success = await this.ExecuteRuleAction(rule);

            var execution = new RuleExecution
            {
                RuleId = id,
                Success = success,
                ExecutedAt = this.clock.UtcNow,
            };

            this.context.RuleExecutions.Add(execution);
            await this.context.SaveChangesAsync();

            this.logger.LogInformation("Executed rule {RuleName} manually with result: {Success}", rule.Name, success);

            return this.Ok(new
            {
                ruleId = id,
                success = success,
                timestamp = this.clock.UtcNow,
            });
        }
        catch (Exception ex)
        {
            var execution = new RuleExecution
            {
                RuleId = id,
                Success = false,
                ErrorMessage = ex.Message,
                ExecutedAt = DateTime.UtcNow,
            };

            this.context.RuleExecutions.Add(execution);
            await this.context.SaveChangesAsync();

            this.logger.LogError(ex, "Failed to execute rule {RuleName}", rule.Name);
            return this.StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Enable/disable automation rule.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("{id}/toggle")]
    public async Task<IActionResult> ToggleRule(int id, [FromBody] bool enabled)
    {
        var rule = await this.context.AutomationRules.FindAsync(id);
        if (rule == null)
        {
            return this.NotFound();
        }

        rule.IsEnabled = enabled;
        await this.context.SaveChangesAsync();

        this.logger.LogInformation("Automation rule {RuleName} {Action}", rule.Name, enabled ? "enabled" : "disabled");

        return this.Ok(new { ruleId = id, enabled = enabled, timestamp = this.clock.UtcNow });
    }

    /// <summary>
    /// Get execution history for a rule.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet("{id}/executions")]
    public async Task<ActionResult<IEnumerable<RuleExecution>>> GetRuleExecutions(int id, [FromQuery] int limit = 100)
    {
        var executions = await this.context.RuleExecutions
            .Where(e => e.RuleId == id)
            .OrderByDescending(e => e.ExecutedAt)
            .Take(limit)
            .ToListAsync();

        return executions;
    }

    /// <summary>
    /// Get all rule executions across all rules.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpGet("executions")]
    public async Task<ActionResult<IEnumerable<RuleExecution>>> GetAllExecutions([FromQuery] int hours = 24, [FromQuery] int limit = 1000)
    {
        var cutoff = this.clock.UtcNow.AddHours(-hours);

        var executions = await this.context.RuleExecutions
            .Include(e => e.Rule)
            .Where(e => e.ExecutedAt >= cutoff)
            .OrderByDescending(e => e.ExecutedAt)
            .Take(limit)
            .ToListAsync();

        return executions;
    }

    /// <summary>
    /// Trigger rules based on device events.
    /// </summary>
    /// <returns><placeholder>A <see cref="Task"/> representing the asynchronous operation.</placeholder></returns>
    [HttpPost("trigger/device")]
    public async Task<IActionResult> TriggerDeviceRules([FromBody] DeviceEventRequest request)
    {
        var trigger = request.EventType switch
        {
            "connected" => AutomationTrigger.DeviceConnected,
            "disconnected" => AutomationTrigger.DeviceDisconnected,
            _ => (AutomationTrigger?)null
        };

        if (trigger == null)
        {
            return this.BadRequest("Invalid event type");
        }

        var rules = await this.context.AutomationRules
            .Include(r => r.TriggerDevice)
            .Include(r => r.TargetSoftware)
            .Where(r => r.IsEnabled &&
                       r.Trigger == trigger &&
                       r.TriggerDeviceId == request.DeviceId)
            .ToListAsync();

        var results = new List<object>();

        foreach (var rule in rules)
        {
            try
            {
                var success = await this.ExecuteRuleAction(rule);

                var execution = new RuleExecution
                {
                    RuleId = rule.Id,
                    Success = success,
                    ExecutedAt = this.clock.UtcNow,
                };

                this.context.RuleExecutions.Add(execution);

                results.Add(new { ruleId = rule.Id, ruleName = rule.Name, success = success });

                this.logger.LogInformation(
                    "Triggered rule {RuleName} for device event {EventType} with result: {Success}",
                    rule.Name, request.EventType, success);
            }
            catch (Exception ex)
            {
                var execution = new RuleExecution
                {
                    RuleId = rule.Id,
                    Success = false,
                    ErrorMessage = ex.Message,
                    ExecutedAt = this.clock.UtcNow,
                };

                this.context.RuleExecutions.Add(execution);

                results.Add(new { ruleId = rule.Id, ruleName = rule.Name, success = false, error = ex.Message });

                this.logger.LogError(ex, "Failed to execute triggered rule {RuleName}", rule.Name);
            }
        }

        await this.context.SaveChangesAsync();

        return this.Ok(new
        {
            triggeredRules = results.Count,
            results = results,
            timestamp = this.clock.UtcNow,
        });
    }

    private async Task<bool> ExecuteRuleAction(AutomationRule rule)
    {
        switch (rule.Action)
        {
            case AutomationAction.StartSoftware:
                if (rule.TargetSoftware != null)
                {
                    // This would typically call the SoftwareController or a service
                    this.logger.LogInformation("Would start software: {SoftwareName}", rule.TargetSoftware.Name);
                    return true;
                }

                break;

            case AutomationAction.StopSoftware:
                if (rule.TargetSoftware != null)
                {
                    // This would typically call the SoftwareController or a service
                    this.logger.LogInformation("Would stop software: {SoftwareName}", rule.TargetSoftware.Name);
                    return true;
                }

                break;

            case AutomationAction.RestartSoftware:
                if (rule.TargetSoftware != null)
                {
                    // This would typically call the SoftwareController or a service
                    this.logger.LogInformation("Would restart software: {SoftwareName}", rule.TargetSoftware.Name);
                    return true;
                }

                break;

            case AutomationAction.SendNotification:
                this.logger.LogInformation("Would send notification for rule: {RuleName}", rule.Name);
                return true;

            case AutomationAction.RunScript:
                this.logger.LogInformation("Would run script for rule: {RuleName}", rule.Name);
                return true;

            default:
                this.logger.LogWarning("Unknown automation action: {Action}", rule.Action);
                return false;
        }

        return false;
    }

    private bool RuleExists(int id)
    {
        return this.context.AutomationRules.Any(e => e.Id == id);
    }
}

public class DeviceEventRequest
{
    public int DeviceId
    {
        get; set;
    }

    public string EventType { get; set; } = string.Empty; // "connected" or "disconnected"
}
