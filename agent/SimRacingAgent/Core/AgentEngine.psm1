# SimRacing Agent Core Engine
# Main agent orchestration and lifecycle management

using module ..\Utils\Logging.psm1

class AgentEngine {
    [string]$Version
    [string]$InstanceId
    [hashtable]$Config
    [bool]$IsRunning
    [System.Collections.ArrayList]$Modules
    [System.Timers.Timer]$HealthTimer

    AgentEngine() {
        $this.Version = "1.0.0"
        $this.InstanceId = [System.Guid]::NewGuid().ToString()
        $this.IsRunning = $false
        $this.Modules = @()
        $this.LoadConfiguration()
    }

    [void]LoadConfiguration() {
        try {
            $configPath = Join-Path $PSScriptRoot "..\Utils\agent-config.json"
            if (Test-Path $configPath) {
                $configContent = Get-Content $configPath | ConvertFrom-Json
                $this.Config = @{}
                $configContent.PSObject.Properties | ForEach-Object {
                    $this.Config[$_.Name] = $_.Value
                }
            } else {
                Write-AgentWarning "Configuration file not found: $configPath" -Source "AgentEngine"
                $this.CreateDefaultConfig()
            }
        }
        catch {
            Write-AgentError "Failed to load configuration: $($_.Exception.Message)" -Source "AgentEngine"
            $this.CreateDefaultConfig()
        }
    }

    [void]CreateDefaultConfig() {
        $this.Config = @{
            Agent = @{
                Name = "SimRacingAgent"
                Version = $this.Version
                InstanceId = $this.InstanceId
            }
            Modules = @{
                DeviceMonitor = @{ Enabled = $true }
                SoftwareManager = @{ Enabled = $true }
                AutomationEngine = @{ Enabled = $true }
                HealthMonitor = @{ Enabled = $true }
            }
        }
        Write-AgentInfo "Created default configuration" -Source "AgentEngine"
    }

    [bool]Start() {
        try {
            if ($this.IsRunning) {
                Write-AgentWarning "Agent engine is already running" -Source "AgentEngine"
                return $true
            }

            Write-AgentInfo "Starting agent engine v$($this.Version)" -Source "AgentEngine"

            # Start health timer
            $this.HealthTimer = New-Object System.Timers.Timer(30000) # 30 seconds
            $this.HealthTimer.AutoReset = $true

            Register-ObjectEvent -InputObject $this.HealthTimer -EventName Elapsed -Action {
                try {
                    [AgentEngine]$engine = $Event.MessageData
                    $engine.PerformHealthCheck()
                }
                catch {
                    Write-AgentError "Health check error: $($_.Exception.Message)" -Source "AgentEngine"
                }
            } -MessageData $this | Out-Null

            $this.HealthTimer.Start()
            $this.IsRunning = $true

            Write-AgentInfo "Agent engine started successfully" -Source "AgentEngine"
            return $true
        }
        catch {
            Write-AgentError "Failed to start agent engine: $($_.Exception.Message)" -Source "AgentEngine"
            return $false
        }
    }

    [void]Stop() {
        try {
            if (-not $this.IsRunning) {
                return
            }

            Write-AgentInfo "Stopping agent engine" -Source "AgentEngine"

            if ($this.HealthTimer) {
                $this.HealthTimer.Stop()
                $this.HealthTimer.Dispose()
            }

            $this.IsRunning = $false
            Write-AgentInfo "Agent engine stopped" -Source "AgentEngine"
        }
        catch {
            Write-AgentError "Error stopping agent engine: $($_.Exception.Message)" -Source "AgentEngine"
        }
    }

    [void]PerformHealthCheck() {
        try {
            Write-AgentDebug "Performing health check" -Source "AgentEngine"
            # Basic health check - can be expanded
        }
        catch {
            Write-AgentError "Health check failed: $($_.Exception.Message)" -Source "AgentEngine"
        }
    }

    [hashtable]GetStatus() {
        return @{
            Version = $this.Version
            InstanceId = $this.InstanceId
            IsRunning = $this.IsRunning
            ModuleCount = $this.Modules.Count
        }
    }
}

# Module functions
function Start-AgentEngine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if ($Script:AgentEngineInstance -and $Script:AgentEngineInstance.IsRunning) {
        Write-AgentWarning "Agent engine is already running" -Source "AgentEngine"
        return $true
    }

    if (-not $PSCmdlet.ShouldProcess('AgentEngine', 'Start')) {
        return $false
    }

    if (-not $Script:AgentEngineInstance) {
        $Script:AgentEngineInstance = [AgentEngine]::new()
    }

    return $Script:AgentEngineInstance.Start()
}

function Stop-AgentEngine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if (-not $Script:AgentEngineInstance) { return }

    if (-not $PSCmdlet.ShouldProcess('AgentEngine', 'Stop')) { return }

    $Script:AgentEngineInstance.Stop()
}

function Get-AgentEngineStatus {
    if ($Script:AgentEngineInstance) {
        return $Script:AgentEngineInstance.GetStatus()
    }
    return @{ IsRunning = $false }
}

try {
    Export-ModuleMember -Function Start-AgentEngine, Stop-AgentEngine, Get-AgentEngineStatus -ErrorAction Stop
} catch {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}



