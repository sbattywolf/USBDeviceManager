
<#
Interactive process + log menu for USBDeviceManager (server) and SimRacingAgent (agent).
Run: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\process-menu.ps1
#>

function Get-ServerProcess {
    # Mock-mode emulation: if mock pid file exists, return a fake process object
    try {
        if ($env:PROCESS_MENU_MOCK -eq '1') {
            $mockPidFile = Join-Path -Path $PSScriptRoot -ChildPath 'ci\mock_server.pid'
            if (Test-Path $mockPidFile) {
                $pid = Get-Content -Path $mockPidFile -ErrorAction SilentlyContinue
                if ($pid) {
                    return [PSCustomObject]@{ ProcessId = [int]$pid; CreationDate = (Get-Date).ToString('o'); CommandLine = 'mock USBDeviceManager' }
                }
            }
        }
    } catch { }

    # Prefer the dedicated exe, fallback to dotnet process running the app
    $p = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'USBDeviceManager' } | Select-Object -First 1
    if ($p) { return $p }
    $c = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'USBDeviceManager' } | Select-Object -First 1
    if ($c) { return $c }
    return $null
}

function Get-AgentProcess {
    # Mock-mode emulation: if mock agent pid file exists, return a fake process object
    try {
        if ($env:PROCESS_MENU_MOCK -eq '1') {
            $mockPidFile = Join-Path -Path $PSScriptRoot -ChildPath 'ci\mock_agent.pid'
            if (Test-Path $mockPidFile) {
                $pid = Get-Content -Path $mockPidFile -ErrorAction SilentlyContinue
                if ($pid) {
                    return [PSCustomObject]@{ ProcessId = [int]$pid; CreationDate = (Get-Date).ToString('o'); CommandLine = 'mock SimRacingAgent' }
                }
            }
        }
    } catch { }

    # Agent runs as PowerShell executing SimRacingAgent.ps1 or named process
    $p = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'SimRacingAgent|powershell' } | Select-Object -First 1
    $c = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'SimRacingAgent.ps1' } | Select-Object -First 1
    if ($c) { return $c }
    if ($p) { return $p }
    return $null
}

function Get-ProcId($proc) {
    if (-not $proc) { return $null }
    if ($proc -is [System.Diagnostics.Process]) { return $proc.Id }
    if ($proc.PSObject.Properties.Name -contains 'ProcessId') { return $proc.ProcessId }
    if ($proc.PSObject.Properties.Name -contains 'Id') { return $proc.Id }
    return $null
}

function Get-ProcStartTimeString($proc) {
    if (-not $proc) { return $null }
    try {
        if ($proc -is [System.Diagnostics.Process]) {
            return $proc.StartTime.ToString('o')
        }
        # CIM Win32_Process exposes CreationDate in WMI datetime format
        if ($proc.PSObject.Properties.Name -contains 'CreationDate') {
            $dt = [System.Management.ManagementDateTimeConverter]::ToDateTime($proc.CreationDate)
            return $dt.ToString('o')
        }
    } catch { }
    return $null
}

function Show-ProcInfo($proc) {
    if (-not $proc) { Write-Host "(not found)"; return }
    try {
        if ($proc -is [System.Diagnostics.Process]) {
            $proc | Format-List Id, ProcessName, StartTime, Threads.Count, HandleCount
            $pw = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue
            if ($pw) { $pw | Select-Object ProcessId,ParentProcessId,ExecutablePath,CommandLine | Format-List }
        }
        else {
            $proc | Select-Object ProcessId,ParentProcessId,Name,ExecutablePath,CommandLine | Format-List
        }
    } catch { Write-Host 'Error reading process info:'; Write-Host $_ }
}

function Get-OwningTerminal($proc) {
    if (-not $proc) { return $null }
    $procPid = Get-ProcId $proc
    if (-not $procPid) { return $null }

    # Walk parent chain up to a reasonable depth to find a terminal/console
    $maxDepth = 8
    $current = Get-CimInstance Win32_Process -Filter "ProcessId=$procPid" -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt $maxDepth -and $current; $i++) {
        $ppid = $current.ParentProcessId
        if (-not $ppid) { break }
        $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$ppid" -ErrorAction SilentlyContinue
        if (-not $parent) { break }
        $pname = $parent.Name
        $pcmd = $parent.CommandLine
        if ($pname -match 'powershell|pwsh|cmd|conhost|WindowsTerminal|wt|terminal') {
            return [PSCustomObject]@{ Pid = $parent.ProcessId; ProcessName = $pname; CommandLine = $pcmd }
        }
        $current = $parent
    }
    return $null
}

