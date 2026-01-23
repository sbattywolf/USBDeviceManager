# Configuration Management Utilities
# Centralized configuration loading and validation

using module .\Logging.psm1

class ConfigurationManager {
    [hashtable]$Configuration
    [string]$ConfigPath
    [datetime]$LastLoaded
    [bool]$IsLoaded

    ConfigurationManager([string]$ConfigPath) {
        $this.ConfigPath = $ConfigPath
        $this.Configuration = @{}
        $this.IsLoaded = $false
        $this.LoadConfiguration()
    }

    [bool]LoadConfiguration() {
        try {
            if (-not (Test-Path $this.ConfigPath)) {
                Write-AgentWarning "Configuration file not found: $($this.ConfigPath)" -Source "ConfigManager"
                $this.CreateDefaultConfiguration()
                return $false
            }

            $content = Get-Content -Path $this.ConfigPath -Raw | ConvertFrom-Json
            $this.Configuration = @{}

            # Convert PSObject to hashtable
            foreach ($property in $content.PSObject.Properties) {
                $this.Configuration[$property.Name] = $this.ConvertToHashtable($property.Value)
            }

            $this.LastLoaded = Get-Date
            $this.IsLoaded = $true

            Write-AgentInfo "Configuration loaded from: $($this.ConfigPath)" -Source "ConfigManager"
            return $true
        }
        catch {
            Write-AgentError "Failed to load configuration: $($_.Exception.Message)" -Source "ConfigManager"
            $this.CreateDefaultConfiguration()
            return $false
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

    [void]CreateDefaultConfiguration() {
        try {
            $defaultConfig = @{
                Agent = @{
                    Name = "SimRacingAgent"
                    Version = "1.0.0"
                    UpdateInterval = 30
                    MaxRetries = 3
                }
                Dashboard = @{
                    Url = "http://localhost:5000"
                    ApiKey = ""
                    Enabled = $true
                    HeartbeatInterval = 60
                }
                DeviceMonitoring = @{
                    Enabled = $true
                    ScanInterval = 5
                    NotifyOnChanges = $true
                    DeviceFilters = @()
                }
                SoftwareManagement = @{
                    Enabled = $true
                    MonitorInterval = 10
                    AutoStart = $false
                    ManagedSoftware = @()
                }
                Automation = @{
                    Enabled = $true
                    RulesFile = "automation-rules.json"
                    MaxConcurrentRules = 5
                }
                HealthMonitoring = @{
                    Enabled = $true
                    MonitorInterval = 30
                    Thresholds = @{
                        CPU = @{
                            Warning = 80
                            Critical = 95
                        }
                        Memory = @{
                            Warning = 85
                            Critical = 95
                        }
                        Disk = @{
                            Warning = 85
                            Critical = 95
                        }
                    }
                }
                Logging = @{
                    Level = "Info"
                    Console = $true
                    File = $true
                    Dashboard = $false
                    MaxLogFiles = 30
                }
            }

            $configDir = Split-Path $this.ConfigPath -Parent
            if (-not (Test-Path $configDir)) {
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            }

            $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $this.ConfigPath -Encoding UTF8
            $this.Configuration = $defaultConfig
            $this.IsLoaded = $true

            Write-AgentInfo "Created default configuration at: $($this.ConfigPath)" -Source "ConfigManager"
        }
        catch {
            Write-AgentError "Failed to create default configuration: $($_.Exception.Message)" -Source "ConfigManager"
        }
    }

    [bool]SaveConfiguration() {
        try {
            $this.Configuration | ConvertTo-Json -Depth 10 | Set-Content -Path $this.ConfigPath -Encoding UTF8
            Write-AgentInfo "Configuration saved to: $($this.ConfigPath)" -Source "ConfigManager"
            return $true
        }
        catch {
            Write-AgentError "Failed to save configuration: $($_.Exception.Message)" -Source "ConfigManager"
            return $false
        }
    }

    [object]Get([string]$Path, [object]$Default = $null) {
        try {
            $parts = $Path.Split('.')
            $current = $this.Configuration

            foreach ($part in $parts) {
                if ($current -is [hashtable] -and $current.ContainsKey($part)) {
                    $current = $current[$part]
                } else {
                    return $Default
                }
            }

            return $current
        }
        catch {
            Write-AgentWarning "Error getting configuration value '$Path': $($_.Exception.Message)" -Source "ConfigManager"
            return $Default
        }
    }

    [bool]Set([string]$Path, [object]$Value) {
        try {
            $parts = $Path.Split('.')
            $current = $this.Configuration

            # Navigate to parent
            for ($i = 0; $i -lt ($parts.Length - 1); $i++) {
                $part = $parts[$i]
                if (-not $current.ContainsKey($part)) {
                    $current[$part] = @{}
                }
                $current = $current[$part]
            }

            # Set the value
            $current[$parts[-1]] = $Value

            Write-AgentDebug "Configuration value set: $Path = $Value" -Source "ConfigManager"
            return $true
        }
        catch {
            Write-AgentError "Failed to set configuration value '$Path': $($_.Exception.Message)" -Source "ConfigManager"
            return $false
        }
    }

    [bool]Exists([string]$Path) {
        $value = $this.Get($Path, $null)
        return $null -ne $value
    }

    [hashtable]GetSection([string]$Section) {
        return $this.Get($Section, @{})
    }

    [bool]SetSection([string]$Section, [hashtable]$Values) {
        return $this.Set($Section, $Values)
    }

    [array]GetKeys([string]$Path = "") {
        try {
            $section = if ($Path) { $this.Get($Path, @{}) } else { $this.Configuration }

            if ($section -is [hashtable]) {
                return $section.Keys
            }

            return @()
        }
        catch {
            return @()
        }
    }

    [void]Reload() {
        Write-AgentInfo "Reloading configuration from: $($this.ConfigPath)" -Source "ConfigManager"
        $this.LoadConfiguration()
    }

    [hashtable]GetStatus() {
        return @{
            ConfigPath = $this.ConfigPath
            IsLoaded = $this.IsLoaded
            LastLoaded = $this.LastLoaded
            SectionCount = $this.Configuration.Keys.Count
            FileExists = Test-Path $this.ConfigPath
        }
    }

    [bool]Validate() {
        try {
            $requiredSections = @("Agent", "Dashboard", "Logging")

            foreach ($section in $requiredSections) {
                if (-not $this.Configuration.ContainsKey($section)) {
                    Write-AgentError "Missing required configuration section: $section" -Source "ConfigManager"
                    return $false
                }
            }

            # Validate specific settings
            $agentName = $this.Get("Agent.Name", "")
            if ([string]::IsNullOrEmpty($agentName)) {
                Write-AgentError "Agent.Name cannot be empty" -Source "ConfigManager"
                return $false
            }

            $dashboardUrl = $this.Get("Dashboard.Url", "")
            if ([string]::IsNullOrEmpty($dashboardUrl)) {
                Write-AgentError "Dashboard.Url cannot be empty" -Source "ConfigManager"
                return $false
            }

            Write-AgentInfo "Configuration validation passed" -Source "ConfigManager"
            return $true
        }
        catch {
            Write-AgentError "Configuration validation error: $($_.Exception.Message)" -Source "ConfigManager"
            return $false
        }
    }
}

## Prefer module-scoped ConfigManager with fallback to global for backward compatibility
if (-not $Script:ConfigManager) { if ($Global:ConfigManager) { $Script:ConfigManager = $Global:ConfigManager } else { $Script:ConfigManager = $null } }

# Module functions
function Initialize-Configuration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string]$ConfigPath)

    if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot "agent-config.json" }

    if (-not $PSCmdlet.ShouldProcess('ConfigManager','Initialize')) { return $false }

    if (-not $Script:ConfigManager) { $Script:ConfigManager = [ConfigurationManager]::new($ConfigPath) }
    # Mirror into global scope for backward compatibility
    if (-not $Global:ConfigManager) { $Global:ConfigManager = $Script:ConfigManager }
    return $Script:ConfigManager.IsLoaded
}

