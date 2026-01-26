# Automation Engine Module
# Rule-based automation system for SimRacing environments

using module ..\Utils\Logging.psm1

class AutomationRule {
    [string]$Id
    [string]$Name
    [string]$Description
    [string]$TriggerType  # Device, Software, Schedule, Manual
    [hashtable]$TriggerConfig
    [hashtable]$Conditions
    [array]$Actions
    [bool]$IsEnabled
    [datetime]$LastExecuted
    [int]$ExecutionCount
    [string]$Status

    AutomationRule([hashtable]$config) {
        $this.Id = $config.Id
        $this.Name = $config.Name
        $this.Description = $config.Description
        $this.TriggerType = $config.TriggerType
        $this.TriggerConfig = $config.TriggerConfig
        $this.Conditions = $config.Conditions
        $this.Actions = $config.Actions
        $this.IsEnabled = $config.IsEnabled
        $this.ExecutionCount = 0
        $this.Status = "Ready"
    }

    [bool]EvaluateConditions([hashtable]$context) {
        try {
            if (-not $this.Conditions -or $this.Conditions.Count -eq 0) {
                return $true
            }

            foreach ($condition in $this.Conditions.GetEnumerator()) {
                $result = $this.EvaluateCondition($condition.Key, $condition.Value, $context)
                if (-not $result) {
                    return $false
                }
            }

            return $true
        }
        catch {
            Write-AgentLog "Error evaluating conditions for rule $($this.Name): $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [bool]EvaluateCondition([string]$property, [hashtable]$condition, [hashtable]$context) {
        try {
            $operator = $condition.Operator
            $expectedValue = $condition.Value
            $actualValue = $this.GetContextValue($property, $context)

            switch ($operator) {
                "Equals" { return $actualValue -eq $expectedValue }
                "NotEquals" { return $actualValue -ne $expectedValue }
                "Contains" { return $actualValue -like "*$expectedValue*" }
                "NotContains" { return $actualValue -notlike "*$expectedValue*" }
                "StartsWith" { return $actualValue -like "$expectedValue*" }
                "EndsWith" { return $actualValue -like "*$expectedValue" }
                "GreaterThan" { return [double]$actualValue -gt [double]$expectedValue }
                "LessThan" { return [double]$actualValue -lt [double]$expectedValue }
                "Regex" { return $actualValue -match $expectedValue }
                "Exists" { return $null -ne $actualValue }
                "NotExists" { return $null -eq $actualValue }
                default { return $false }
            }

            # Explicit fallback return (should never reach here)
            return $false
        }
        catch {
            Write-AgentLog "Error evaluating condition: $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [object]GetContextValue([string]$property, [hashtable]$context) {
        $parts = $property.Split('.')
        $value = $context

        foreach ($part in $parts) {
            if ($value -and $value.ContainsKey($part)) {
                $value = $value[$part]
            } else {
                return $null
            }
        }

        return $value
    }

    [array]ExecuteActions([hashtable]$context) {
        $results = @()

        try {
            foreach ($action in $this.Actions) {
                $result = $this.ExecuteAction($action, $context)
                $results += $result
            }

            $this.LastExecuted = Get-Date
            $this.ExecutionCount++
            $this.Status = "Completed"

            Write-AgentLog "Executed rule: $($this.Name) ($($this.Actions.Count) actions)" -Level Info
        }
        catch {
            $this.Status = "Failed"
            Write-AgentLog "Failed to execute rule $($this.Name): $($_.Exception.Message)" -Level Error
            throw
        }

        return $results
    }

    [hashtable]ExecuteAction([hashtable]$action, [hashtable]$context) {
        $actionType = $action.Type
        $actionConfig = $action.Config

        $result = @{
            Type = $actionType
            Success = $false
            Message = ""
            Timestamp = Get-Date
        }

        try {
            switch ($actionType) {
                "StartSoftware" {
                    $softwareName = $actionConfig.SoftwareName
                    if (Get-Command "Start-Software" -ErrorAction SilentlyContinue) {
                        $success = Start-Software -SoftwareName $softwareName
                        $result.Success = $success
                        $result.Message = if ($success) { "Started $softwareName" } else { "Failed to start $softwareName" }
                    }
                }

                "StopSoftware" {
                    $softwareName = $actionConfig.SoftwareName
                    if (Get-Command "Stop-Software" -ErrorAction SilentlyContinue) {
                        $success = Stop-Software -SoftwareName $softwareName
                        $result.Success = $success
                        $result.Message = if ($success) { "Stopped $softwareName" } else { "Failed to stop $softwareName" }
                    }
                }

                "SendNotification" {
                    $message = $actionConfig.Message
                    $title = $actionConfig.Title
                    # Implementation depends on notification system
                    $result.Success = $true
                    $result.Message = "Notification sent: $title - $message"
                }

                "ExecuteScript" {
                    $scriptPath = $actionConfig.ScriptPath
                    $arguments = $actionConfig.Arguments

                    if (Test-Path $scriptPath) {
                        $output = & $scriptPath @arguments 2>&1
                        $result.Success = $LASTEXITCODE -eq 0
                        $result.Message = "Script executed: $scriptPath"
                        $result.Output = $output
                    } else {
                        $result.Message = "Script not found: $scriptPath"
                    }
                }

                "Log" {
                    $message = $actionConfig.Message
                    $level = $actionConfig.Level
                    Write-AgentLog $message -Level $level
                    $result.Success = $true
                    $result.Message = "Logged: $message"
                }

                default {
                    $result.Message = "Unknown action type: $actionType"
                }
            }
        }
        catch {
            $result.Success = $false
            $result.Message = "Action failed: $($_.Exception.Message)"
        }

        return $result
    }
}

class AutomationEngine {
    [hashtable]$Rules
    [hashtable]$Triggers
    [bool]$IsRunning
    [System.Timers.Timer]$ScheduleTimer

    AutomationEngine() {
        $this.Rules = @{}
        $this.Triggers = @{}
        $this.IsRunning = $false
        $this.LoadRules()
    }

    [void]LoadRules() {
        try {
            $rulesPath = Join-Path $PSScriptRoot "..\Utils\automation-rules.json"
            if (Test-Path $rulesPath) {
                $rulesConfig = Get-Content $rulesPath | ConvertFrom-Json

                foreach ($ruleConfig in $rulesConfig.Rules) {
                    # Convert PSCustomObject to Hashtable
                    $ruleHashtable = $this.ConvertToHashtable($ruleConfig)
                    $rule = [AutomationRule]::new($ruleHashtable)
                    $this.Rules[$rule.Id] = $rule
                }

                Write-AgentLog "Loaded $($this.Rules.Count) automation rules" -Level Info
            }
        }
        catch {
            Write-AgentLog "Failed to load automation rules: $($_.Exception.Message)" -Level Error
        }
    }

    [object]ConvertToHashtable([object]$InputObject) {
        if ($InputObject -is [PSCustomObject]) {
            $hashtable = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hashtable[$property.Name] = $this.ConvertToHashtable($property.Value)
            }
            return $hashtable
        }
        elseif ($InputObject -is [System.Object[]] -or $InputObject -is [System.Collections.ArrayList]) {
            return @($InputObject | ForEach-Object { $this.ConvertToHashtable($_) })
        }
        else {
            return $InputObject
        }
    }

    [void]Start() {
        if ($this.IsRunning) {
            Write-AgentLog "Automation engine is already running" -Level Warning
            return
        }

        try {
            Write-AgentLog "Starting automation engine" -Level Info

            # Setup schedule timer for time-based triggers
            $this.ScheduleTimer = New-Object System.Timers.Timer(60000) # Check every minute
            $this.ScheduleTimer.AutoReset = $true

            Register-ObjectEvent -InputObject $this.ScheduleTimer -EventName Elapsed -Action {
                try {
                    [AutomationEngine]$engine = $Event.MessageData
                    $engine.ProcessScheduledTriggers()
                }
                catch {
                    Write-AgentLog "Schedule processing error: $($_.Exception.Message)" -Level Error
                }
            } -MessageData $this | Out-Null

            $this.ScheduleTimer.Start()
            $this.IsRunning = $true

            Write-AgentLog "Automation engine started successfully" -Level Info
        }
        catch {
            Write-AgentLog "Failed to start automation engine: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    [void]Stop() {
        if (-not $this.IsRunning) {
            return
        }

        try {
            if ($this.ScheduleTimer) {
                $this.ScheduleTimer.Stop()
                $this.ScheduleTimer.Dispose()
            }

            $this.IsRunning = $false
            Write-AgentLog "Automation engine stopped" -Level Info
        }
        catch {
            Write-AgentLog "Error stopping automation engine: $($_.Exception.Message)" -Level Error
        }
    }

    [void]ProcessTrigger([string]$triggerType, [hashtable]$context) {
        try {
            $triggeredRules = $this.Rules.Values | Where-Object {
                $_.IsEnabled -and $_.TriggerType -eq $triggerType
            }

            foreach ($rule in $triggeredRules) {
                if ($rule.EvaluateConditions($context)) {
                    Write-AgentLog "Trigger matched rule: $($rule.Name)" -Level Info

                    try {
                        $rule.ExecuteActions($context)
                        Write-AgentLog "Rule executed successfully: $($rule.Name)" -Level Info
                    }
                    catch {
                        Write-AgentLog "Rule execution failed: $($rule.Name) - $($_.Exception.Message)" -Level Error
                    }
                }
            }
        }
        catch {
            Write-AgentLog "Error processing trigger ${triggerType}: $($_.Exception.Message)" -Level Error
        }
    }

    [void]ProcessScheduledTriggers() {
        $now = Get-Date

        $scheduledRules = $this.Rules.Values | Where-Object {
            $_.IsEnabled -and $_.TriggerType -eq "Schedule"
        }

        foreach ($rule in $scheduledRules) {
            try {
                $schedule = $rule.TriggerConfig.Schedule
                if ($this.IsScheduleMatch($schedule, $now, $rule.LastExecuted)) {
                    Write-AgentLog "Schedule triggered rule: $($rule.Name)" -Level Info

                    $context = @{
                        TriggerType = "Schedule"
                        Timestamp = $now
                        Schedule = $schedule
                    }

                    $rule.ExecuteActions($context)
                }
            }
            catch {
                Write-AgentLog "Error processing scheduled rule $($rule.Name): $($_.Exception.Message)" -Level Error
            }
        }
    }

    [bool]IsScheduleMatch([hashtable]$schedule, [datetime]$now, [datetime]$lastExecuted) {
        $type = $schedule.Type
        $interval = $schedule.Interval

        switch ($type) {
            "Interval" {
                $intervalMinutes = [int]$interval
                return ($now - $lastExecuted).TotalMinutes -ge $intervalMinutes
            }

            "Daily" {
                $targetTime = [datetime]$schedule.Time
                $todayTarget = Get-Date -Hour $targetTime.Hour -Minute $targetTime.Minute -Second 0

                return $now -ge $todayTarget -and $lastExecuted.Date -lt $now.Date
            }

            "Weekly" {
                $dayOfWeek = $schedule.DayOfWeek
                $targetTime = [datetime]$schedule.Time

                return $now.DayOfWeek -eq $dayOfWeek -and
                       $now.Hour -eq $targetTime.Hour -and
                       $now.Minute -eq $targetTime.Minute -and
                       ($now - $lastExecuted).TotalDays -ge 7
            }

            default {
                return $false
            }
        }
        return $false
    }

    [void]ExecuteRule([string]$ruleId) {
        if ($this.Rules.ContainsKey($ruleId)) {
            $rule = $this.Rules[$ruleId]

            if (-not $rule.IsEnabled) {
                Write-AgentLog "Rule is disabled: $($rule.Name)" -Level Warning
                return
            }

            try {
                $context = @{
                    TriggerType = "Manual"
                    Timestamp = Get-Date
                    RuleId = $ruleId
                }

                $rule.ExecuteActions($context)
                Write-AgentLog "Manually executed rule: $($rule.Name)" -Level Info
            }
            catch {
                Write-AgentLog "Failed to execute rule $($rule.Name): $($_.Exception.Message)" -Level Error
            }
        } else {
            Write-AgentLog "Rule not found: $ruleId" -Level Error
        }
    }

    [array]GetRules() {
        return $this.Rules.Values | ForEach-Object {
            @{
                Id = $_.Id
                Name = $_.Name
                Description = $_.Description
                TriggerType = $_.TriggerType
                IsEnabled = $_.IsEnabled
                LastExecuted = $_.LastExecuted
                ExecutionCount = $_.ExecutionCount
                Status = $_.Status
            }
        }
    }

    [hashtable]GetRuleDetails([string]$ruleId) {
        if ($this.Rules.ContainsKey($ruleId)) {
            $rule = $this.Rules[$ruleId]
            return @{
                Id = $rule.Id
                Name = $rule.Name
                Description = $rule.Description
                TriggerType = $rule.TriggerType
                TriggerConfig = $rule.TriggerConfig
                Conditions = $rule.Conditions
                Actions = $rule.Actions
                IsEnabled = $rule.IsEnabled
                LastExecuted = $rule.LastExecuted
                ExecutionCount = $rule.ExecutionCount
                Status = $rule.Status
            }
        }
        return @{}
    }

    [hashtable]GetStatus() {
        return @{
            IsRunning = $this.IsRunning
            RuleCount = $this.Rules.Count
            EnabledRuleCount = ($this.Rules.Values | Where-Object { $_.IsEnabled }).Count
            TotalExecutions = ($this.Rules.Values | Measure-Object ExecutionCount -Sum).Sum
        }
    }
}

# Module functions
## Use script-scoped AutomationEngine instance with fallback to global for backward compatibility
if (-not $Script:AutomationEngine) { if ($Global:AutomationEngine) { $Script:AutomationEngine = $Global:AutomationEngine } else { $Script:AutomationEngine = $null } }

function Start-AutomationEngine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if ($Script:AutomationEngine -and $Script:AutomationEngine.IsRunning) {
        Write-AgentLog "Automation engine is already running" -Level Warning
        return
    }

    if (-not $PSCmdlet.ShouldProcess('AutomationEngine','Start')) { return $false }

    if (-not $Script:AutomationEngine) { $Script:AutomationEngine = [AutomationEngine]::new() }
    return $Script:AutomationEngine.Start()
}

function Stop-AutomationEngine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if (-not $Script:AutomationEngine) { return }
    if (-not $PSCmdlet.ShouldProcess('AutomationEngine','Stop')) { return }

