# Run integration tests non-interactively, preferring an existing DB path or fallback.
param(
    [string]$DbPath = $null,
    [int]$Port = 5006,
    [switch]$NoStop,
    [switch]$PreserveDb
)

try {
    # Determine DB path: prefer provided, then env SIMRACING_DEBUG_DBPATH, then repo server DB, then artifacts fallback
    if (-not $DbPath) { $DbPath = $env:SIMRACING_DEBUG_DBPATH }
    if (-not $DbPath) {
        $repoDb = Join-Path -Path (Resolve-Path -Path .).Path -ChildPath 'server/USBDeviceManager/simracing.db'
        if (Test-Path $repoDb) { $DbPath = $repoDb }
    }
    if (-not $DbPath) { $DbPath = Join-Path -Path (Resolve-Path -Path .).Path -ChildPath 'artifacts/ci-local-simracing.db' }

    Write-Host "Using DB path: $DbPath"
    $env:SIMRACING_DEBUG_DBPATH = $DbPath
    $env:ASPNETCORE_URLS = "http://127.0.0.1:$Port"
    $env:DOTNET_ENVIRONMENT = 'Production'
    $env:NONINTERACTIVE = '1'

    # Initialize DB schema before starting server if helper is present
    $ensureProj = 'scripts/ci-init-db/EnsureDb/EnsureDb.csproj'
    if (Test-Path $ensureProj) {
            Write-Host "Running DB initializer helper: $ensureProj"
            $env:DefaultConnection = "Data Source=$DbPath"
            Write-Host "Invoking 'dotnet run' for EnsureDb (will build if necessary)"
            try {
                & dotnet run -p $ensureProj -c Release
            } catch {
                Write-Error ("DB initializer invocation failed: {0}" -f $_)
                exit 1
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Error "DB initializer failed (exit $LASTEXITCODE). See logs for details."
                exit $LASTEXITCODE
            }
        Write-Host "DB initializer completed successfully."
    } else {
        Write-Host "No DB initializer helper present; relying on server EnsureCreated at startup."
    }

    # Start server using the start script and wait for it to report healthy.
    Write-Host "Starting server on port $Port using start-server-and-wait.ps1..."
    # Prefer pwsh when available on runners
    $shellExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Name
    if (-not $shellExe) { $shellExe = (Get-Command powershell -ErrorAction SilentlyContinue).Name }
    if (-not $shellExe) { Write-Error "No PowerShell executable found in PATH"; exit 1 }

    $launcherOut = 'scripts/tmp/launcher.out'
    $launcherErr = 'scripts/tmp/launcher.err'
    New-Item -Path $launcherOut -ItemType File -Force | Out-Null
    New-Item -Path $launcherErr -ItemType File -Force | Out-Null

    $startArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/start-server-and-wait.ps1','-Port',$Port,'-TimeoutSec','60')
    $launcher = Start-Process -FilePath $shellExe -ArgumentList $startArgs -WorkingDirectory (Resolve-Path -Path .).Path -RedirectStandardOutput $launcherOut -RedirectStandardError $launcherErr -PassThru
    Write-Host "Launched start-server-and-wait (pid $($launcher.Id)); waiting for it to complete readiness checks..."
    $finished = $launcher.WaitForExit(180000) # wait up to 3 minutes for readiness script to exit
    if (-not $finished) {
        Write-Host "start-server-and-wait did not exit within expected time; printing launcher logs and continuing to check for server pid..."
        if (Test-Path $launcherOut) { Get-Content $launcherOut -Tail 200 }
        if (Test-Path $launcherErr) { Get-Content $launcherErr -Tail 200 }
    }

    # Read server pid written by start-server-and-wait for later graceful stop
    $pidFile = 'scripts/tmp/server.pid'
    $serverPid = $null
    if (Test-Path $pidFile) { try { $serverPid = Get-Content $pidFile -ErrorAction Stop } catch { $serverPid = $null } }
    if ($serverPid) { Write-Host "Server process id recorded: $serverPid" } else { Write-Host "No server.pid found; server pid unknown." }

    # Run integration tests and save TRX
    $trx = 'artifacts/integration.trx'
    Write-Host "Running integration tests; TRX -> $trx"
    dotnet test USBDeviceManager.sln --filter Category=Integration -v minimal --logger "trx;LogFileName=$trx"
    $exit = $LASTEXITCODE

    # Attempt to stop the server gracefully if we recorded a pid (unless -NoStop)
    if ($serverPid) {
        if ($NoStop) {
            Write-Host "Skipping server stop due to -NoStop flag (pid $serverPid still running)."
        } else {
            try {
                Write-Host "Invoking stop-server.ps1 for pid $serverPid..."
                $stopScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'stop-server.ps1'
                if (Test-Path $stopScript) {
                    & $stopScript -TargetPid $serverPid
                } else {
                    Write-Host "stop-server.ps1 not found; falling back to direct Stop-Process"
                    Stop-Process -Id $serverPid -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    if (Get-Process -Id $serverPid -ErrorAction SilentlyContinue) {
                        Write-Host "Server process still running; forcing stop..."
                        Stop-Process -Id $serverPid -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch { Write-Verbose "Error stopping server process: $_" }
        }
    }

    # On failure copy DB for inspection after server has stopped
    function Safe-Preserve-Db {
        param(
            [string]$Source,
            [string]$DestBase = 'artifacts/ci-local-simracing-on-failure'
        )
        if (-not (Test-Path $Source -PathType Leaf)) {
            Write-Host "Source DB not found: $Source; skipping preservation."
            return 1
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $DestBase) | Out-Null
        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        if ($serverPid) { $pidFrag = $serverPid } else { $pidFrag = $PID }
        $finalName = "$DestBase.$ts.pid$pidFrag.db"
        $tmpName = "$finalName.tmp.$([guid]::NewGuid().ToString()).partial"
        try {
            Write-Host "Preserving DB: copying $Source -> $tmpName"
            Copy-Item -Path $Source -Destination $tmpName -Force -ErrorAction Stop
            # Preserve timestamps
            $srcInfo = Get-Item -LiteralPath $Source -ErrorAction SilentlyContinue
            if ($srcInfo) {
                $dstInfo = Get-Item -LiteralPath $tmpName -ErrorAction SilentlyContinue
                if ($dstInfo) {
                    $dstInfo.CreationTime = $srcInfo.CreationTime
                    $dstInfo.LastWriteTime = $srcInfo.LastWriteTime
                }
            }
            Move-Item -Path $tmpName -Destination $finalName -Force -ErrorAction Stop
            Write-Host "DB preserved to $finalName"
            return 0
        } catch {
            Write-Host "Failed to preserve DB: $($_.Exception.Message)"
            try { Remove-Item -Path $tmpName -ErrorAction SilentlyContinue } catch {}
            return 2
        }
    }

    if ($exit -ne 0) {
        Write-Host "Tests failed (exit $exit). Attempting to preserve DB for inspection..."
        # If PreserveDb requested, attempt preservation even if server still running (copy may fail if locked)
        $presRc = Safe-Preserve-Db -Source $DbPath -DestBase 'artifacts/ci-local-simracing-on-failure'
        if ($presRc -ne 0) { 
            Write-Host "Preservation returned code $presRc; attempting fallback copy to artifacts/ci-local-simracing-on-failure.db"; 
            Copy-Item -Path $DbPath -Destination 'artifacts/ci-local-simracing-on-failure.db' -Force -ErrorAction SilentlyContinue 
        }
    }

    if ($NoStop -and -not $PreserveDb -and $serverPid) {
        Write-Host "Note: server process $serverPid left running (NoStop). Manually stop with Stop-Process -Id $serverPid or run scripts/stop-server.ps1 -Pid $serverPid when finished."
    }

    # Generate an integration report if helper exists (non-fatal)
    $reportScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'generate-integration-test.ps1'
    if (Test-Path $reportScript) {
        Write-Host "Generating integration test report via $reportScript"
        try {
            & $reportScript -TrxPath $trx -LauncherOut $launcherOut -LauncherErr $launcherErr -ArtifactDir 'artifacts' -OutReport 'artifacts/integration-test-report.txt' -OutHtml 'artifacts/integration-test-report.html'
        } catch {
            Write-Host "generate-integration-test.ps1 failed: $($_.Exception.Message)"
        }
    }

    # Always attempt to copy logs and pipeline files into `artifacts/` so workflow uploads capture them
    try {
        New-Item -ItemType Directory -Force -Path artifacts | Out-Null
        if (Test-Path 'scripts/tmp') { Copy-Item -Path 'scripts/tmp/*' -Destination 'artifacts' -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path '.github/workflows') { New-Item -ItemType Directory -Force -Path 'artifacts/pipeline-configuration' | Out-Null; Copy-Item -Path '.github/workflows/*' -Destination 'artifacts/pipeline-configuration' -Recurse -Force -ErrorAction SilentlyContinue }
    } catch { Write-Host "Warning: failed to copy logs to artifacts: $($_.Exception.Message)" }

} finally {
    # Ensure the server is stopped at the end of the run unless caller explicitly requested NoStop.
    try {
        if ($NoStop) { Write-Host "NoStop specified; skipping final ensure-server-stopped call." }
        else {
            $ensureScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'ensure-server-stopped.ps1'
            if (Test-Path $ensureScript) {
                Write-Host "Running ensure-server-stopped to clean up any stray server processes..."
                try { & $ensureScript } catch { Write-Warning ("ensure-server-stopped invocation failed: {0}" -f $_) }
            } else {
                Write-Host "ensure-server-stopped helper not present; no final cleanup performed."
            }
        }
    } catch { Write-Warning ("Error during final cleanup: {0}" -f $_) }
}

exit $exit
