<#
Ensures any running USBDeviceManager process is stopped so builds can overwrite the binary.

Behavior:
- If no process is running, exits 0.
- By default will Stop-Process -Force for any matching process.
- To skip killing and instead return a non-zero status, set environment variable `AUTO_KILL` to `false`.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ensure-server-stopped.ps1

Exit codes:
  0 - no process running or killed successfully
  2 - process running but AUTO_KILL=false, skipped killing
  1 - error occurred
#>
param()

<#
Hardened ensure script:
- Detects and stops running server processes by PID, by common process names, or by executable path/commandline.
- Writes actions to `scripts/tmp/ensure-stopped.log` for debug/CI artifacts.
- Respects `AUTO_KILL=false` to skip killing (returns exit code 2).
#>

function Ensure-TempDir {
    $tmp = Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath 'tmp'
    if (-not (Test-Path $tmp)) { New-Item -ItemType Directory -Path $tmp | Out-Null }
    return $tmp
}

try {
    $tmp = Ensure-TempDir
    $log = Join-Path $tmp 'ensure-stopped.log'
    "$((Get-Date).ToString('s')) - ensure-server-stopped start" | Out-File -FilePath $log -Encoding utf8 -Append

    # Candidate process names and executable fragments to match
    $names = @('USBDeviceManager','SMServer','SMGui')
    $exeFragments = @('SMServer.exe','USBDeviceManager')

    # Gather processes by name
    $procs = @()
    try {
        $procs += Get-Process -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.ProcessName }
    } catch {
        # ignore
    }

    # Also try matching by path or main module if available
    try {
        $byPath = @()
        foreach ($pp in (Get-Process -ErrorAction SilentlyContinue)) {
            if ($pp.Path) {
                foreach ($frag in $exeFragments) {
                    if ($pp.Path -like "*$frag*") { $byPath += $pp; break }
                }
            }
        }
        if ($byPath) { $procs += $byPath }
    } catch {
        # Some platforms disallow querying Path; ignore failures
    }

    # On Windows try Win32_Process to match commandline (works in pwsh on Windows)
    if ($PSVersionTable.Platform -eq 'Win32NT') {
        try {
            $cim = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
            if ($cim) {
                $matches = $cim | Where-Object { $_.CommandLine -and ($exeFragments | ForEach-Object { $_ -and ($_.CommandLine -match [regex]::Escape($_)) }) }
                foreach ($m in $matches) {
                    try { $p = Get-Process -Id $m.ProcessId -ErrorAction SilentlyContinue; if ($p) { $procs += $p } } catch { }
                }
            }
        } catch {
            # ignore
        }
    }

    # Deduplicate
    $procs = $procs | Sort-Object -Property Id -Unique

    if (-not $procs -or $procs.Count -eq 0) {
        "$((Get-Date).ToString('s')) - No matching server processes found." | Out-File -FilePath $log -Append
        Write-Host "No running server process found."
        exit 0
    }

    $pids = $procs | ForEach-Object { $_.Id }
    "$((Get-Date).ToString('s')) - Found processes: $($pids -join ', ') - Names: $($procs | ForEach-Object { $_.ProcessName } -join ', ')" | Out-File -FilePath $log -Append

    if ($env:AUTO_KILL -and $env:AUTO_KILL -eq 'false') {
        "$((Get-Date).ToString('s')) - AUTO_KILL=false; skipping kill" | Out-File -FilePath $log -Append
        Write-Host "Server is running (PID(s): $($pids -join ', ')). AUTO_KILL=false so skipping kill.";
        exit 2
    }

    # Attempt to stop each process, with retries to let file handles release
    $maxAttempts = 5
    foreach ($p in $procs) {
        $attempt = 1
        while ($attempt -le $maxAttempts) {
            try {
                "$((Get-Date).ToString('s')) - Attempt $($attempt): Stopping PID $($p.Id) ($($p.ProcessName))" | Out-File -FilePath $log -Append
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
                Start-Sleep -Milliseconds 500
                if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) {
                    "$((Get-Date).ToString('s')) - Stopped PID $($p.Id)" | Out-File -FilePath $log -Append
                    break
                }
            } catch {
                "$((Get-Date).ToString('s')) - Stop attempt $($attempt) failed for PID $($p.Id): $_" | Out-File -FilePath $log -Append
            }
            $attempt++
            Start-Sleep -Seconds 1
        }
    }

    # Final verification
    Start-Sleep -Seconds 1
    $still = @()
    try {
        foreach ($pp in (Get-Process -ErrorAction SilentlyContinue)) {
            if ($names -contains $pp.ProcessName) { $still += $pp; continue }
            if ($pp.Path) {
                foreach ($frag in $exeFragments) { if ($pp.Path -like "*$frag*") { $still += $pp; break } }
            }
        }
    } catch {
        # ignore
    }
    if ($still -and $still.Count -gt 0) {
        "$((Get-Date).ToString('s')) - Processes still running after stop attempts: $($still | ForEach-Object { $_.Id } -join ', ')" | Out-File -FilePath $log -Append
        Write-Warning "Some server processes remain: $($still | ForEach-Object { $_.Id } -join ', ')"
        exit 1
    }

    "$((Get-Date).ToString('s')) - All matched server processes stopped successfully." | Out-File -FilePath $log -Append
    Write-Host "Server processes stopped."
    exit 0
}
catch {
    "$((Get-Date).ToString('s')) - Error in ensure-server-stopped: $_" | Out-File -FilePath $log -Append
    Write-Error "Error checking/stopping server processes: $_"
    exit 1
}
