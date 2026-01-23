# Logging Utilities
# Centralized logging system with multiple outputs and levels

class AgentLogger {
    [string]$LogPath
    [string]$LogLevel
    [hashtable]$LogLevels
    [bool]$ConsoleOutput
    [bool]$FileOutput
    [bool]$DashboardOutput
    [System.Collections.Queue]$LogBuffer
    [int]$MaxBufferSize

    AgentLogger() {
        $this.LogLevels = @{
            "Trace" = 0
            "Debug" = 1
            "Info" = 2
            "Warning" = 3
            "Error" = 4
            "Critical" = 5
        }

        $this.LogLevel = "Info"
        $this.ConsoleOutput = $true
        $this.FileOutput = $true
        $this.DashboardOutput = $false
        $this.MaxBufferSize = 1000
        $this.LogBuffer = New-Object System.Collections.Queue

        $this.InitializeLogPath()
    }

    [void]InitializeLogPath() {
        $fallbackLog = $null
        try {
            $logsDir = Join-Path $PSScriptRoot "..\Logs"
            if (-not (Test-Path $logsDir)) {
                New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
            }

            $timestamp = Get-Date -Format "yyyy-MM-dd"
            $this.LogPath = Join-Path $logsDir "SimRacingAgent-$timestamp.log"
        }
        catch {
            $this.LogPath = Join-Path $env:TEMP "SimRacingAgent.log"
            # Ensure fallback log path is defined before attempting writes
            $fallbackLog = Join-Path $env:TEMP "SimRacingAgent_fallback.log"
            try {
                $msg = "Warning: Could not initialize standard log path, using temp: $($this.LogPath)"
                Add-Content -Path $fallbackLog -Value $msg -ErrorAction SilentlyContinue
            } catch {
                try {
                    Add-Content -Path $fallbackLog -Value "Logging fallback write failed" -ErrorAction SilentlyContinue
                } catch {
                    Write-Verbose "Logging initialization failed and fallback write also failed." -ErrorAction SilentlyContinue
                }
            }
        }
    }

    [void]WriteLog([string]$Message, [string]$Level = "Info", [string]$Source = "", [hashtable]$Properties = @{}) {
        try {
            $levelValue = $this.LogLevels[$Level]
            $currentLevelValue = $this.LogLevels[$this.LogLevel]

            if ($levelValue -lt $currentLevelValue) {
                return
            }

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            $processId = [System.Diagnostics.Process]::GetCurrentProcess().Id
            $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId

            if (-not $Source) {
                $Source = (Get-PSCallStack)[2].Command
            }

            # Create log entry
            $logEntry = @{
                Timestamp = $timestamp
                Level = $Level
                Source = $Source
                Message = $Message
                ProcessId = $processId
                ThreadId = $threadId
                Properties = $Properties
            }

            # Format for display/file
            $formattedMessage = "[$timestamp] [$Level] [$Source] $Message"
            if ($Properties.Count -gt 0) {
                $propsJson = $Properties | ConvertTo-Json -Compress
                $formattedMessage += " | Properties: $propsJson"
            }

            # Output to console
            if ($this.ConsoleOutput) {
                $this.WriteToConsole($formattedMessage, $Level)
            }

            # Output to file
            if ($this.FileOutput) {
                $this.WriteToFile($formattedMessage)
            }

            # Add to buffer for dashboard
            if ($this.DashboardOutput) {
                $this.AddToBuffer($logEntry)
            }

        }
        catch {
            $ex = $_
            try {
                $fallbackLog = Join-Path $env:TEMP "SimRacingAgent_fallback.log"
                Add-Content -Path $fallbackLog -Value ("Logging error: $($ex.Exception.Message)") -ErrorAction SilentlyContinue
            } catch {
                Write-Verbose "Logging error occurred and fallback write failed: $($ex.Exception.Message)" -ErrorAction SilentlyContinue
            }
        }
    }

