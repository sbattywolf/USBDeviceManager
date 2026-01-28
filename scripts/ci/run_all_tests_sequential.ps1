param(
    [string] $RunId = $(Get-Date -Format "yyyyMMdd_HHmmss"),
    [switch] $DryRun,
    [int] $PublishTimeoutMinutes = 10,
    [int] $SuiteTimeoutMinutes = 30,
    [int] $E2ETimeoutMinutes = 30
)

# Directory where per-run TRX files will be stored
$root = Join-Path $PSScriptRoot "..\..\artifacts\test-results\$RunId"
New-Item -ItemType Directory -Force -Path $root | Out-Null

Write-Host "Test run id: $RunId"
Write-Host "Output directory: $root"
if ($DryRun) { Write-Host "DRY RUN: commands will be printed but not executed." }

# Initialize metrics collection early so other steps can append
$metrics = @()
$metricsCsv = Join-Path $root 'metrics.csv'
$metricsJson = Join-Path $root 'metrics.json'

function Write-MetricCSVHeader {
    param($path)
    if (-not (Test-Path $path)) {
        "Step,Start,End,DurationMs,ExitCode,CPUms,MemoryBytes,TimedOut,Notes" | Out-File -FilePath $path -Encoding utf8
    }
}
Write-MetricCSVHeader -path $metricsCsv
# Ensure a self-contained SMServer.exe is available for tests (long-term CI fix)
$publishScript = Join-Path $PSScriptRoot 'publish-smserver-selfcontained.ps1'
if (Test-Path $publishScript) {
    Write-Host "Found publish script: $publishScript"
    if ($DryRun) {
        Write-Host "DRY RUN: would publish SMServer self-contained executable using $publishScript"
    }
    else {
        Write-Host "Publishing SMServer self-contained executable... (timeout: ${PublishTimeoutMinutes}m)"
        $pubArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$publishScript)
        $pubProc = Start-Process -FilePath 'powershell' -ArgumentList $pubArgs -NoNewWindow -PassThru
        $pubTimeoutMs = $PublishTimeoutMinutes * 60 * 1000
        $pubStart = Get-Date
        $pubExited = $pubProc.WaitForExit($pubTimeoutMs)
        if (-not $pubExited) {
            try { $pubProc.Kill() } catch {}
            $pubProc.WaitForExit()
            $pubExit = $pubProc.ExitCode
            $pubExitStr = 'TimedOut'
            Write-Host "Publish step timed out after ${PublishTimeoutMinutes}m and was killed (proc id: $($pubProc.Id))." -ForegroundColor Yellow
            # Capture diagnostics
            $diagDir = Join-Path $root 'diagnostics'
            New-Item -ItemType Directory -Force -Path $diagDir | Out-Null
            dotnet --info | Out-File -FilePath (Join-Path $diagDir 'dotnet-info-publish.txt') -Encoding utf8
            Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 20 | Out-File (Join-Path $diagDir 'process-list-publish.txt') -Encoding utf8
            $pubNote = "Timed out and killed"
        }
        else {
            $pubProc.WaitForExit()
            $pubExit = $pubProc.ExitCode
            $pubExitStr = if ($pubExit -ne $null -and $pubExit -ne '') { $pubExit.ToString() } else { 'Unknown' }
            $pubNote = ""
            if ($pubExit -ne 0) { Write-Host "Publish script returned exit code $pubExit" -ForegroundColor Yellow }
        }
        $pubEnd = Get-Date
        $pubDur = (New-TimeSpan -Start $pubStart -End $pubEnd).TotalMilliseconds
        $cpuMs = 0
        $mem = 0
        try { $cpuMs = [math]::Round($pubProc.TotalProcessorTime.TotalMilliseconds,0) } catch {}
        try { $mem = $pubProc.PeakWorkingSet64 } catch {}
        if (-not $pubExitStr) { $pubExitStr = if ($pubExit -ne $null) { $pubExit.ToString() } else { 'Unknown' } }
        "Publish,$($pubStart.ToString('o')),$($pubEnd.ToString('o')),$([math]::Round($pubDur,0)),$pubExitStr,$cpuMs,$mem,$([bool](-not $pubExited)),$pubNote" | Out-File -FilePath $metricsCsv -Append -Encoding utf8
        $metrics += [pscustomobject]@{ Step = 'publish-smserver'; Start = $pubStart.ToString('o'); End = $pubEnd.ToString('o'); DurationMs = [math]::Round($pubDur,0); ExitCode = $pubExitStr; CPUms = $cpuMs; MemoryBytes = $mem; TimedOut = (-not $pubExited); Notes = $pubNote }
    }
} else { Write-Host "Publish script not present; skipping self-contained publish." }



