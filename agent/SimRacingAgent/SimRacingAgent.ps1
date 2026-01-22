#!/usr/bin/env pwsh

<#
.SYNOPSIS
    SimRacing Agent - USB device monitoring and automation system
.DESCRIPTION
    Monitors USB devices, manages software lifecycle, and provides automation
    capabilities for SimRacing setups. Integrates with SimRacing Dashboard.
.PARAMETER ConfigPath
    Path to configuration file (default: agent-config.json)
.PARAMETER DashboardUrl
    URL of the SimRacing Dashboard (default: http://localhost:5000)
.PARAMETER LogLevel
    Logging level: Trace, Debug, Info, Warning, Error, Critical (default: Info)
.PARAMETER Service
    Run as a background service
.EXAMPLE
    .\SimRacingAgent.ps1 -DashboardUrl "http://dashboard.local:5000" -LogLevel Debug
#>

param(
    [string]$ConfigPath = "",
    [string]$DashboardUrl = "http://localhost:5000",
    [string]$LogLevel = "Info",
    [switch]$Service = $false
)

# Set script location and module paths
$ScriptPath = $PSScriptRoot
$ModulesPath = Join-Path $ScriptPath "Modules"
$ServicesPath = Join-Path $ScriptPath "Services"
$UtilsPath = Join-Path $ScriptPath "Utils"
$CorePath = Join-Path $ScriptPath "Core"

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Initialize error handling
$ErrorActionPreference = "Stop"

# Module-scoped agent info to avoid global state in normal runs
$Script:AgentInfo = @{
    Name = "SimRacingAgent"
    Version = "1.0.0"
    Id = [System.Guid]::NewGuid().ToString()
    Hostname = $env:COMPUTERNAME
    Platform = "Windows PowerShell"
    StartTime = Get-Date
    ProcessId = $PID
    Capabilities = @(
        "USB Monitoring",
        "Software Management",
        "Health Monitoring",
        "Automation Engine"
    )
}

# Single-instance enforcement: named mutex to ensure only one agent runs per host
try {
    $mutexName = "Global\SimRacingAgent_$($Script:AgentInfo.Hostname)"
    $createdNew = $false
    $Script:AgentMutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
    if (-not $createdNew) {
        Write-Output "Another SimRacingAgent instance is already running on this host. Exiting." | Out-String | Write-Host
        Write-AgentError "Another SimRacingAgent instance is already running on this host. Exiting." -Source "Startup"
        exit 2
    }
    else {
        Write-AgentInfo "Acquired single-instance mutex: $mutexName" -Source "Startup"
    }
}
catch {
    Write-AgentWarning "Failed to acquire single-instance mutex: $($_.Exception.Message)" -Source "Startup"
}

# Import utility modules first
try {
    Import-Module (Join-Path $UtilsPath "Logging.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $UtilsPath "Configuration.psm1") -Force -ErrorAction Stop
}
catch {
    Write-AgentError "FATAL: Failed to load utility modules: $($_.Exception.Message)" -Source "Startup"
    exit 1
}

# Initialize logging with console output
Set-AgentLogOutput -Console $true -File $true -Dashboard $false
Set-AgentLogLevel -Level $LogLevel

Write-AgentInfo "Starting SimRacing Agent v$($Script:AgentInfo.Version)" -Source "Startup"
Write-AgentInfo "Agent ID: $($Script:AgentInfo.Id)" -Source "Startup"

function Initialize-Agent {
    param(
        [string]$ConfigPath,
        [string]$DashboardUrl
    )

    try {
        Write-AgentInfo "Initializing SimRacing Agent..." -Source "Init"

        # Initialize configuration
        if ($ConfigPath) {
            $configInitialized = Initialize-Configuration -ConfigPath $ConfigPath
        } else {
            $configPath = Join-Path $UtilsPath "agent-config.json"
            $configInitialized = Initialize-Configuration -ConfigPath $configPath
        }

        if (-not $configInitialized) {
            Write-AgentWarning "Using default configuration" -Source "Init"
        }

        # Update dashboard URL from parameter
        if ($DashboardUrl -ne "http://localhost:5000") {
            Set-AgentConfiguration -Path "Dashboard.Url" -Value $DashboardUrl
        }

        # Import core modules
        Write-AgentInfo "Loading core modules..." -Source "Init"
        Import-Module (Join-Path $CorePath "AgentEngine.psm1") -Force

        # Import feature modules
        Write-AgentInfo "Loading feature modules..." -Source "Init"
        Import-Module (Join-Path $ModulesPath "DeviceMonitor.psm1") -Force
        Import-Module (Join-Path $ModulesPath "SoftwareManager.psm1") -Force
        Import-Module (Join-Path $ModulesPath "AutomationEngine.psm1") -Force

        # Import service modules
        Write-AgentInfo "Loading service modules..." -Source "Init"
        Import-Module (Join-Path $ServicesPath "HealthMonitor.psm1") -Force
        Import-Module (Join-Path $ServicesPath "DashboardClient.psm1") -Force

        Write-AgentInfo "All modules loaded successfully" -Source "Init"
        return $true
    }
    catch {
        Write-AgentError "Failed to initialize agent: $($_.Exception.Message)" -Source "Init"
        Write-AgentException -Exception $_.Exception -Context "Agent Initialization"
        return $false
    }
}

function Start-AgentServices {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    try {
        if (-not $PSCmdlet.ShouldProcess('Agent','StartServices')) { return $false }
        Write-AgentInfo "Starting agent services..." -Source "Services"

        # Initialize dashboard client
        $dashboardUrl = Get-AgentConfiguration -Path "Dashboard.Url" -Default "http://localhost:5000"
        $dashboardConnected = Initialize-DashboardClient -BaseUrl $dashboardUrl

        if ($dashboardConnected) {
            Write-AgentInfo "Connected to dashboard at: $dashboardUrl" -Source "Services"

            # Register agent with dashboard
            $registrationResult = Register-Agent -AgentInfo $Script:AgentInfo
            if ($registrationResult.Success) {
                Write-AgentInfo "Agent registered with dashboard successfully" -Source "Services"
            }
        } else {
            Write-AgentWarning "Could not connect to dashboard at: $dashboardUrl" -Source "Services"
        }

        # Start device monitoring if enabled
        $deviceConfig = Get-DeviceConfig
        if ($deviceConfig.Enabled) {
            $interval = $deviceConfig.ScanInterval
            Start-DeviceMonitoring -IntervalSeconds $interval
            Write-AgentInfo "Device monitoring started (interval: ${interval}s)" -Source "Services"
        }

        # Start software monitoring if enabled
        $softwareConfig = Get-SoftwareConfig
        if ($softwareConfig.Enabled) {
            $interval = $softwareConfig.MonitorInterval
            Start-SoftwareMonitoring -IntervalSeconds $interval
            Write-AgentInfo "Software monitoring started (interval: ${interval}s)" -Source "Services"
        }

        # Start automation engine if enabled
        $automationConfig = Get-AutomationConfig
        if ($automationConfig.Enabled) {
            Start-AutomationEngine
            Write-AgentInfo "Automation engine started" -Source "Services"
        }

        # Start health monitoring if enabled
        $healthConfig = Get-HealthConfig
        if ($healthConfig.Enabled) {
            $interval = $healthConfig.MonitorInterval
            Start-HealthMonitoring -IntervalSeconds $interval -DashboardUrl $dashboardUrl
            Write-AgentInfo "Health monitoring started (interval: ${interval}s)" -Source "Services"
        }

        # Enable dashboard logging if connected
        if ($dashboardConnected) {
            Set-AgentLogOutput -Console $true -File $true -Dashboard $true
        }

        Write-AgentInfo "All services started successfully" -Source "Services"
        return $true
    }
    catch {
        Write-AgentError "Failed to start services: $($_.Exception.Message)" -Source "Services"
        Write-AgentException -Exception $_.Exception -Context "Service Startup"
        return $false
    }
}

function Stop-AgentServices {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    try {
        if (-not $PSCmdlet.ShouldProcess('Agent','StopServices')) { return }
        Write-AgentInfo "Stopping agent services..." -Source "Shutdown"

        # Stop monitoring services with safe checks
        if (Get-Command "Stop-DeviceMonitoring" -ErrorAction SilentlyContinue) {
            Stop-DeviceMonitoring
        }

        if (Get-Command "Stop-SoftwareMonitoring" -ErrorAction SilentlyContinue) {
            Stop-SoftwareMonitoring
        }

        if (Get-Command "Stop-AutomationEngine" -ErrorAction SilentlyContinue) {
            Stop-AutomationEngine
        }

        if (Get-Command "Stop-HealthMonitoring" -ErrorAction SilentlyContinue) {
            Stop-HealthMonitoring
        }

        Write-AgentInfo "Agent services stopped" -Source "Shutdown"
    }
    catch {
        Write-AgentError "Error stopping services: $($_.Exception.Message)" -Source "Shutdown"
    }
}

function Start-InteractiveMode {
    Write-Output ""
    Write-Output "══════════════════════════════════════════════════════════="
    Write-Output "                SimRacing Agent Interactive Mode            "
    Write-Output "══════════════════════════════════════════════════════════="
    Write-Output ""
    Write-Output "Commands:"
    Write-Output "  S - Show Status      D - Show Devices      A - Show Automation"
    Write-Output "  H - Show Health      L - Show Logs         C - Show Config"
    Write-Output "  R - Reload Config    T - Test Dashboard    Q - Quit"
    Write-Output ""

    $continue = $true
    while ($continue) {
        try {
            [System.Console]::Write('Agent> ')
            $userInput = Read-Host

            switch ($userInput.ToUpper()) {
                "S" {
                    Show-AgentStatus
                }
                "D" {
                    Show-DeviceStatus
                }
                "A" {
                    Show-AutomationStatus
                }
                "H" {
                    Show-HealthStatus
                }
                "L" {
                    Show-RecentLogs
                }
                "C" {
                    Show-Configuration
                }
                    "R" {
                    Write-AgentInfo "Reloading configuration..." -Source "Interactive"
                    Reset-AgentConfiguration
                    Write-AgentInfo "Configuration reloaded" -Source "Interactive"
                }
                    "T" {
                    Write-AgentInfo "Testing dashboard connection..." -Source "Interactive"
                    $connected = Test-DashboardConnection
                    if ($connected) {
                        Write-AgentInfo "Dashboard connection: OK" -Source "Interactive"
                    } else {
                        Write-AgentError "Dashboard connection: FAILED" -Source "Interactive"
                    }
                }
                "Q" {
                    $continue = $false
                }
                "HELP" {
                    Show-Help
                }
                "" {
                    # Empty input, continue
                }
                    default {
                    Write-AgentWarning "Unknown command: $userInput (try 'Q' to quit)" -Source "Interactive"
                }
            }
        }
        catch {
            Write-AgentError "Interactive mode error: $($_.Exception.Message)" -Source "Interactive"
        }
    }
}

function Show-AgentStatus {
    Write-Output ""
    Write-Output "Agent Status:"
    Write-Output "  Name: $($Script:AgentInfo.Name)"
    Write-Output "  Version: $($Script:AgentInfo.Version)"
    Write-Output "  ID: $($Script:AgentInfo.Id)"
    Write-Output "  Start Time: $($Script:AgentInfo.StartTime)"
    Write-Output "  Uptime: $((Get-Date) - $Script:AgentInfo.StartTime)"

    $configStatus = Get-ConfigurationStatus
    Write-Output "  Configuration: $($configStatus.ConfigPath)"

    $dashboardStatus = Get-DashboardClientStatus
    Write-Output "  Dashboard: $($dashboardStatus.BaseUrl) [$($dashboardStatus.IsConnected)]"

    Write-Output ""
}

function Show-DeviceStatus {
    Write-Output ""
    Write-Output "Device Status:"

    if (Get-Command "Get-DeviceMonitoringStatus" -ErrorAction SilentlyContinue) {
        $deviceStatus = Get-DeviceMonitoringStatus
        Write-Output "  Monitoring: $($deviceStatus.IsMonitoring)"
        Write-Output "  Connected Devices: $($deviceStatus.ConnectedDeviceCount)"
        Write-Output "  Racing Devices: $($deviceStatus.RacingDeviceCount)"
        Write-Output "  History Entries: $($deviceStatus.HistoryEntryCount)"
    } else {
        Write-Warning "  Device monitoring not available"
    }

    if (Get-Command "Get-ConnectedDevices" -ErrorAction SilentlyContinue) {
        $devices = Get-ConnectedDevices
        if ($devices -and $devices.Count -gt 0) {
            Write-Warning "  Recent Devices:"
            $devices | Select-Object -First 5 | ForEach-Object {
                Write-Output "    $($_.Name) [$($_.DeviceId)]"
            }
        }
    }

    Write-Output ""
}

function Show-AutomationStatus {
    Write-Output ""
    Write-Output "Automation Status:"

    if (Get-Command "Get-AutomationStatus" -ErrorAction SilentlyContinue) {
        $automationStatus = Get-AutomationStatus
        Write-Output "  Engine Running: $($automationStatus.IsRunning)"
        Write-Output "  Total Rules: $($automationStatus.RuleCount)"
        Write-Output "  Enabled Rules: $($automationStatus.EnabledRuleCount)"
        Write-Output "  Total Executions: $($automationStatus.TotalExecutions)"

        if (Get-Command "Get-AutomationRules" -ErrorAction SilentlyContinue) {
            $rules = Get-AutomationRules
            if ($rules -and $rules.Count -gt 0) {
                Write-Warning "  Rules:"
                $rules | ForEach-Object {
                    $status = if ($_.IsEnabled) { "Enabled" } else { "Disabled" }
                    Write-Output "    $($_.Name) [$status] - Executions: $($_.ExecutionCount)"
                }
            }
        }
    } else {
        Write-Warning "  Automation engine not available"
    }

    Write-Output ""
}

function Show-HealthStatus {
    Write-Output ""
    Write-Output "Health Status:"

    if (Get-Command "Get-HealthStatus" -ErrorAction SilentlyContinue) {
        $healthStatus = Get-HealthStatus
        Write-Output "  Monitoring: $($healthStatus.IsMonitoring)"
        Write-Output "  Overall Health: $($healthStatus.OverallHealth)"
        Write-Output "  Health Score: $($healthStatus.HealthScore)"

        if (Get-Command "Get-CurrentHealthMetrics" -ErrorAction SilentlyContinue) {
            $metrics = Get-CurrentHealthMetrics
            if ($metrics) {
                Write-Warning "  System Metrics:"
                Write-Output "    CPU Usage: $($metrics.System.CPU.Usage)%"
                Write-Output "    Memory Usage: $($metrics.System.Memory.Usage)%"
                Write-Output "    Uptime: $($metrics.System.Uptime.TotalHours) hours"
            }
        }
    } else {
        Write-Warning "  Health monitoring not available"
    }

    Write-Output ""
}

function Show-RecentLogs {
    Write-Output ""
    Write-Output "Recent Logs (last 10):"

    $logBuffer = Get-AgentLogBuffer
    if ($logBuffer -and $logBuffer.Count -gt 0) {
        $logBuffer | Select-Object -Last 10 | ForEach-Object {
            $entry = "  [$($_.Timestamp)] [$($_.Level)] $($_.Message)"
            switch ($_.Level) {
                "Error" { Write-Error $entry }
                "Warning" { Write-Warning $entry }
                default { Write-Output $entry }
            }
        }
    } else {
        Write-Output "  No recent logs available"
    }

    Write-Output ""
}

function Show-Configuration {
    Write-Output ""
    Write-Output "Configuration:"

    $config = Get-AgentConfiguration
    $sections = @("Agent", "Dashboard", "DeviceMonitoring", "SoftwareManagement", "Automation", "HealthMonitoring")

    foreach ($section in $sections) {
        if ($config.ContainsKey($section)) {
            Write-Warning "  ${section}:"
            $sectionData = $config[$section]
            foreach ($key in $sectionData.Keys) {
                Write-Output "    ${key}: $($sectionData[$key])"
            }
        }
    }

    Write-Output ""
}

function Show-Help {
    Write-Output ""
    Write-Output "SimRacing Agent Help:"
    Write-Output ""
    Write-Output "This agent monitors USB devices, manages software, and provides"
    Write-Output "automation capabilities for SimRacing setups."
    Write-Output ""
    Write-Warning "Features:"
    Write-Output "  • USB device monitoring and event detection"
    Write-Output "  • Software lifecycle management"
    Write-Output "  • Rule-based automation engine"
    Write-Output "  • System health monitoring"
    Write-Output "  • Dashboard integration"
    Write-Output ""
    Write-Output "Configuration file: $((Get-ConfigurationStatus).ConfigPath)"
    Write-Output "Dashboard URL: $((Get-DashboardClientStatus).BaseUrl)"
    Write-Output ""
}

# Main execution
try {
    # Initialize agent
    $initialized = Initialize-Agent -ConfigPath $ConfigPath -DashboardUrl $DashboardUrl
    if (-not $initialized) {
        Write-AgentError "Failed to initialize agent. Exiting." -Source "Startup"
        exit 1
    }

    # Start services
    $servicesStarted = Start-AgentServices
    if (-not $servicesStarted) {
        Write-AgentError "Failed to start services. Exiting." -Source "Startup"
        exit 1
    }

    Write-AgentInfo "SimRacing Agent started successfully" -Source "Main"
    Write-AgentInfo "Agent ID: $($Script:AgentInfo.Id)" -Source "Main"

    # Send initial heartbeat
    try {
        Send-AgentHeartbeat -AgentId $Script:AgentInfo.Id | Out-Null
    }
    catch {
        Write-AgentWarning "Failed to send initial heartbeat: $($_.Exception.Message)" -Source "Main"
    }

    if ($Service) {
        Write-AgentInfo "Running in service mode. Press Ctrl+C to stop." -Source "Main"

        # Service mode - run indefinitely
        try {
            while ($true) {
                Start-Sleep -Seconds 60

                # Send periodic heartbeat
                try {
                    Send-AgentHeartbeat -AgentId $Script:AgentInfo.Id | Out-Null
                }
                catch {
                    Write-AgentDebug "Heartbeat failed: $($_.Exception.Message)" -Source "Heartbeat"
                }
            }
        }
        catch {
            Write-AgentInfo "Service mode interrupted" -Source "Main"
        }
    } else {
        # Interactive mode
        Start-InteractiveMode
    }
}
catch {
    Write-AgentError "Fatal error: $($_.Exception.Message)" -Source "Main"
    Write-AgentException -Exception $_.Exception -Context "Main Execution"
}
finally {
    # Cleanup
    Write-AgentInfo "Shutting down SimRacing Agent..." -Source "Shutdown"
    Stop-AgentServices

    # Release single-instance mutex if acquired
    if ($Script:AgentMutex) {
        try {
            $Script:AgentMutex.ReleaseMutex()
            $Script:AgentMutex.Close()
            Write-AgentInfo "Released single-instance mutex" -Source "Shutdown"
        }
        catch {
            Write-AgentWarning "Failed to release mutex: $($_.Exception.Message)" -Source "Shutdown"
        }
    }

    Write-AgentInfo "SimRacing Agent stopped" -Source "Shutdown"
}



