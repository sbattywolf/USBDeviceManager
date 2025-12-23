# Adapter stubs to provide functions expected by legacy tests

function ConvertTo-HashtableRecursive {
    param($obj)
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        $ht = @{}
        foreach ($p in $obj.PSObject.Properties) {
            $ht[$p.Name] = ConvertTo-HashtableRecursive $p.Value
        }
        return $ht
    }
    elseif ($obj -is [System.Array]) {
        return @($obj | ForEach-Object { ConvertTo-HashtableRecursive $_ })
    }
    else { return $obj }
}

function Get-DefaultConfiguration {
    # Try to load actual agent config if available and convert to hashtable
    $configPath = Join-Path $PSScriptRoot "..\..\SimRacingAgent\Utils\agent-config.json"
    if (Test-Path $configPath) {
        try {
            $raw = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            # normalize to PSCustomObject and ensure expected fields
            $ps = ConvertFrom-Json ((ConvertTo-Json $raw -Depth 10))
            if (-not $ps.Agent) { $ps | Add-Member -NotePropertyName Agent -NotePropertyValue @{} -Force }
            if (-not $ps.Agent.DataPath) { $ps.Agent | Add-Member -NotePropertyName DataPath -NotePropertyValue (Join-Path $env:TEMP 'SimRacingAgent') -Force }
            if (-not $ps.Logging) { $ps | Add-Member -NotePropertyName Logging -NotePropertyValue @{} -Force }
            if (-not $ps.Logging.LogFilePath) { $ps.Logging | Add-Member -NotePropertyName LogFilePath -NotePropertyValue (Join-Path $env:TEMP 'SimRacingAgent\logs\agent.log') -Force }
            $ps | Add-Member -MemberType ScriptMethod -Name ContainsKey -Value { param($k) return ($this.PSObject.Properties.Name -contains $k) } -Force
            return $ps
        }
        catch {
            # fall through to default
        }
    }

    # Fallback default configuration (matches ConfigurationManager.CreateDefaultConfiguration)
    $dataPath = Join-Path $env:TEMP 'SimRacingAgent'
    $logPath = Join-Path $dataPath 'logs\agent.log'

    $cfg = [PSCustomObject]@{
        Agent = [PSCustomObject]@{ Name = 'SimRacingAgent'; Version = '1.0.0'; UpdateInterval = 30; MaxRetries = 3; DataPath = $dataPath }
        Dashboard = [PSCustomObject]@{ Url = 'http://localhost:5000'; ApiKey = ''; Enabled = $true; HeartbeatInterval = 60 }
        DeviceMonitoring = [PSCustomObject]@{ Enabled = $true; ScanInterval = 5; NotifyOnChanges = $true; DeviceFilters = @() }
        SoftwareManagement = [PSCustomObject]@{ Enabled = $true; MonitorInterval = 10; AutoStart = $false; ManagedSoftware = @() }
        Automation = [PSCustomObject]@{ Enabled = $true; RulesFile = 'automation-rules.json'; MaxConcurrentRules = 5 }
        HealthMonitoring = [PSCustomObject]@{ Enabled = $true; MonitorInterval = 30 }
        Logging = [PSCustomObject]@{ Level = 'Info'; Console = $true; File = $true; Dashboard = $false; MaxLogFiles = 30; LogFilePath = $logPath }
    }

    # Add ContainsKey method to emulate hashtable behaviour in tests
    $cfg | Add-Member -MemberType ScriptMethod -Name ContainsKey -Value { param($k) return ($this.PSObject.Properties.Name -contains $k) } -Force

    return $cfg
}

function Test-AgentRunning {
    # Return $true if a process with name 'SimRacingAgent' is running
    try {
        if ($Global:MockFunctions.ContainsKey('Get-Process')) {
            $Global:MockCalls['Get-Process'] = ($Global:MockCalls['Get-Process'] -as [int]) + 1
            $p = & $Global:MockFunctions['Get-Process'].GetNewClosure()
        }
        else {
            $p = Get-Process -Name 'SimRacingAgent' -ErrorAction SilentlyContinue
        }
        return ($p -and $p.Count -gt 0)
    }
    catch {
        return $false
    }
}

$Global:AgentLockFile = $Global:AgentLockFile -or (Join-Path $env:TEMP 'SimRacingAgent.lock')

function Set-AgentLock {
    try {
        $data = @{ ProcessId = $PID; Timestamp = (Get-Date).ToString('o') }
        $json = $data | ConvertTo-Json
        $path = $Global:AgentLockFile
        $dir = Split-Path $path -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        $json | Set-Content -Path $path -Encoding UTF8
        return $true
    }
    catch {
        return $false
    }
}