    [void]WriteToConsole([string]$Message, [string]$Level) {
        $color = switch ($Level) {
            "Trace" { "DarkGray" }
            "Debug" { "Gray" }
            "Info" { "White" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            "Critical" { "Magenta" }
            default { "White" }
        }

        try {
            $colorEnum = [System.Enum]::Parse([System.ConsoleColor], $color)
            [System.Console]::ForegroundColor = $colorEnum
            [System.Console]::WriteLine($Message)
            [System.Console]::ResetColor()
        }
        catch {
            Write-Output $Message
        }
    }

    [void]WriteToFile([string]$Message) {
        try {
            Add-Content -Path $this.LogPath -Value $Message -Encoding UTF8
        }
        catch {
            $err = $_
            Write-Verbose ("WriteToFile failed: $($err.Exception.Message)") -ErrorAction SilentlyContinue
        }
    }

    [void]AddToBuffer([hashtable]$LogEntry) {
        try {
            if ($this.LogBuffer.Count -ge $this.MaxBufferSize) {
                $this.LogBuffer.Dequeue() | Out-Null
            }

            $this.LogBuffer.Enqueue($LogEntry)
        }
        catch {
            $err = $_
            Write-Verbose ("AddToBuffer failed: $($err.Exception.Message)") -ErrorAction SilentlyContinue
        }
    }

    [array]FlushBuffer() {
        try {
            $entries = @()
            while ($this.LogBuffer.Count -gt 0) {
                $entries += $this.LogBuffer.Dequeue()
            }
            return $entries
        }
        catch {
            return @()
        }
    }

    [void]SetLogLevel([string]$Level) {
        if ($this.LogLevels.ContainsKey($Level)) {
            $this.LogLevel = $Level
            $this.WriteLog("Log level set to: $Level", "Info", "Logger", @{})
        }
    }

    [void]SetOutputs([bool]$Console, [bool]$File, [bool]$Dashboard = $false) {
        $this.ConsoleOutput = $Console
        $this.FileOutput = $File
        $this.DashboardOutput = $Dashboard

        $outputs = @()
        if ($Console) { $outputs += "Console" }
        if ($File) { $outputs += "File" }
        if ($Dashboard) { $outputs += "Dashboard" }

        $this.WriteLog("Log outputs configured: $($outputs -join ', ')", "Info", "Logger", @{})
    }

    [hashtable]GetStatus() {
        return @{
            LogPath = $this.LogPath
            LogLevel = $this.LogLevel
            ConsoleOutput = $this.ConsoleOutput
            FileOutput = $this.FileOutput
            DashboardOutput = $this.DashboardOutput
            BufferSize = $this.LogBuffer.Count
            MaxBufferSize = $this.MaxBufferSize
        }
    }
}

## Prefer module-scoped AgentLogger
if (-not $Script:AgentLogger) { $Script:AgentLogger = [AgentLogger]::new() }

<#
 .SYNOPSIS
    Write a structured log entry to configured outputs.
 .PARAMETER Message
    The log message text.
 .PARAMETER Level
    Log level (Trace, Debug, Info, Warning, Error, Critical).
 .PARAMETER Source
    Optional source identifier for the message.
 .PARAMETER Properties
    Additional structured properties as a hashtable.
 .EXAMPLE
    Write-AgentLog -Message "Started" -Level Info -Source Startup
#>
function Write-AgentLog {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Source = "",
        [hashtable]$Properties = @{}
    )

    if ($Script:AgentLogger) {
        $Script:AgentLogger.WriteLog($Message, $Level, $Source, $Properties)
    } else {
        Write-Output "[$Level] $Message"
    }
}

<#
 .SYNOPSIS
    Write a Trace-level log message.
 .PARAMETER Message
    The log message text.
#>
function Write-AgentTrace {
    param([string]$Message, [string]$Source = "", [hashtable]$Properties = @{})
    Write-AgentLog -Message $Message -Level "Trace" -Source $Source -Properties $Properties
}

<#
 .SYNOPSIS
    Write a Debug-level log message.
 .PARAMETER Message
    The log message text.
#>
function Write-AgentDebug {
    param([string]$Message, [string]$Source = "", [hashtable]$Properties = @{})
    Write-AgentLog -Message $Message -Level "Debug" -Source $Source -Properties $Properties
}

<#
 .SYNOPSIS
    Write an Info-level log message.
 .PARAMETER Message
    The log message text.
#>
function Write-AgentInfo {
    param([string]$Message, [string]$Source = "", [hashtable]$Properties = @{})
    Write-AgentLog -Message $Message -Level "Info" -Source $Source -Properties $Properties
}

<#
 .SYNOPSIS
    Write a Warning-level log message.
 .PARAMETER Message
    The log message text.
#>
function Write-AgentWarning {
    param([string]$Message, [string]$Source = "", [hashtable]$Properties = @{})
    Write-AgentLog -Message $Message -Level "Warning" -Source $Source -Properties $Properties
}

<#
 .SYNOPSIS
    Write an Error-level log message.
 .PARAMETER Message
    The log message text.
#>
function Write-AgentError {
    param([string]$Message, [string]$Source = "", [hashtable]$Properties = @{})
    Write-AgentLog -Message $Message -Level "Error" -Source $Source -Properties $Properties
}

<#
 .SYNOPSIS
    Write a Critical-level log message.
 .PARAMETER Message
    The log message text.
