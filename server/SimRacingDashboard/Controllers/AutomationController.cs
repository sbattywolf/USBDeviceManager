using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SimRacingDashboard.Data;
using SimRacingDashboard.Models;

namespace SimRacingDashboard.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AutomationController : ControllerBase
{
    private readonly SimRacingContext _context;
    private readonly ILogger<AutomationController> _logger;

    public AutomationController(SimRacingContext context, ILogger<AutomationController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Get all automation rules
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<AutomationRule>>> GetRules()
    {
        return await _context.AutomationRules
            .Include(r => r.TriggerDevice)
            .Include(r => r.TargetSoftware)
            .ToListAsync();
    }

    /// <summary>
    /// Get specific automation rule by ID
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<AutomationRule>> GetRule(int id)
    {
        var rule = await _context.AutomationRules
            .Include(r => r.TriggerDevice)
            .Include(r => r.TargetSoftware)
            .FirstOrDefaultAsync(r => r.Id == id);
        
        if (rule == null)
        {
            return NotFound();
        }

        return rule;
    }

    /// <summary>
    /// Create new automation rule
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<AutomationRule>> CreateRule(AutomationRule rule)
    {
        // Validate referenced entities to avoid foreign-key errors and ensure
        // EF does not try to insert detached or missing navigation objects.
        if (rule.TriggerDeviceId.HasValue)
        {
            var device = await _context.UsbDevices.FindAsync(rule.TriggerDeviceId.Value);
            if (device == null)
            {
                return BadRequest(new { error = "Trigger device not found" });
            }
            // attach existing device instance to the rule so EF tracks correctly
            rule.TriggerDevice = device;
        }

        if (rule.TargetSoftwareId.HasValue)
        {
            var sw = await _context.ManagedSoftware.FindAsync(rule.TargetSoftwareId.Value);
            if (sw == null)
            {
                return BadRequest(new { error = "Target software not found" });
            }
            rule.TargetSoftware = sw;
        }

        _context.AutomationRules.Add(rule);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetRule), new { id = rule.Id }, rule);
    }

    /// <summary>
    /// Update automation rule
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateRule(int id, AutomationRule rule)
    {
        if (id != rule.Id)
        {
            return BadRequest();
        }

        _context.Entry(rule).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!RuleExists(id))
            {
                return NotFound();
            }
            throw;
        }

        return NoContent();
    }

    /// <summary>
    /// Delete automation rule
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteRule(int id)
    {
        var rule = await _context.AutomationRules.FindAsync(id);
        if (rule == null)
        {
            return NotFound();
        }

        _context.AutomationRules.Remove(rule);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    /// <summary>
    /// Execute automation rule manually
    /// </summary>
    [HttpPost("{id}/execute")]
    public async Task<IActionResult> ExecuteRule(int id)
    {
        var rule = await _context.AutomationRules
            .Include(r => r.TriggerDevice)
            .Include(r => r.TargetSoftware)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (rule == null)
        {
            return NotFound();
        }

        if (!rule.IsEnabled)
        {
            return BadRequest("Rule is disabled");
        }

        try
        {
            var success = await ExecuteRuleAction(rule);

            var execution = new RuleExecution
            {
                RuleId = id,
                Success = success,
                ExecutedAt = DateTime.UtcNow
            };

            _context.RuleExecutions.Add(execution);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Executed rule {RuleName} manually with result: {Success}", rule.Name, success);

            return Ok(new { 
                ruleId = id, 
                success = success, 
                timestamp = DateTime.UtcNow 
            });
        }
        catch (Exception ex)
        {
            var execution = new RuleExecution
            {
                RuleId = id,
                Success = false,
                ErrorMessage = ex.Message,
                ExecutedAt = DateTime.UtcNow
            };

            _context.RuleExecutions.Add(execution);
            await _context.SaveChangesAsync();

            _logger.LogError(ex, "Failed to execute rule {RuleName}", rule.Name);
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Enable/disable automation rule
    /// </summary>
    [HttpPost("{id}/toggle")]
    public async Task<IActionResult> ToggleRule(int id, [FromBody] bool enabled)
    {
        var rule = await _context.AutomationRules.FindAsync(id);
        if (rule == null)
        {
            return NotFound();
        }

        rule.IsEnabled = enabled;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Automation rule {RuleName} {Action}", rule.Name, enabled ? "enabled" : "disabled");

        return Ok(new { ruleId = id, enabled = enabled, timestamp = DateTime.UtcNow });
    }

    /// <summary>
    /// Get execution history for a rule
    /// </summary>
    [HttpGet("{id}/executions")]
    public async Task<ActionResult<IEnumerable<RuleExecution>>> GetRuleExecutions(int id, [FromQuery] int limit = 100)
    {
        var executions = await _context.RuleExecutions
            .Where(e => e.RuleId == id)
            .OrderByDescending(e => e.ExecutedAt)
            .Take(limit)
            .ToListAsync();

        return executions;
    }

    /// <summary>
    /// Get all rule executions across all rules
    /// </summary>
    [HttpGet("executions")]
    public async Task<ActionResult<IEnumerable<RuleExecution>>> GetAllExecutions([FromQuery] int hours = 24, [FromQuery] int limit = 1000)
    {
        var cutoff = DateTime.UtcNow.AddHours(-hours);
        
        var executions = await _context.RuleExecutions
            .Include(e => e.Rule)
            .Where(e => e.ExecutedAt >= cutoff)
            .OrderByDescending(e => e.ExecutedAt)
            .Take(limit)
            .ToListAsync();

        return executions;
    }

    /// <summary>
    /// Trigger rules based on device events
    /// </summary>
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
            return BadRequest("Invalid event type");
        }

        var rules = await _context.AutomationRules
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
                var success = await ExecuteRuleAction(rule);

                var execution = new RuleExecution
                {
                    RuleId = rule.Id,
                    Success = success,
                    ExecutedAt = DateTime.UtcNow
                };

                _context.RuleExecutions.Add(execution);

                results.Add(new { ruleId = rule.Id, ruleName = rule.Name, success = success });

                _logger.LogInformation("Triggered rule {RuleName} for device event {EventType} with result: {Success}", 
                    rule.Name, request.EventType, success);
            }
            catch (Exception ex)
            {
                var execution = new RuleExecution
                {
                    RuleId = rule.Id,
                    Success = false,
                    ErrorMessage = ex.Message,
                    ExecutedAt = DateTime.UtcNow
                };

                _context.RuleExecutions.Add(execution);

                results.Add(new { ruleId = rule.Id, ruleName = rule.Name, success = false, error = ex.Message });

                _logger.LogError(ex, "Failed to execute triggered rule {RuleName}", rule.Name);
            }
        }

        await _context.SaveChangesAsync();

        return Ok(new { 
            triggeredRules = results.Count, 
            results = results, 
            timestamp = DateTime.UtcNow 
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
                    _logger.LogInformation("Would start software: {SoftwareName}", rule.TargetSoftware.Name);
                    return true;
                }
                break;

            case AutomationAction.StopSoftware:
                if (rule.TargetSoftware != null)
                {
                    // This would typically call the SoftwareController or a service
                    _logger.LogInformation("Would stop software: {SoftwareName}", rule.TargetSoftware.Name);
                    return true;
                }
                break;

            case AutomationAction.RestartSoftware:
                if (rule.TargetSoftware != null)
                {
                    // This would typically call the SoftwareController or a service
                    _logger.LogInformation("Would restart software: {SoftwareName}", rule.TargetSoftware.Name);
                    return true;
                }
                break;

            case AutomationAction.SendNotification:
                _logger.LogInformation("Would send notification for rule: {RuleName}", rule.Name);
                return true;

            case AutomationAction.RunScript:
                _logger.LogInformation("Would run script for rule: {RuleName}", rule.Name);
                return true;

            default:
                _logger.LogWarning("Unknown automation action: {Action}", rule.Action);
                return false;
        }

        return false;
    }

    private bool RuleExists(int id)
    {
        return _context.AutomationRules.Any(e => e.Id == id);
    }
}

public class DeviceEventRequest
{
    public int DeviceId { get; set; }
    public string EventType { get; set; } = string.Empty; // "connected" or "disconnected"
}