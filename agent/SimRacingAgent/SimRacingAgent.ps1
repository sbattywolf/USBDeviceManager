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

# Global variables
$Global:AgentInfo = @{
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

# Import utility modules first
try {
    Import-Module (Join-Path $UtilsPath "Logging.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $UtilsPath "Configuration.psm1") -Force -ErrorAction Stop
}
catch {
    Write-Host "FATAL: Failed to load utility modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Initialize logging with console output
Set-AgentLogOutputs -Console $true -File $true -Dashboard $false
Set-AgentLogLevel -Level $LogLevel

Write-AgentInfo "Starting SimRacing Agent v$($Global:AgentInfo.Version)" -Source "Startup"
Write-AgentInfo "Agent ID: $($Global:AgentInfo.Id)" -Source "Startup"

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
    try {
        Write-AgentInfo "Starting agent services..." -Source "Services"
        
        # Initialize dashboard client
        $dashboardUrl = Get-AgentConfiguration -Path "Dashboard.Url" -Default "http://localhost:5000"
        $dashboardConnected = Initialize-DashboardClient -BaseUrl $dashboardUrl
        
        if ($dashboardConnected) {
            Write-AgentInfo "Connected to dashboard at: $dashboardUrl" -Source "Services"
            
            # Register agent with dashboard
            $registrationResult = Register-Agent -AgentInfo $Global:AgentInfo
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
            Set-AgentLogOutputs -Console $true -File $true -Dashboard $true
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
    try {
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
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                SimRacing Agent Interactive Mode            " -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Green
    Write-Host "  S - Show Status      D - Show Devices      A - Show Automation" -ForegroundColor White
    Write-Host "  H - Show Health      L - Show Logs         C - Show Config" -ForegroundColor White
    Write-Host "  R - Reload Config    T - Test Dashboard    Q - Quit" -ForegroundColor White
    Write-Host ""
    
    $continue = $true
    while ($continue) {
        try {
            Write-Host "Agent> " -NoNewline -ForegroundColor Yellow
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
                    Write-Host "Reloading configuration..." -ForegroundColor Yellow
                    Reset-AgentConfiguration
                    Write-Host "Configuration reloaded" -ForegroundColor Green
                }
                "T" {
                    Write-Host "Testing dashboard connection..." -ForegroundColor Yellow
                    $connected = Test-DashboardConnection
                    if ($connected) {
                        Write-Host "Dashboard connection: OK" -ForegroundColor Green
                    } else {
                        Write-Host "Dashboard connection: FAILED" -ForegroundColor Red
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
                    Write-Host "Unknown command: $userInput (try 'Q' to quit)" -ForegroundColor Red
                }
            }
        }
        catch {
            Write-AgentError "Interactive mode error: $($_.Exception.Message)" -Source "Interactive"
        }
    }
}

function Show-AgentStatus {
    Write-Host ""
    Write-Host "Agent Status:" -ForegroundColor Green
    Write-Host "  Name: $($Global:AgentInfo.Name)" -ForegroundColor White
    Write-Host "  Version: $($Global:AgentInfo.Version)" -ForegroundColor White
    Write-Host "  ID: $($Global:AgentInfo.Id)" -ForegroundColor White
    Write-Host "  Start Time: $($Global:AgentInfo.StartTime)" -ForegroundColor White
    Write-Host "  Uptime: $((Get-Date) - $Global:AgentInfo.StartTime)" -ForegroundColor White
    
    $configStatus = Get-ConfigurationStatus
    Write-Host "  Configuration: $($configStatus.ConfigPath)" -ForegroundColor White
    
    $dashboardStatus = Get-DashboardClientStatus
    Write-Host "  Dashboard: $($dashboardStatus.BaseUrl) [$($dashboardStatus.IsConnected)]" -ForegroundColor White
    
    Write-Host ""
}

function Show-DeviceStatus {
    Write-Host ""
    Write-Host "Device Status:" -ForegroundColor Green
    
    if (Get-Command "Get-DeviceMonitoringStatus" -ErrorAction SilentlyContinue) {
        $deviceStatus = Get-DeviceMonitoringStatus
        Write-Host "  Monitoring: $($deviceStatus.IsMonitoring)" -ForegroundColor White
        Write-Host "  Connected Devices: $($deviceStatus.ConnectedDeviceCount)" -ForegroundColor White
        Write-Host "  Racing Devices: $($deviceStatus.RacingDeviceCount)" -ForegroundColor White
        Write-Host "  History Entries: $($deviceStatus.HistoryEntryCount)" -ForegroundColor White
    } else {
        Write-Host "  Device monitoring not available" -ForegroundColor Yellow
    }
    
    if (Get-Command "Get-ConnectedDevices" -ErrorAction SilentlyContinue) {
        $devices = Get-ConnectedDevices
        if ($devices -and $devices.Count -gt 0) {
            Write-Host "  Recent Devices:" -ForegroundColor Yellow
            $devices | Select-Object -First 5 | ForEach-Object {
                Write-Host "    $($_.Name) [$($_.DeviceId)]" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host ""
}

function Show-AutomationStatus {
    Write-Host ""
    Write-Host "Automation Status:" -ForegroundColor Green
    
    if (Get-Command "Get-AutomationStatus" -ErrorAction SilentlyContinue) {
        $automationStatus = Get-AutomationStatus
        Write-Host "  Engine Running: $($automationStatus.IsRunning)" -ForegroundColor White
        Write-Host "  Total Rules: $($automationStatus.RuleCount)" -ForegroundColor White
        Write-Host "  Enabled Rules: $($automationStatus.EnabledRuleCount)" -ForegroundColor White
        Write-Host "  Total Executions: $($automationStatus.TotalExecutions)" -ForegroundColor White
        
        if (Get-Command "Get-AutomationRules" -ErrorAction SilentlyContinue) {
            $rules = Get-AutomationRules
            if ($rules -and $rules.Count -gt 0) {
                Write-Host "  Rules:" -ForegroundColor Yellow
                $rules | ForEach-Object {
                    $status = if ($_.IsEnabled) { "Enabled" } else { "Disabled" }
                    Write-Host "    $($_.Name) [$status] - Executions: $($_.ExecutionCount)" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "  Automation engine not available" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Show-HealthStatus {
    Write-Host ""
    Write-Host "Health Status:" -ForegroundColor Green
    
    if (Get-Command "Get-HealthStatus" -ErrorAction SilentlyContinue) {
        $healthStatus = Get-HealthStatus
        Write-Host "  Monitoring: $($healthStatus.IsMonitoring)" -ForegroundColor White
        Write-Host "  Overall Health: $($healthStatus.OverallHealth)" -ForegroundColor White
        Write-Host "  Health Score: $($healthStatus.HealthScore)" -ForegroundColor White
        
        if (Get-Command "Get-CurrentHealthMetrics" -ErrorAction SilentlyContinue) {
            $metrics = Get-CurrentHealthMetrics
            if ($metrics) {
                Write-Host "  System Metrics:" -ForegroundColor Yellow
                Write-Host "    CPU Usage: $($metrics.System.CPU.Usage)%" -ForegroundColor Gray
                Write-Host "    Memory Usage: $($metrics.System.Memory.Usage)%" -ForegroundColor Gray
                Write-Host "    Uptime: $($metrics.System.Uptime.TotalHours) hours" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  Health monitoring not available" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Show-RecentLogs {
    Write-Host ""
    Write-Host "Recent Logs (last 10):" -ForegroundColor Green
    
    $logBuffer = Get-AgentLogBuffer
    if ($logBuffer -and $logBuffer.Count -gt 0) {
        $logBuffer | Select-Object -Last 10 | ForEach-Object {
            $color = switch ($_.Level) {
                "Error" { "Red" }
                "Warning" { "Yellow" }
                "Info" { "White" }
                default { "Gray" }
            }
            Write-Host "  [$($_.Timestamp)] [$($_.Level)] $($_.Message)" -ForegroundColor $color
        }
    } else {
        Write-Host "  No recent logs available" -ForegroundColor Gray
    }
    
    Write-Host ""
}

function Show-Configuration {
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Green
    
    $config = Get-AgentConfiguration
    $sections = @("Agent", "Dashboard", "DeviceMonitoring", "SoftwareManagement", "Automation", "HealthMonitoring")
    
    foreach ($section in $sections) {
        if ($config.ContainsKey($section)) {
            Write-Host "  ${section}:" -ForegroundColor Yellow
            $sectionData = $config[$section]
            foreach ($key in $sectionData.Keys) {
                Write-Host "    ${key}: $($sectionData[$key])" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host ""
}

function Show-Help {
    Write-Host ""
    Write-Host "SimRacing Agent Help:" -ForegroundColor Green
    Write-Host ""
    Write-Host "This agent monitors USB devices, manages software, and provides" -ForegroundColor White
    Write-Host "automation capabilities for SimRacing setups." -ForegroundColor White
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Yellow
    Write-Host "  • USB device monitoring and event detection" -ForegroundColor White
    Write-Host "  • Software lifecycle management" -ForegroundColor White
    Write-Host "  • Rule-based automation engine" -ForegroundColor White
    Write-Host "  • System health monitoring" -ForegroundColor White
    Write-Host "  • Dashboard integration" -ForegroundColor White
    Write-Host ""
    Write-Host "Configuration file: $((Get-ConfigurationStatus).ConfigPath)" -ForegroundColor Gray
    Write-Host "Dashboard URL: $((Get-DashboardClientStatus).BaseUrl)" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
try {
    # Initialize agent
    $initialized = Initialize-Agent -ConfigPath $ConfigPath -DashboardUrl $DashboardUrl
    if (-not $initialized) {
        Write-Host "Failed to initialize agent. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Start services
    $servicesStarted = Start-AgentServices
    if (-not $servicesStarted) {
        Write-Host "Failed to start services. Exiting." -ForegroundColor Red
        exit 1
    }
    
    Write-AgentInfo "SimRacing Agent started successfully" -Source "Main"
    Write-AgentInfo "Agent ID: $($Global:AgentInfo.Id)" -Source "Main"
    
    # Send initial heartbeat
    try {
        Send-AgentHeartbeat -AgentId $Global:AgentInfo.Id | Out-Null
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
                    Send-AgentHeartbeat -AgentId $Global:AgentInfo.Id | Out-Null
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
    Write-AgentInfo "SimRacing Agent stopped" -Source "Shutdown"
}