function Format-CommandLine($cmd, $maxLen = 120) {
    if (-not $cmd) { return '' }
    try {
        if ($cmd.Length -le $maxLen) { return $cmd }
        return $cmd.Substring(0, $maxLen - 3) + '...'
    } catch { return $cmd }
}

# Helper to write test marker files using an absolute path resolved from the repo root when a relative path is provided.
function Write-TestMarker([string]$line) {
    if (-not $env:PROCESS_MENU_TEST_MARKER) { return }
    try {
        $marker = $env:PROCESS_MENU_TEST_MARKER
        if (-not [System.IO.Path]::IsPathRooted($marker)) {
            $repoRoot = Split-Path -Path $PSScriptRoot -Parent
            $marker = Join-Path -Path $repoRoot -ChildPath $marker
        }
        # Sanitize the line: collapse any embedded newlines and trim whitespace.
        $safe = ($line -replace "[\r\n]+", ' ').Trim()
        # Use Add-Content to append raw text without formatting/wrapping.
        Add-Content -Path $marker -Value $safe -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}
function Tail-File($path) {
    if (-not (Test-Path $path)) { Write-Host "Log not found: $path"; return }
    Write-Host "Tailing $path - press Enter to stop"

    # initial immediate display: last 100 lines
    try {
        Get-Content -Path $path -Tail 100 | ForEach-Object { Write-Host $_ }
    } catch { Write-Host "(failed to read initial lines) $_" }

    $stop = $false
    while (-not $stop) {
        Write-Host "Next poll in ${TailPollSeconds}s... Press Enter to stop"
        $elapsed = 0
        while ($elapsed -lt $TailPollSeconds) {
            Start-Sleep -Milliseconds 200
            $elapsed += 0.2
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq 'Enter') { $stop = $true; break }
            }
        }
        if ($stop) { break }

        # refresh: show last 100 lines with separator
        Write-Host "---- Poll: showing last 100 lines at $(Get-Date -Format o) ----"
        try {
            Get-Content -Path $path -Tail 100 | ForEach-Object { Write-Host $_ }
        } catch { Write-Host "(failed to read lines) $_" }
    }
}

function Stop-ProcById($id) {
    try {
        Stop-Process -Id $id -Force -ErrorAction Stop
        Write-Host "Stopped $id"
    } catch {
        Write-Host 'Failed to stop' $id
        Write-Host $_
    }
}