#>
function Write-AgentCritical {
    param([string]$Message, [string]$Source = "", [hashtable]$Properties = @{})
    Write-AgentLog -Message $Message -Level "Critical" -Source $Source -Properties $Properties
}

<#
 .SYNOPSIS
    Set the global log level for the agent logger.
 .PARAMETER Level
    The log level to set (Trace, Debug, Info, Warning, Error, Critical).
#>
function Set-AgentLogLevel {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string]$Level)

    $action = "Set log level to $Level"
    if (-not $PSCmdlet.ShouldProcess('AgentLogger', $action)) { return }

    if ($Script:AgentLogger) { $Script:AgentLogger.SetLogLevel($Level) }
}

<#
 .SYNOPSIS
    Configure which outputs the agent logger writes to.
 .PARAMETER Console
    Enable or disable console output.
 .PARAMETER File
    Enable or disable file output.
 .PARAMETER Dashboard
    Enable or disable dashboard buffering/output.
#>
function Set-AgentLogOutput {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [bool]$Console = $true,
        [bool]$File = $true,
        [bool]$Dashboard = $false
    )

    $action = "Configure outputs: Console=$Console, File=$File, Dashboard=$Dashboard"
    if (-not $PSCmdlet.ShouldProcess('AgentLogger', $action)) { return }

    if ($Script:AgentLogger) { $Script:AgentLogger.SetOutputs($Console, $File, $Dashboard) }
}

<#
 .SYNOPSIS
    Get the current status of the agent logger.
#>
function Get-AgentLogStatus {
    if ($Script:AgentLogger) { return $Script:AgentLogger.GetStatus() }
    return @{}
}

<#
 .SYNOPSIS
    Flush and return buffered log entries destined for the dashboard.
#>
function Get-AgentLogBuffer {
    if ($Script:AgentLogger) { return $Script:AgentLogger.FlushBuffer() }
    return @()
}

<#
 .SYNOPSIS
    Write a structured event to the log.
 .PARAMETER EventType
    Short event type identifier.
#>
function Write-AgentEvent {
    param(
        [string]$EventType,
        [string]$Category = "General",
        [hashtable]$Data = @{},
        [string]$Level = "Info"
    )

    $properties = @{
        Event = $EventType
        Category = $Category
        Data = $Data
    }

    Write-AgentLog -Message "Event: $EventType" -Level $Level -Source $Category -Properties $properties
}

<#
 .SYNOPSIS
    Write a metric measurement to the log.
 .PARAMETER MetricName
    The metric identifier.
#>
function Write-AgentMetric {
    param(
        [string]$MetricName,
        [object]$Value,
        [hashtable]$Tags = @{},
        [string]$Unit = ""
    )

    $properties = @{
        MetricName = $MetricName
        Value = $Value
        Tags = $Tags
        Unit = $Unit
        Type = "Metric"
    }

    Write-AgentLog -Message "Metric: $MetricName = $Value $Unit" -Level "Debug" -Source "Metrics" -Properties $properties
}

<#
 .SYNOPSIS
    Log a performance timing measurement.
 .PARAMETER Operation
    Short operation name.
#>
function Write-AgentPerformance {
    param(
        [string]$Operation,
        [timespan]$Duration,
        [hashtable]$Context = @{}
    )

    $properties = @{
        Operation = $Operation
        Duration = $Duration
        DurationMs = $Duration.TotalMilliseconds
        Context = $Context
        Type = "Performance"
    }

    Write-AgentLog -Message "Performance: $Operation completed in $($Duration.TotalMilliseconds)ms" -Level "Debug" -Source "Performance" -Properties $properties
}

<#
 .SYNOPSIS
    Log an exception with structured details.
 .PARAMETER Exception
    The exception object to log.
#>
function Write-AgentException {
    param(
        [System.Exception]$Exception,
        [string]$Context = "",
        [string]$Level = "Error"
    )

    $properties = @{
        ExceptionType = $Exception.GetType().FullName
        StackTrace = $Exception.StackTrace
        InnerException = if ($Exception.InnerException) { $Exception.InnerException.Message } else { $null }
        Context = $Context
        Type = "Exception"
    }

    $message = if ($Context) { "$Context : $($Exception.Message)" } else { $Exception.Message }
    Write-AgentLog -Message $message -Level $Level -Source "Exception" -Properties $properties
}

# Export module members
Export-ModuleMember -Function Write-AgentLog, Write-AgentTrace, Write-AgentDebug, Write-AgentInfo, Write-AgentWarning, Write-AgentError, Write-AgentCritical, Set-AgentLogLevel, Set-AgentLogOutput, Get-AgentLogStatus, Get-AgentLogBuffer, Write-AgentEvent, Write-AgentMetric, Write-AgentPerformance, Write-AgentException