function Get-AgentConfiguration {
    param(
        [string]$Path = "",
        [object]$Default = $null
    )

    if (-not $Script:ConfigManager) { Initialize-Configuration }
    if ($Path) { return $Script:ConfigManager.Get($Path, $Default) } else { return $Script:ConfigManager.Configuration }
}

function Set-AgentConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$Path,
        [object]$Value
    )

    if (-not $PSCmdlet.ShouldProcess('ConfigManager','Set')) { return $false }
    if (-not $Script:ConfigManager) { Initialize-Configuration }
    return $Script:ConfigManager.Set($Path, $Value)
}

function Save-AgentConfiguration {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess('ConfigManager','Save')) { return $false }
    if ($Script:ConfigManager) { return $Script:ConfigManager.SaveConfiguration() }
    return $false
}

function Test-AgentConfiguration {
    if ($Script:ConfigManager) { return $Script:ConfigManager.Validate() }
    return $false
}

function Get-ConfigurationSection {
    param([string]$Section)

    if ($Script:ConfigManager) { return $Script:ConfigManager.GetSection($Section) }
    return @{}
}

function Set-ConfigurationSection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$Section,
        [hashtable]$Values
    )

    if (-not $PSCmdlet.ShouldProcess('ConfigManager','SetSection')) { return $false }
    if ($Script:ConfigManager) { return $Script:ConfigManager.SetSection($Section, $Values) }
    return $false
}

function Reset-AgentConfiguration {
    if ($Script:ConfigManager) { $Script:ConfigManager.Reload() }
}

function Get-ConfigurationStatus {
    if ($Script:ConfigManager) { return $Script:ConfigManager.GetStatus() }
    return @{ IsLoaded = $false }
}

function Test-ConfigurationExists {
    param([string]$Path)

    if ($Script:ConfigManager) { return $Script:ConfigManager.Exists($Path) }
    return $false
}

function Get-ConfigurationKeys {
    param([string]$Path = "")

    if ($Script:ConfigManager) { return $Script:ConfigManager.GetKeys($Path) }
    return @()
}

# Convenience functions for common configuration sections
function Get-AgentInfo {
    return Get-ConfigurationSection -Section "Agent"
}

function Get-DashboardConfig {
    return Get-ConfigurationSection -Section "Dashboard"
}

function Get-LoggingConfig {
    return Get-ConfigurationSection -Section "Logging"
}

function Get-DeviceConfig {
    return Get-ConfigurationSection -Section "DeviceMonitoring"
}

function Get-SoftwareConfig {
    return Get-ConfigurationSection -Section "SoftwareManagement"
}

function Get-AutomationConfig {
    return Get-ConfigurationSection -Section "Automation"
}

function Get-HealthConfig {
    return Get-ConfigurationSection -Section "HealthMonitoring"
}

# Export module members
try {
    Export-ModuleMember -Function Initialize-Configuration, Get-AgentConfiguration, Set-AgentConfiguration, Save-AgentConfiguration, Test-AgentConfiguration, Get-ConfigurationSection, Set-ConfigurationSection, Reset-AgentConfiguration, Get-ConfigurationStatus, Test-ConfigurationExists, Get-ConfigurationKeys, Get-AgentInfo, Get-DashboardConfig, Get-LoggingConfig, Get-DeviceConfig, Get-SoftwareConfig, Get-AutomationConfig, Get-HealthConfig -ErrorAction Stop
} catch {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}