function Start-ServerDetached {
    # Support mock/no-process mode via env var PROCESS_MENU_MOCK=1 or NO_PROC=1
    $mock = $false
    if ($env:PROCESS_MENU_MOCK -eq '1' -or $env:NO_PROC -eq '1') { $mock = $true }

    # Additional safety/dry-run guard: PROCESS_MENU_DRY_RUN=1 or PROCESS_MENU_NO_START=1
    $dryRun = $false
    if ($env:PROCESS_MENU_DRY_RUN -eq '1' -or $env:PROCESS_MENU_NO_START -eq '1') { $dryRun = $true }

    Push-Location (Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\server\USBDeviceManager')
    $cwd = (Get-Location)
    $outLog = Join-Path -Path ([string]$cwd) -ChildPath 'server.log'
    $errLog = Join-Path -Path ([string]$cwd) -ChildPath 'server.err'

    # Ensure logs exist and are writable (best-effort). If we cannot create them, warn but continue.
    foreach ($p in @($outLog, $errLog)) {
        try {
            if (-not (Test-Path $p)) { New-Item -Path $p -ItemType File -Force | Out-Null }
            else {
                # attempt an open for write to detect locks/permission issues
                $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
                $fs.Close()
            }
        } catch {
            Write-Host ("Warning: cannot create/open log {0}: {1}" -f $p, $_.Exception.Message) -ForegroundColor Yellow
        }
    }

    if ($dryRun) {
        # Dry-run: do not start, write marker and exit
        try { "$((Get-Date).ToString('o')) MOCK/DRYRUN Start-ServerDetached (no process started)" | Out-File -FilePath $outLog -Append -Encoding UTF8 -ErrorAction Stop } catch {}
            if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) MOCK_MARK Start-ServerDetached" }
        Write-Host "[DRYRUN] Skipping actual server start; logs -> $outLog"
        Pop-Location
        return [PSCustomObject]@{ Id = 0 }
    }

    if ($mock) {
        # Mock-mode: emulate a running server using a pid file
        $mockPidFile = Join-Path -Path $PSScriptRoot -ChildPath 'ci\mock_server.pid'
        try {
            if (Test-Path $mockPidFile) {
                $existingPid = Get-Content -Path $mockPidFile -ErrorAction SilentlyContinue
                if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) SKIP_ALREADY_RUNNING Start-ServerDetached PID=$existingPid" }
                Pop-Location
                return [PSCustomObject]@{ Id = [int]$existingPid; ProcessId = [int]$existingPid }
            }
            $newPid = Get-Random -Minimum 20000 -Maximum 60000
            Set-Content -Path $mockPidFile -Value $newPid -Force
            if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) MOCK_MARK Start-ServerDetached PID=$newPid" }
            try { "$((Get-Date).ToString('o')) MOCK Start-ServerDetached PID=$newPid" | Out-File -FilePath $outLog -Append -Encoding UTF8 -ErrorAction Stop } catch {}
            Pop-Location
            return [PSCustomObject]@{ Id = [int]$newPid; ProcessId = [int]$newPid; CreationDate = (Get-Date).ToString('o') }
        } catch {
            Pop-Location
            return [PSCustomObject]@{ Id = 0 }
        }
    }

    # Singleton guard: if a server process is already running, do not start another.
    $existing = Get-ServerProcess
    $existingId = Get-ProcId $existing
    if ($existingId) {
        Write-Host ("Server already running (PID={0}); skipping start." -f $existingId) -ForegroundColor Yellow
        if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) SKIP_ALREADY_RUNNING Start-ServerDetached PID=$existingId" }
        Pop-Location
        return $existing
    }

    # Check for dotnet on PATH for safety
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetCmd) {
        $msg = 'dotnet runtime not found on PATH. Aborting server start for safety.'
        Write-Host $msg -ForegroundColor Red
        Write-Host 'If you intentionally want to skip starting the server, set PROCESS_MENU_DRY_RUN=1 or PROCESS_MENU_ASSUME_DRYRUN=1.' -ForegroundColor Yellow
        if ($env:PROCESS_MENU_ASSUME_DRYRUN -eq '1') {
            try { "$((Get-Date).ToString('o')) ASSUME_DRYRUN Start-ServerDetached (dotnet missing)" | Out-File -FilePath $outLog -Append -Encoding UTF8 -ErrorAction Stop } catch {}
                if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) MOCK_MARK Start-ServerDetached_MISSING_DOTNET" }
            Pop-Location
            return [PSCustomObject]@{ Id = 0 }
        }
        Pop-Location
        return $null
    }

    try {
        $proc = Start-Process -FilePath dotnet -ArgumentList 'run' -WorkingDirectory $cwd -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru -ErrorAction Stop
        Pop-Location
        Write-Host "Started server (detached); PID=$($proc.Id); logs -> $outLog"
        if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) STARTED Start-ServerDetached PID=$($proc.Id)" }
        $exitLog = Join-Path -Path ([string]$cwd) -ChildPath 'server-exit-capture.log'
        Start-Job -Name "ServerExitWatcher_$($proc.Id)" -ScriptBlock {
            param($processId,$log)
            Try {
                Wait-Process -Id $processId -ErrorAction Stop
                $ts = (Get-Date).ToUniversalTime().ToString('o')
                "$ts ProcessExited PID=$processId" | Out-File -FilePath $log -Append -Encoding UTF8
            } Catch {
                $ts = (Get-Date).ToUniversalTime().ToString('o')
                "$ts Wait-Process failed for PID=$processId - $_" | Out-File -FilePath $log -Append -Encoding UTF8
            }
        } -ArgumentList $proc.Id,$exitLog | Out-Null
        return $proc
    } catch {
        $err = $_.Exception.Message -replace "\r|\n"," "
        try { "$((Get-Date).ToString('o')) FAILED Start-ServerDetached Error:$err" | Out-File -FilePath $errLog -Append -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
        if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) FAIL_MARK Start-ServerDetached $err" }
        Write-Host "Failed to start server: $err" -ForegroundColor Red
        Pop-Location
        return $null
    }
}

