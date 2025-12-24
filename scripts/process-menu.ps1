
<#
Interactive process + log menu for USBDeviceManager (server) and SimRacingAgent (agent).
Run: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\process-menu.ps1
#>

function Get-ServerProcess {
    # Prefer the dedicated exe, fallback to dotnet process running the app
    $p = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'USBDeviceManager' } | Select-Object -First 1
    if ($p) { return $p }
    $c = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'USBDeviceManager' } | Select-Object -First 1
    if ($c) { return $c }
    return $null
}

function Get-AgentProcess {
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
    Push-Location (Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\server\USBDeviceManager')
    $cwd = (Get-Location)
    $outLog = Join-Path -Path ([string]$cwd) -ChildPath 'server.log'
    $errLog = Join-Path -Path ([string]$cwd) -ChildPath 'server.err'
    $proc = Start-Process -FilePath dotnet -ArgumentList 'run' -WorkingDirectory $cwd -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
    Pop-Location
    Write-Host "Started server (detached); PID=$($proc.Id); logs -> server/USBDeviceManager/server.log"
    $exitLog = Join-Path -Path ([string]$cwd) -ChildPath 'server-exit-capture.log'
    Start-Job -Name "ServerExitWatcher_$($proc.Id)" -ScriptBlock {
        param($pid,$log)
        Try {
            Wait-Process -Id $pid -ErrorAction Stop
            $ts = (Get-Date).ToUniversalTime().ToString('o')
            "$ts ProcessExited PID=$pid" | Out-File -FilePath $log -Append -Encoding UTF8
        } Catch {
            $ts = (Get-Date).ToUniversalTime().ToString('o')
            "$ts Wait-Process failed for PID=$pid - $_" | Out-File -FilePath $log -Append -Encoding UTF8
        }
    } -ArgumentList $proc.Id,$exitLog | Out-Null
}

function Start-AgentDetached {
    Push-Location (Join-Path -Path ([string]$PSScriptRoot) -ChildPath '..\agent\SimRacingAgent')
    $cwd = (Get-Location)
    $outLog = Join-Path -Path ([string]$cwd) -ChildPath 'agent-run.log'
    $errLog = Join-Path -Path ([string]$cwd) -ChildPath 'agent-run.err'
    $proc = Start-Process -FilePath powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','.\SimRacingAgent.ps1' -WorkingDirectory $cwd -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
    Pop-Location
    Write-Host "Started agent (detached); PID=$($proc.Id); logs -> agent/SimRacingAgent/agent-run.log"
    $exitLog = Join-Path -Path ([string]$cwd) -ChildPath 'agent-exit-capture.log'
    Start-Job -Name "AgentExitWatcher_$($proc.Id)" -ScriptBlock {
        param($pid,$log)
        Try {
            Wait-Process -Id $pid -ErrorAction Stop
            $ts = (Get-Date).ToUniversalTime().ToString('o')
            "$ts ProcessExited PID=$pid" | Out-File -FilePath $log -Append -Encoding UTF8
        } Catch {
            $ts = (Get-Date).ToUniversalTime().ToString('o')
            "$ts Wait-Process failed for PID=$pid - $_" | Out-File -FilePath $log -Append -Encoding UTF8
        }
    } -ArgumentList $proc.Id,$exitLog | Out-Null
}

while ($true) {
    Clear-Host
    Write-Host "=== Process Menu: Server vs Agent ===" -ForegroundColor Cyan
    # Configurable tail polling (seconds)
    if (-not (Get-Variable -Name TailPollSeconds -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name TailPollSeconds -Scope Script -Value 30
    }

    # Show concise status at top for quick identification
    $curServer = Get-ServerProcess
    $curAgent = Get-AgentProcess
    $curServerId = Get-ProcId $curServer
    $curAgentId = Get-ProcId $curAgent
    if ($curServerId) { Write-Host "Server: running (PID=$curServerId)" -ForegroundColor Green } else { Write-Host "Server: not running" -ForegroundColor DarkYellow }
    if ($curAgentId) { Write-Host "Agent: running (PID=$curAgentId)" -ForegroundColor Green } else { Write-Host "Agent: not running" -ForegroundColor DarkYellow }
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

    $choice = (Read-Host 'Select an option').Trim().ToUpperInvariant()
        $exitMain = $false
    switch ($choice) {
        '1' {
            $sp = Get-ServerProcess
            Write-Host "\n-- Server process --" -ForegroundColor Yellow
            Show-ProcInfo $sp
            Read-Host 'Press Enter to continue'
        }
        '2' {
            Start-ServerDetached; Read-Host 'Press Enter to continue'
        }
        '3' {
            $sp = Get-ServerProcess
            $id = Get-ProcId $sp
            if ($id) { Stop-ProcById $id } else { Write-Host 'Server not found' }
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
            if ($id) { Stop-ProcById $id } else { Write-Host 'Agent not found' }
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