$suites = @(
    @{ Name='Unit'; Filter='Category=Unit'; Log='unit-tests.trx' },
    @{ Name='Integration'; Filter='Category=Integration'; Log='integration-tests.trx' },
    @{ Name='Functional'; Filter='Category=Functional'; Log='functional-tests.trx' },
    @{ Name='Regression'; Filter='Category=Regression'; Log='regression-tests.trx' }
)

foreach ($s in $suites) {
    $name = $s.Name
    $filter = $s.Filter
    $log = $s.Log
    $outPath = $root
    Write-Host "\n--- Running $name tests ---"
    $cmdArgs = @('test','USBDeviceManager.sln','--configuration','Release','--logger',"trx;LogFileName=$log",'--results-directory',$outPath,'--filter',$filter)
    Write-Host ('dotnet ' + ($cmdArgs -join ' '))
    if (-not $DryRun) {
        $suiteStart = Get-Date
        $timeoutMs = $SuiteTimeoutMinutes * 60 * 1000
        $proc = Start-Process -FilePath 'dotnet' -ArgumentList $cmdArgs -NoNewWindow -PassThru
        $exited = $proc.WaitForExit($timeoutMs)
        if (-not $exited) {
            try { $proc.Kill() } catch {}
            $proc.WaitForExit()
            $exit = $proc.ExitCode
            $exitStr = 'TimedOut'
            $note = "Timed out after ${SuiteTimeoutMinutes}m and killed"
            Write-Host "Command timed out (killed) for $name tests (proc id: $($proc.Id))." -ForegroundColor Yellow
            # diagnostics
            $diagDir = Join-Path $root 'diagnostics'
            New-Item -ItemType Directory -Force -Path $diagDir | Out-Null
            dotnet --info | Out-File -FilePath (Join-Path $diagDir "dotnet-info-$name.txt") -Encoding utf8
            Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 20 | Out-File (Join-Path $diagDir "process-list-$name.txt") -Encoding utf8
            $timedOut = $true
        }
        else {
            $proc.WaitForExit()
            $exit = $proc.ExitCode
            $exitStr = if ($exit -ne $null -and $exit -ne '') { $exit.ToString() } else { 'Unknown' }
            $note = ""
            if ($exit -ne 0) { $note = "Non-zero exit"; Write-Host "Command exited with code $exit for $name tests (continuing to next suite)." -ForegroundColor Yellow }
            $timedOut = $false
        }
        $suiteEnd = Get-Date
        $dur = (New-TimeSpan -Start $suiteStart -End $suiteEnd).TotalMilliseconds
        $cpuMs = 0
        $mem = 0
        try { $cpuMs = [math]::Round($proc.TotalProcessorTime.TotalMilliseconds,0) } catch {}
        try { $mem = $proc.PeakWorkingSet64 } catch {}
        $metrics += [pscustomobject]@{ Step = "$name tests"; Start = $suiteStart.ToString('o'); End = $suiteEnd.ToString('o'); DurationMs = [math]::Round($dur,0); ExitCode = $exitStr; CPUms = $cpuMs; MemoryBytes = $mem; TimedOut = $timedOut; Notes = $note }
        "$($name) tests,$($suiteStart.ToString('o')),$($suiteEnd.ToString('o')),$([math]::Round($dur,0)),$exitStr,$cpuMs,$mem,$timedOut,$note" | Out-File -FilePath $metricsCsv -Append -Encoding utf8
    }
}