function Start-AgentDetached {
    # Support mock/no-process mode via env var PROCESS_MENU_MOCK=1 or NO_PROC=1
    $mock = $false
    if ($env:PROCESS_MENU_MOCK -eq '1' -or $env:NO_PROC -eq '1') { $mock = $true }

    Push-Location (Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\agent\SimRacingAgent')
    $cwd = (Get-Location)
    $outLog = Join-Path -Path ([string]$cwd) -ChildPath 'agent-run.log'
    $errLog = Join-Path -Path ([string]$cwd) -ChildPath 'agent-run.err'
    if ($mock) {
        if (-not (Test-Path $outLog)) { New-Item -Path $outLog -ItemType File -Force | Out-Null }
        if (-not (Test-Path $errLog)) { New-Item -Path $errLog -ItemType File -Force | Out-Null }
        # Mock-mode: emulate agent PID file
        $mockPidFile = Join-Path -Path $PSScriptRoot -ChildPath 'ci\mock_agent.pid'
        try {
            if (Test-Path $mockPidFile) {
                $existingPid = Get-Content -Path $mockPidFile -ErrorAction SilentlyContinue
                    if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) SKIP_ALREADY_RUNNING Start-AgentDetached PID=$existingPid" }
                Pop-Location
                return [PSCustomObject]@{ Id = [int]$existingPid; ProcessId = [int]$existingPid }
            }
            $newPid = Get-Random -Minimum 20000 -Maximum 60000
            Set-Content -Path $mockPidFile -Value $newPid -Force
                if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) MOCK_MARK Start-AgentDetached PID=$newPid" }
            try { "$((Get-Date).ToString('o')) MOCK Start-AgentDetached PID=$newPid" | Out-File -FilePath $outLog -Append -Encoding UTF8 -ErrorAction Stop } catch {}
            Pop-Location
            return [PSCustomObject]@{ Id = [int]$newPid; ProcessId = [int]$newPid; CreationDate = (Get-Date).ToString('o') }
        } catch {
            Pop-Location
            return [PSCustomObject]@{ Id = 0 }
        }
    }

    $proc = Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','.\SimRacingAgent.ps1' -WorkingDirectory $cwd -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
    Pop-Location
    Write-Host "Started agent (detached); PID=$($proc.Id); logs -> agent/SimRacingAgent/agent-run.log"
    $exitLog = Join-Path -Path ([string]$cwd) -ChildPath 'agent-exit-capture.log'
    Start-Job -Name "AgentExitWatcher_$($proc.Id)" -ScriptBlock {
        param($processId,$log)
        Try {
            Wait-Process -Id $processId -ErrorAction Stop
            $ts = (Get-Date).ToUniversalTime().ToString('o')
            "$ts ProcessExited PID=$processId" | Out-File -FilePath $log -Append -Encoding UTF8
        } Catch {
            $ts = (Get-Date).ToUniversalTime().ToString('o')
            "$ts Wait-Process failed for PID=$processId - $_" | Out-File -FilePath $log -Append -Encoding UTF8
        }
    } -ArgumentList $proc.Id,$exitLog | Out-Null
}

