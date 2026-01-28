param(
    [int]
    $Interval = 30
)

$log = '.\artifacts\scanner_watch.log'
$stateFile = '.\artifacts\scanner_watch_state.json'
$patterns = @('artifact','scan','ndjson','artifact-scan','USBDeviceManager')

function Get-MatchingProcesses {
    Get-CimInstance Win32_Process | Where-Object {
        $cmd = $_.CommandLine
        if (-not $cmd) { return $false }
        foreach ($p in $patterns) { if ($cmd -match [regex]::Escape($p)) { return $true } }
        return $false
    } | Select-Object ProcessId, Name, CommandLine, ExecutablePath
}

# initialize
if (-not (Test-Path (Split-Path $log))) { New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null }
if (-not (Test-Path $stateFile)) { '{}' | Out-File -FilePath $stateFile -Encoding utf8 }

$last = @()
try {
    $j = Get-Content -Raw -LiteralPath $stateFile | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($j -and $j.pids) { $last = $j.pids }
} catch { $last = @() }

Write-Output "Starting scanner watcher (interval ${Interval}s). Logging to $log"
"$(Get-Date -Format o) START interval=${Interval}s" | Out-File -FilePath $log -Append -Encoding utf8

while ($true) {
    $now = Get-Date -Format o
    $matches = Get-MatchingProcesses
    $pids = @($matches | Select-Object -ExpandProperty ProcessId) | Where-Object { $_ -ne $null }

    $added = $pids | Where-Object { $_ -notin $last }
    $removed = $last | Where-Object { $_ -notin $pids }

    if ($pids.Count -gt 0) {
        "$now FOUND count=$($pids.Count) pids=$($pids -join ',')" | Out-File -FilePath $log -Append -Encoding utf8
        $matches | ForEach-Object { "  PID=$($_.ProcessId) Name=$($_.Name) Path=$($_.ExecutablePath) Cmd=$($_.CommandLine)" | Out-File -FilePath $log -Append -Encoding utf8 }
    } else {
        "$now NONE" | Out-File -FilePath $log -Append -Encoding utf8
    }

    if ($added.Count -gt 0 -or $removed.Count -gt 0) {
        if ($added.Count -gt 0) {
            "${now} ADDED: $($added -join ',')" | Out-File -FilePath $log -Append -Encoding utf8
            Write-Host "Scanner watcher: ADDED $($added -join ',')" -ForegroundColor Yellow

            # For each added PID record extended info and optionally run handle.exe
            foreach ($pid in $added) {
                try {
                    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$pid"
                    if ($proc) {
                        $owner = (Invoke-CimMethod -InputObject $proc -MethodName GetOwner -ErrorAction SilentlyContinue)
                        $ownerName = if ($owner) { "$($owner.Domain)\\$($owner.User)" } else { 'UNKNOWN' }
                        $creation = $proc.CreationDate
                        $parent = $proc.ParentProcessId
                        "${now} PID_DETAIL PID=$($proc.ProcessId) Name=$($proc.Name) ParentPID=$parent CreationDate=$creation Owner=$ownerName Path=$($proc.ExecutablePath)" | Out-File -FilePath $log -Append -Encoding utf8

                        # If handle.exe is available, run it to detect open handles touching artifacts
                        $handle = (Get-Command handle.exe -ErrorAction SilentlyContinue)
                        if ($handle) {
                            try {
                                $hout = & handle.exe -p $pid 2>&1
                                $matchesHandles = $hout | Where-Object { $_ -match 'artifact|artifacts|ndjson|artifact-scan' }
                                if ($matchesHandles) {
                                    "${now} PID_HANDLES PID=$pid" | Out-File -FilePath $log -Append -Encoding utf8
                                    $matchesHandles | Out-File -FilePath $log -Append -Encoding utf8
                                } else {
                                    "${now} PID_HANDLES PID=$pid NO_MATCHES" | Out-File -FilePath $log -Append -Encoding utf8
                                }
                            } catch {
                                "${now} PID_HANDLES PID=$pid ERROR: $($_.Exception.Message)" | Out-File -FilePath $log -Append -Encoding utf8
                            }
                        } else {
                            "${now} PID_HANDLES PID=$pid SKIPPED handle.exe not found" | Out-File -FilePath $log -Append -Encoding utf8
                        }
                    } else {
                        "${now} PID_DETAIL PID=$pid NOTFOUND" | Out-File -FilePath $log -Append -Encoding utf8
                    }
                } catch {
                    "${now} PID_DETAIL PID=$pid ERROR: $($_.Exception.Message)" | Out-File -FilePath $log -Append -Encoding utf8
                }
            }
        }

        if ($removed.Count -gt 0) { "${now} REMOVED: $($removed -join ',')" | Out-File -FilePath $log -Append -Encoding utf8; Write-Host "Scanner watcher: REMOVED $($removed -join ',')" -ForegroundColor Cyan }
    }

    # persist state
    @{ pids = $pids } | ConvertTo-Json | Out-File -FilePath $stateFile -Encoding utf8
    $last = $pids

    Start-Sleep -Seconds $Interval
}