    $Script:AutomationEngine.Stop()
}

function Invoke-AutomationTrigger {
    param(
        [string]$TriggerType,
        [hashtable]$Context
    )

    if ($Script:AutomationEngine -and $Script:AutomationEngine.IsRunning) {
        $Script:AutomationEngine.ProcessTrigger($TriggerType, $Context)
    }
}

function Invoke-AutomationRule {
    param([string]$RuleId)

    if ($Script:AutomationEngine) {
        $Script:AutomationEngine.ExecuteRule($RuleId)
    }
}

function Get-AutomationRules {
    if ($Script:AutomationEngine) {
        return $Script:AutomationEngine.GetRules()
    }
    return @()
}

function Get-AutomationRule {
    param([string]$RuleId)

    if ($Script:AutomationEngine) {
        return $Script:AutomationEngine.GetRuleDetails($RuleId)
    }
    return @{}
}

function Get-AutomationStatus {
    if ($Script:AutomationEngine) {
        return $Script:AutomationEngine.GetStatus()
    }
    return @{ IsRunning = $false }
}

# Convenience functions for common triggers
function Invoke-DeviceAutomation {
    param(
        [string]$EventType,
        [hashtable]$Device
    )

    $context = @{
        TriggerType = "Device"
        EventType = $EventType
        Device = $Device
        Timestamp = Get-Date
    }

    Invoke-AutomationTrigger -TriggerType "Device" -Context $context
}

function Invoke-SoftwareAutomation {
    param(
        [string]$EventType,
        [hashtable]$Software
    )

    $context = @{
        TriggerType = "Software"
        EventType = $EventType
        Software = $Software
        Timestamp = Get-Date
    }

    Invoke-AutomationTrigger -TriggerType "Software" -Context $context
}

# Export module members
try {
    Export-ModuleMember -Function * -ErrorAction Stop
} catch {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}