while ($true) {
    # Opt-in auto-advance for automated mock runs: if mock-mode is active
    # and `PROCESS_MENU_ENABLE_AUTO_ADVANCE=1` is set, perform the default
    # action once and exit. This keeps the change minimal and CI-safe.
    if ($env:PROCESS_MENU_MOCK -eq '1' -and $env:PROCESS_MENU_ENABLE_AUTO_ADVANCE -eq '1') {
        $defaultAction = $env:PROCESS_MENU_DEFAULT_ACTION
        if (-not $defaultAction) { $defaultAction = '2' }
        Write-Host "Auto-advance (mock-mode) enabled; executing default action: $defaultAction" -ForegroundColor DarkYellow
        switch ($defaultAction) {
            '2' { Start-ServerDetached }
            '6' { Start-AgentDetached }
            default { Start-ServerDetached }
        }
        Write-Host "Auto-advance complete; exiting." -ForegroundColor DarkCyan
        exit 0
    }
    Clear-Host
    Write-Host "=== Process Menu: Server vs Agent ===" -ForegroundColor Cyan
    # Configurable tail polling (seconds)
    if (-not (Get-Variable -Name TailPollSeconds -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name TailPollSeconds -Scope Script -Value 30
    }

    # Input timeout (seconds). Default 10s. Controlled via env var PROCESS_MENU_INPUT_TIMEOUT.
    if (-not (Get-Variable -Name InputTimeoutSeconds -Scope Script -ErrorAction SilentlyContinue)) {
        $envTimeout = $env:PROCESS_MENU_INPUT_TIMEOUT
        if ($envTimeout -and [int]::TryParse($envTimeout,[ref]$null)) { Set-Variable -Name InputTimeoutSeconds -Scope Script -Value ([int]$envTimeout) }
        else { Set-Variable -Name InputTimeoutSeconds -Scope Script -Value 10 }
    }

    function Read-Line-WithTimeout([string]$prompt, [int]$timeoutSec) {
        Write-Host -NoNewline "$prompt " -ForegroundColor Cyan
        $sb = New-Object System.Text.StringBuilder
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while ($stopwatch.Elapsed.TotalSeconds -lt $timeoutSec) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Enter') { break }
                if ($key.Key -eq 'Backspace') {
                    if ($sb.Length -gt 0) { $sb.Length = $sb.Length - 1; Write-Host -NoNewline "`b `b" } continue
                }
                $sb.Append($key.KeyChar) | Out-Null
                Write-Host -NoNewline $key.KeyChar
            } else {
                Start-Sleep -Milliseconds 100
            }
        }
        $stopwatch.Stop()
        if ($sb.Length -eq 0 -and $stopwatch.Elapsed.TotalSeconds -ge $timeoutSec) { Write-Host ''; return $null }
        Write-Host ''
        return $sb.ToString()
    }

    # Show concise status at top for quick identification
    $curServer = Get-ServerProcess
    $curAgent = Get-AgentProcess
    $curServerId = Get-ProcId $curServer
    $curAgentId = Get-ProcId $curAgent
    # If running in mock/testing mode, show a concise single-line summary and highlight it.
    if ($env:PROCESS_MENU_MOCK -eq '1') {
        $srvState = if ($curServerId) { 'up' } else { 'dw' }
        $agtState = if ($curAgentId) { 'up' } else { 'dw' }
        Write-Host "Running in TESTING mode - srvmck:$srvState agntmck:$agtState" -ForegroundColor Magenta
    }
    # Display concise Server/Agent status line (human-readable start times)
    $srvStatus = if ($env:PROCESS_MENU_MOCK -eq '1') { 'MOCKED' } elseif ($curServerId) { 'UP' } else { 'DOWN' }
    $agtStatus = if ($env:PROCESS_MENU_MOCK -eq '1') { 'MOCKED' } elseif ($curAgentId) { 'UP' } else { 'DOWN' }

    # Helper to format start time safely
    function Format-StartTime($raw) {
        if (-not $raw) { return 'N/A' }
        try {
            $dt = [datetime]::Parse($raw)
            return $dt.ToString('yyyy MM dd HH:mm:ss')
        } catch { return $raw }
    }

    $srvStartRaw = $null; $agtStartRaw = $null
    try { $srvStartRaw = Get-ProcStartTimeString $curServer } catch { $srvStartRaw = $null }
    try { $agtStartRaw = Get-ProcStartTimeString $curAgent } catch { $agtStartRaw = $null }

    $srvStartFmt = Format-StartTime $srvStartRaw
    $agtStartFmt = Format-StartTime $agtStartRaw

    # Choose color for status summary
    $srvColor = if ($srvStatus -eq 'UP') { 'Green' } elseif ($srvStatus -eq 'MOCKED') { 'Magenta' } else { 'DarkYellow' }
    $agtColor = if ($agtStatus -eq 'UP') { 'Green' } elseif ($agtStatus -eq 'MOCKED') { 'Magenta' } else { 'DarkYellow' }

    # Print summary lines
    $srvPidText = if ($curServerId) { "PID=$curServerId" } else { 'PID=N/A' }
    $agtPidText = if ($curAgentId) { "PID=$curAgentId" } else { 'PID=N/A' }
    Write-Host ("Server: {0} ({1}, started={2})" -f $srvStatus, $srvPidText, $srvStartFmt) -ForegroundColor $srvColor
    Write-Host "Quick: press 1 to show full server info" -ForegroundColor DarkCyan
    Write-Host ("Agent: {0} ({1}, started={2})" -f $agtStatus, $agtPidText, $agtStartFmt) -ForegroundColor $agtColor
    Write-Host "Tail poll interval: $($TailPollSeconds)s" -ForegroundColor DarkCyan
    Write-Host "--- Server ---" -ForegroundColor Yellow
    Write-Host "1) Show server process info"
    Write-Host "2) Start server (detached)"
    Write-Host "3) Stop server process"
    Write-Host "4) Tail server.log"
    Write-Host ""
    Write-Host "--- Agent ---" -ForegroundColor Yellow
    Write-Host "5) Show agent process info"
    Write-Host "6) Start agent (detached)"
    Write-Host "7) Stop agent process"
    Write-Host "8) Tail agent-run.log"
    Write-Host ""
    # Config moved under Setup (option 9)
    Write-Host "--- Setup ---" -ForegroundColor Yellow
    Write-Host "9) Setup menu (ensure/clear logs, rebuild server)"
    Write-Host "0) Exit"

    $raw = Read-Line-WithTimeout 'Select an option' $InputTimeoutSeconds
    $exitMain = $false
    if ($null -eq $raw) {
        # timed out
        if ($env:PROCESS_MENU_ENABLE_AUTO_ADVANCE -eq '1') {
            $defaultAction = $env:PROCESS_MENU_DEFAULT_ACTION
            if (-not $defaultAction) { $defaultAction = '2' }
            Write-Host "No input within ${InputTimeoutSeconds}s; auto-selecting default action: $defaultAction" -ForegroundColor DarkYellow
            switch ($defaultAction) {
                '2' { Start-ServerDetached }
                '6' { Start-AgentDetached }
                default { Start-ServerDetached }
            }
            Read-Host 'Auto-advance action complete. Press Enter to continue'
            continue
        } else {
            # treat as empty input and re-prompt (preserve previous behavior of no auto-select)
            $choice = ''
        }
    } else {
        $choice = $raw.Trim().ToUpperInvariant()
    }
    switch ($choice) {
        '1' {
            $sp = Get-ServerProcess
            Write-Host "\n-- Server process --" -ForegroundColor Yellow
            Show-ProcInfo $sp
            Read-Host 'Press Enter to continue'
        }
        '2' {
            $started = Start-ServerDetached
            # immediately refresh server status so top-line reflects started process
            Start-Sleep -Milliseconds 200
            $curServer = Get-ServerProcess
            $curServerId = Get-ProcId $curServer
            if ($curServerId) { Write-Host "Server started (PID=$curServerId)" -ForegroundColor Green } else { Write-Host 'Server start requested (detached); monitor logs for PID' -ForegroundColor Yellow }
            Read-Host 'Press Enter to continue'
        }
        '3' {
            $sp = Get-ServerProcess
            $id = Get-ProcId $sp
            if ($id) {
                Stop-ProcById $id
                # If mock-mode, remove mock pid file when stopping
                if ($env:PROCESS_MENU_MOCK -eq '1') {
                    $mockPidFile = Join-Path -Path $PSScriptRoot -ChildPath 'ci\mock_server.pid'
                    try {
                        if (Test-Path $mockPidFile) {
                            $mp = Get-Content $mockPidFile -ErrorAction SilentlyContinue
                            Remove-Item -Path $mockPidFile -Force -ErrorAction SilentlyContinue
                            if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) MOCK_MARK Stopped-Server PID=$mp" }
                        }
                    } catch {}
                }
                Start-Sleep -Milliseconds 200; $curServer = Get-ServerProcess; $curServerId = Get-ProcId $curServer; Write-Host "Server stopped." -ForegroundColor Yellow
            } else { Write-Host 'Server not found' }
            Read-Host 'Press Enter to continue'
        }
        '4' {
            Tail-File (Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\server\USBDeviceManager\server.log')
            Read-Host 'Tailing ended. Press Enter to continue'
        }
        '5' {
            $ap = Get-AgentProcess
            Write-Host "\n-- Agent process --" -ForegroundColor Yellow
            Show-ProcInfo $ap
            Read-Host 'Press Enter to continue'
        }
        '6' {
            $ap = Get-AgentProcess
            $aid = Get-ProcId $ap
            if ($aid) {
                Write-Host "Agent already running (PID=$aid)."
                $ans = (Read-Host 'Restart agent (stop existing and start new)? [y/N]').Trim().ToUpperInvariant()
                if ($ans -eq 'Y') {
                    Write-Host "Stopping existing agent PID=$aid..."
                    try { Stop-ProcById $aid } catch { Write-Host ("Failed to stop PID={0}: {1}" -f $aid, $_.Exception.Message) }
                    Start-AgentDetached
                } else {
                    Write-Host 'Skipping start; existing agent will be left running.'
                }
            } else {
                Start-AgentDetached
            }
            Read-Host 'Press Enter to continue'
        }
        '7' {
            $ap = Get-AgentProcess
            $id = Get-ProcId $ap
            if ($id) {
                Stop-ProcById $id
                if ($env:PROCESS_MENU_MOCK -eq '1') {
                    $mockPidFile = Join-Path -Path $PSScriptRoot -ChildPath 'ci\mock_agent.pid'
                    try {
                        if (Test-Path $mockPidFile) {
                            $mp = Get-Content $mockPidFile -ErrorAction SilentlyContinue
                            Remove-Item -Path $mockPidFile -Force -ErrorAction SilentlyContinue
                            if ($env:PROCESS_MENU_TEST_MARKER) { Write-TestMarker "$((Get-Date).ToString('o')) MOCK_MARK Stopped-Agent PID=$mp" }
                        }
                    } catch {}
                }
            } else { Write-Host 'Agent not found' }
            Read-Host 'Press Enter to continue'
        }
        '8' {
            Tail-File (Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\agent\SimRacingAgent\agent-run.log')
            Read-Host 'Tailing ended. Press Enter to continue'
        }
        # Config options moved into Setup submenu
        '9' {
            # Setup submenu
            $exitSetup = $false
            while (-not $exitSetup) {
                Clear-Host
                Write-Host '--- Setup Menu ---' -ForegroundColor Cyan
                Write-Host '1) Ensure log files exist'
                Write-Host '2) Clear logs (server + agent)'
                Write-Host '3) Rebuild server (dotnet build)'
                Write-Host '4) Set tail poll interval (seconds)'
                Write-Host '5) Identify running roles (agent/server)'
                Write-Host '0) Back'
                $s = (Read-Host 'Select setup option').Trim()
                switch ($s) {
                    '1' {
                        $serverLog = Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\server\USBDeviceManager\server.log'
                        $agentLog = Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\agent\SimRacingAgent\agent-run.log'
                        $paths = @($serverLog, $agentLog)
                        $results = foreach ($p in $paths) {
                            $fp = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                            if (-not $fp) {
                                New-Item -Path $p -ItemType File -Force | Out-Null
                                [PSCustomObject]@{ Path = $p; Status = 'Created' }
                            } else {
                                [PSCustomObject]@{ Path = $p; Status = 'Exists' }
                            }
                        }
                        $results | Format-Table -AutoSize
                        Read-Host 'Press Enter to continue'
                    }
                    '2' {
                        $serverLog = Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\server\USBDeviceManager\server.log'
                        $agentLog = Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\agent\SimRacingAgent\agent-run.log'
                        $files = @($serverLog, $agentLog)
                        $results = foreach ($f in $files) {
                            if (Test-Path $f) {
                                try {
                                    Clear-Content -Path $f -ErrorAction Stop
                                    [PSCustomObject]@{ Path = $f; Status = 'Cleared' }
                                } catch {
                                    # If Clear-Content fails (file locked), try a safer .NET truncation/write
                                    try {
                                        [System.IO.File]::WriteAllText($f, '')
                                        [PSCustomObject]@{ Path = $f; Status = 'Truncated (fallback)' }
                                    } catch {
                                        $err = $_.Exception.Message -replace "\r|\n"," "
                                        [PSCustomObject]@{ Path = $f; Status = "Error: $err" }
                                    }
                                }
                            } else {
                                [PSCustomObject]@{ Path = $f; Status = 'Missing' }
                            }
                        }
                        $results | Format-Table -AutoSize
                        Read-Host 'Press Enter to continue'
                    }
                    '3' {
                        Push-Location (Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\server\USBDeviceManager')
                        dotnet build
                        Pop-Location
                        Read-Host 'Build finished. Press Enter to continue'
                    }
                    '0' { $exitSetup = $true }
                    '4' {
                        $val = Read-Host "Enter tail poll interval in seconds (current: $TailPollSeconds)"
                        if ([int]::TryParse($val,[ref]$null)) {
                            $n = [int]$val
                            if ($n -ge 1) { Set-Variable -Name TailPollSeconds -Scope Script -Value $n; Write-Host "Tail poll interval set to ${n}s" } else { Write-Host 'Please enter a positive integer' }
                        } else { Write-Host 'Invalid number' }
                        Read-Host 'Press Enter to continue'
                    }
                    '5' {
                        $sp = Get-ServerProcess
                        $ap = Get-AgentProcess
                        Write-Host "\n-- Identification --" -ForegroundColor Yellow
                        $sid = Get-ProcId $sp
                        $aid = Get-ProcId $ap
                        if ($sid) { Write-Host "Server running: PID=$sid" } else { Write-Host 'Server not running' }
                        if ($aid) { Write-Host "Agent running: PID=$aid" } else { Write-Host 'Agent not running' }
                        Read-Host 'Press Enter to continue'
                    }
                    '6' {
                        Clear-Host
                        Write-Host '--- Owning Terminals ---' -ForegroundColor Cyan
                        $sp = Get-ServerProcess
                        $ap = Get-AgentProcess
                        $sOwner = Get-OwningTerminal $sp
                        $aOwner = Get-OwningTerminal $ap
                        if ($sOwner) {
                            Write-Host ("Server owner: {0} PID={1}" -f $sOwner.ProcessName, $sOwner.Pid)
                            Write-Host ("Cmd: {0}" -f (Format-CommandLine $sOwner.CommandLine 200))
                        } else { Write-Host 'Server owner: none' }
                        if ($aOwner) {
                            Write-Host ("Agent owner: {0} PID={1}" -f $aOwner.ProcessName, $aOwner.Pid)
                            Write-Host ("Cmd: {0}" -f (Format-CommandLine $aOwner.CommandLine 200))
                        } else { Write-Host 'Agent owner: none' }

                        if ($env:PROCESS_MENU_MOCK -eq '1') {
                            Write-Host 'Mock-mode: signal actions are no-op.' -ForegroundColor Yellow
                            Read-Host 'Press Enter to continue'
                            break
                        }

                        if ($env:PROCESS_MENU_ALLOW_SIGNAL -eq '1') {
                            $ans = (Read-Host 'Terminate any owning terminal processes? This is destructive. [y/N]').Trim().ToUpperInvariant()
                            if ($ans -eq 'Y') {
                                foreach ($o in @($sOwner, $aOwner)) {
                                    if ($o) {
                                        try {
                                            Stop-Process -Id $o.Pid -Force -ErrorAction Stop
                                            Write-Host "Terminated PID=$($o.Pid)"
                                        } catch {
                                            Write-Host "Failed to terminate PID=$($o.Pid): $($_.Exception.Message)" -ForegroundColor Red
                                        }
                                    }
                                }
                            } else { Write-Host 'Skipping termination.' }
                        } else {
                            Write-Host 'To enable signaling, set PROCESS_MENU_ALLOW_SIGNAL=1 before running this script.' -ForegroundColor Yellow
                        }
                        Read-Host 'Press Enter to continue'
                    }
                    default { Write-Host 'Invalid choice'; Start-Sleep -Seconds 1 }
                }
            }
        }
            '0' { $exitMain = $true }
        default { Write-Host 'Invalid choice'; Start-Sleep -Seconds 1 }
    }
        if ($exitMain) { break }
}

Write-Host 'Exiting process-menu.'
try {
    # Cleanup stale mock pid files on exit
    if ($env:PROCESS_MENU_MOCK -eq '1') {
        $mockServer = Join-Path -Path $PSScriptRoot -ChildPath 'ci\mock_server.pid'
        $mockAgent  = Join-Path -Path $PSScriptRoot -ChildPath 'ci\mock_agent.pid'
        try { if (Test-Path $mockServer) { Remove-Item -Path $mockServer -Force -ErrorAction SilentlyContinue } } catch {}
        try { if (Test-Path $mockAgent)  { Remove-Item -Path $mockAgent -Force -ErrorAction SilentlyContinue } } catch {}
    }
} catch {}