# Run E2E self-hosted wrapper (will write AgentE2E.selfhost.trx to artifacts/test-results)
Write-Host "\n--- Running E2E self-hosted wrapper ---"
$e2eCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_e2e_selfhost.ps1"
Write-Host $e2eCmd
if (-not $DryRun) {
    # Start server as a background job (prefer published DLL, fallback to EXE)
    $diagDir = Join-Path $root 'diagnostics'
    New-Item -ItemType Directory -Force -Path $diagDir | Out-Null
    $serverLog = Join-Path $diagDir 'server.log'
    $serverDll = Join-Path $PSScriptRoot '..\..\server\USBDeviceManager\bin\Release\net8.0\SMServer.dll'
    $serverExe = Join-Path $PSScriptRoot '..\..\server\USBDeviceManager\bin\Release\net8.0\SMServer.exe'
    $serverStarted = $false
    $serverJobName = 'SMServer_Run'
    try {
        $dllPath = Resolve-Path $serverDll -ErrorAction SilentlyContinue
        $exePath = Resolve-Path $serverExe -ErrorAction SilentlyContinue
        if ($dllPath) {
            Write-Host "Starting server from DLL: $($dllPath.Path) (background job: $serverJobName)"
            $job = Start-Job -Name $serverJobName -ScriptBlock {
                param($dllPath, $logFile)
                Set-Location (Split-Path $dllPath)
                dotnet $dllPath *>&1 | Out-File $logFile -Encoding utf8
            } -ArgumentList $dllPath.Path, $serverLog
            Start-Sleep -Seconds 2
            $serverStarted = $true
        }
        elseif ($exePath) {
            Write-Host "Starting server from EXE: $($exePath.Path) (background job: $serverJobName)"
            $job = Start-Job -Name $serverJobName -ScriptBlock {
                param($exePath, $logFile)
                Set-Location (Split-Path $exePath)
                & $exePath *>&1 | Out-File $logFile -Encoding utf8
            } -ArgumentList $exePath.Path, $serverLog
            Start-Sleep -Seconds 2
            $serverStarted = $true
        }
        else {
            Write-Host "No SMServer binary found at expected release paths; E2E wrapper must start or expect it." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Failed to start server job: $_" -ForegroundColor Yellow
    }

    $e2eStart = Get-Date
    # If we started the server job, do a quick health check wait before launching the wrapper to reduce races.
    if ($serverStarted) {
        $hcScript = Join-Path $PSScriptRoot 'smoke_health_check.ps1'
        if (Test-Path $hcScript) {
            Write-Host "Waiting for health endpoint before running E2E wrapper (30s)..."
            & powershell -NoProfile -ExecutionPolicy Bypass -File $hcScript -HealthUrl 'http://localhost:5000/api/configs' -TimeoutSec 30 -MetricsFile $metricsCsv
            if ($LASTEXITCODE -ne 0) { Write-Host "Health check failed before E2E wrapper (exit=$LASTEXITCODE)" -ForegroundColor Yellow }
        }
    }

    $e2eArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File','./scripts/ci/run_e2e_selfhost.ps1','-MetricsFile',$metricsCsv)
    $e2eProc = Start-Process -FilePath 'powershell' -ArgumentList $e2eArgs -NoNewWindow -PassThru
    $e2eTimeoutMs = $E2ETimeoutMinutes * 60 * 1000
    $e2eExited = $e2eProc.WaitForExit($e2eTimeoutMs)
    if (-not $e2eExited) {
        try { $e2eProc.Kill() } catch {}
        $e2eProc.WaitForExit()
        $e2eExit = $e2eProc.ExitCode
        $e2eExitStr = 'TimedOut'
        $e2eNote = "Timed out after ${E2ETimeoutMinutes}m and killed"
        Write-Host "E2E wrapper timed out and was killed (proc id: $($e2eProc.Id))." -ForegroundColor Yellow
        # diagnostics
        $diagDir = Join-Path $root 'diagnostics'
        New-Item -ItemType Directory -Force -Path $diagDir | Out-Null
        dotnet --info | Out-File -FilePath (Join-Path $diagDir 'dotnet-info-e2e.txt') -Encoding utf8
        Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 20 | Out-File (Join-Path $diagDir 'process-list-e2e.txt') -Encoding utf8
        $e2eTimedOut = $true
    }
    else {
        $e2eProc.WaitForExit()
        $e2eExit = $e2eProc.ExitCode
        $e2eExitStr = if ($e2eExit -ne $null -and $e2eExit -ne '') { $e2eExit.ToString() } else { 'Unknown' }
        $e2eNote = ""
        $e2eTimedOut = $false
    }
    $e2eEnd = Get-Date
    $e2eDur = (New-TimeSpan -Start $e2eStart -End $e2eEnd).TotalMilliseconds
    $cpuMs = 0; $mem = 0
    try { $cpuMs = [math]::Round($e2eProc.TotalProcessorTime.TotalMilliseconds,0) } catch {}
    try { $mem = $e2eProc.PeakWorkingSet64 } catch {}
    if (-not $e2eExitStr) { $e2eExitStr = if ($e2eExit -ne $null) { $e2eExit.ToString() } else { 'Unknown' } }
    $metrics += [pscustomobject]@{ Step = 'E2E self-hosted wrapper'; Start = $e2eStart.ToString('o'); End = $e2eEnd.ToString('o'); DurationMs = [math]::Round($e2eDur,0); ExitCode = $e2eExitStr; CPUms = $cpuMs; MemoryBytes = $mem; TimedOut = $e2eTimedOut; Notes = $e2eNote }
    "E2E self-hosted wrapper,$($e2eStart.ToString('o')),$($e2eEnd.ToString('o')),$([math]::Round($e2eDur,0)),$e2eExitStr,$cpuMs,$mem,$e2eTimedOut,$e2eNote" | Out-File -FilePath $metricsCsv -Append -Encoding utf8
    # copy AgentE2E TRX into run folder if present
    $e2eTrx = Join-Path (Join-Path $PSScriptRoot "..\..\artifacts\test-results") 'AgentE2E.selfhost.trx'
    if (Test-Path $e2eTrx) {
        Copy-Item $e2eTrx -Destination (Join-Path $root 'AgentE2E.selfhost.trx') -Force
    }

    # Stop the server job we started (if any) and capture logs
    if ($serverStarted) {
        try {
            Write-Host "Stopping server job: $serverJobName"
            Stop-Job -Name $serverJobName -ErrorAction SilentlyContinue
            Receive-Job -Name $serverJobName -Keep -ErrorAction SilentlyContinue | Out-File (Join-Path $diagDir 'server.job.output.txt') -Encoding utf8
            Get-Job -Name $serverJobName | Remove-Job -ErrorAction SilentlyContinue
            Write-Host "Server logs: $serverLog"
            # record netstat snapshot
            netstat -a -n -o | Select-String ':5000|:5006' | Out-File (Join-Path $diagDir 'netstat_ports_after_e2e.txt')
        } catch {
            Write-Host "Error stopping server job: $_" -ForegroundColor Yellow
        }
    }
}

# Merge TRX files from this run using repository merge_trx.py if available
$mergePy = Join-Path $PSScriptRoot 'merge_trx.py'
if (Test-Path $mergePy) {
    $outMerged = Join-Path $root 'all-tests.trx'
    Write-Host "\n--- Merging TRX files for run into $outMerged ---"
    Write-Host ('python ' + $mergePy + ' ' + $root + ' ' + $outMerged)
    if (-not $DryRun) {
        $mergeStart = Get-Date
        & python $mergePy $root $outMerged
        $mergeEnd = Get-Date
        $mergeDur = (New-TimeSpan -Start $mergeStart -End $mergeEnd).TotalMilliseconds
        $mergeExit = $LASTEXITCODE
        $mergeExitStr = if ($mergeExit -ne $null -and $mergeExit -ne '') { $mergeExit.ToString() } else { 'Unknown' }
        if ($mergeExit -ne 0) { Write-Host "merge_trx.py returned exit code $mergeExit" -ForegroundColor Yellow }
        $metrics += [pscustomobject]@{ Step = 'merge_trx'; Start = $mergeStart.ToString('o'); End = $mergeEnd.ToString('o'); DurationMs = [math]::Round($mergeDur,0); ExitCode = $mergeExitStr; Notes = "" }
        "merge_trx,$($mergeStart.ToString('o')),$($mergeEnd.ToString('o')),$([math]::Round($mergeDur,0)),$mergeExitStr," | Out-File -FilePath $metricsCsv -Append -Encoding utf8
    }
} else {
    Write-Host "merge_trx.py not found in scripts/ci; skipping merge." -ForegroundColor Yellow
}

Write-Host "\nRun complete. TRX artifacts are in: $root"
if ($DryRun) { Write-Host "(Dry run finished)" }

# Write summary JSON of collected metrics
if (-not $DryRun) {
    $metrics | ConvertTo-Json -Depth 5 | Out-File -FilePath $metricsJson -Encoding utf8
    Write-Host "\nMetrics written to: $metricsJson and $metricsCsv"
    Write-Host "Summary of steps (DurationMs):"
    $metrics | ForEach-Object {
        $raw = $_.ExitCode
        $label = ''
        if ($raw -eq $null -or [string]::IsNullOrWhiteSpace($raw) -or $raw -eq 'Unknown') {
            $label = 'No exit code'
        }
        elseif ($raw -eq 'TimedOut') {
            $label = 'Timed out'
        }
        else {
            $asInt = 0
            $parsed = [int]::TryParse($raw, [ref]$asInt)
            if ($parsed) {
                if ($asInt -eq 0) { $label = 'Succeeded (0)' } else { $label = "Failed ($asInt)" }
            }
            else {
                $label = $raw
            }
        }
        Write-Host ("- $($_.Step): $($_.DurationMs) ms (exit=$label)")
    }
}