function Clear-AgentLock {
    try {
        $path = $Global:AgentLockFile
        if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
        return $true
    }
    catch {
        return $false
    }
}

function Write-AgentLog {
    param(
        [string]$Message,
        [string]$Level = 'Info',
        [string]$Source = '',
        [hashtable]$Properties = @{},
        [string]$Component,
        [string]$LogPath
    )
    # If caller requested an explicit LogPath, prefer writing to it.
    if ($LogPath) {
        if ($Component) { $Source = $Component }
        $formatted = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] [$Source] $Message"
        Write-Host $formatted
        try {
            $dir = Split-Path $LogPath -Parent
            if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
            Add-Content -Path $LogPath -Value $formatted -Encoding UTF8
            return
        }
        catch {}
    }

    # Prefer the real global logger if available
    if ($null -ne $Global:AgentLogger -and $Global:AgentLogger -is [object]) {
        try { $Global:AgentLogger.WriteLog($Message, $Level, $Source, $Properties); return } catch {}
    }

    if ($Component) { $Source = $Component }
    $formatted = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] [$Source] $Message"
    Write-Host $formatted
    try {
        $target = if ($LogPath) { $LogPath } else { Join-Path $env:TEMP 'SimRacingAgent-tests.log' }
        $dir = Split-Path $target -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        Add-Content -Path $target -Value $formatted -Encoding UTF8
    }
    catch {}
}

function Test-Configuration {
    param([object]$Config)
    # If a config object is provided, validate its shape locally (don't delegate to module-level validator)
    if ($Config) {
        if ($Config -is [hashtable]) { return ($Config.ContainsKey('Agent') -and $Config.ContainsKey('Dashboard')) }
        if ($Config -is [psobject] -or $Config -is [System.Management.Automation.PSCustomObject]) { return ($Config.PSObject.Properties.Name -contains 'Agent' -and $Config.PSObject.Properties.Name -contains 'Dashboard') }
        return $false
    }

    # Fallback: delegate to underlying module validator if no config object provided
    if (Get-Command -Name 'Test-AgentConfiguration' -ErrorAction SilentlyContinue) {
        return Test-AgentConfiguration
    }
    return $false
}

function Save-Configuration {
    param([object]$Config, [string]$Path)
    # Prefer local implementation to avoid delegating to module-level functions which expect global state
    try {
        $json = $Config | ConvertTo-Json -Depth 10
        if (-not $Path) {
            $Path = Join-Path $env:TEMP 'SimRacingAgent_saved_config.json'
        }
        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        $json | Set-Content -Path $Path -Encoding UTF8
        return $true
    } catch { return $false }
}

function Load-Configuration {
    param([string]$Path)
    if (Get-Command -Name 'Load-AgentConfiguration' -ErrorAction SilentlyContinue) {
        try { return Load-AgentConfiguration -Path $Path } catch {}
    }
    try {
        if (-not (Test-Path $Path)) { return $null }
        $raw = Get-Content -Path $Path -Raw | ConvertFrom-Json
        # Ensure PSCustomObject with ContainsKey behaviour
        $obj = $raw | ConvertTo-HashtableRecursive
        # Convert recursive hashtable back to PSCustomObject for tests
        $ps = ConvertFrom-Json ((ConvertTo-Json $raw -Depth 10))
        $ps | Add-Member -MemberType ScriptMethod -Name ContainsKey -Value { param($k) return ($this.PSObject.Properties.Name -contains $k) } -Force
        return $ps
    } catch { return $null }
}

function Export-Configuration {
    param([object]$Config)
    $path = Join-Path $env:TEMP ("SimRacingAgent_config_export_{0}.json" -f ([guid]::NewGuid().ToString()))
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
    return @{ FileName = $path }
}

function Get-AgentStatus {
    param([object]$Config)
    $running = Test-AgentRunning
    $configValid = $false
    if ($Config) { $configValid = Test-Configuration -Config $Config }
    $proc = Get-Process -Id $PID -ErrorAction SilentlyContinue
    $memory = if ($proc) { [math]::Round($proc.WorkingSet64 / 1MB,2) } else { 0 }
    return @{ AgentRunning = $running; ConfigValid = $configValid; MemoryUsage = $memory }
}

Export-ModuleMember -Function Get-DefaultConfiguration, Test-AgentRunning, Set-AgentLock, Clear-AgentLock, Write-AgentLog, Test-Configuration, Save-Configuration, Load-Configuration, Export-Configuration, Get-AgentStatus
