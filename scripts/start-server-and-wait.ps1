param(
    [string]$ProjectPath = "server/USBDeviceManager",
    [int]$Port = 5000,
    [int]$TimeoutSec = 180,
    [switch]$NoBuild,
    [string]$Configuration = 'Release'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

# Load shared utilities (safe date parsing, etc.) if available
$utilsPath = Join-Path $scriptDir 'utils.ps1'
if (Test-Path $utilsPath) { . $utilsPath }

# Prefer explicit IPv4 loopback binding to avoid localhost IPv6/IPv4
# resolution differences on CI runners. Can be overridden with env var
# `CI_BIND_ADDRESS` if necessary.
$bindAddress = $Env:CI_BIND_ADDRESS
if ([string]::IsNullOrWhiteSpace($bindAddress)) { $bindAddress = '127.0.0.1' }

$WriteHostMsg = "Starting server project: $ProjectPath on port $Port (binding: $bindAddress)"
Write-Host $WriteHostMsg

# Helper to check whether a TCP port is currently in use on this machine
function Test-PortInUse {
    param([int]$p)
    try {
        $listeners = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
        return ($listeners | Where-Object { $_.Port -eq $p }).Count -gt 0
    } catch {
        return $false
    }
}

# If the requested port is already in use, choose a random ephemeral port instead
$initialPort = $Port
if (Test-PortInUse -p $Port) {
    Write-Host "Port $Port is in use; selecting an ephemeral port."
    $maxAttempts = 8
    for ($i = 0; $i -lt $maxAttempts; $i++) {
        $candidate = Get-Random -Minimum 15000 -Maximum 65000
        if (-not (Test-PortInUse -p $candidate)) { $Port = $candidate; break }
    }
    Write-Host "Using port $Port (initial requested: $initialPort)"
}

$dotnetArgs = "run --project `"$ProjectPath`" --configuration $Configuration --urls http://$($bindAddress):$Port"
if ($NoBuild) { $dotnetArgs += ' --no-build' }

$outFile = Join-Path $tmpDir "server.log"
$errFile = Join-Path $tmpDir "server.err.log"

# Ensure log files exist so CI artifact upload can pick them up even if the
# process exits quickly and Start-Process hasn't flushed output yet. If the
# files are already present and locked by a running process, leave them alone.
if (-not (Test-Path $outFile)) { New-Item -Path $outFile -ItemType File -Force | Out-Null }
# Note: no placeholder files created here to avoid leaving temporary artifacts in CI.
if (-not (Test-Path $errFile)) { New-Item -Path $errFile -ItemType File -Force | Out-Null }

# Attempt to start the server with guarded retries if it exits immediately.
$maxStartAttempts = 3
$startAttempt = 0
$backoffSeconds = 2
$proc = $null

while ($startAttempt -lt $maxStartAttempts) {
    try {
        $startAttempt++
        # If caller requested NoBuild, ensure a runnable exe is available.
        # Some CI publishes RID outputs under win-x64/SMServer.exe; copy it
        # into the framework root if the test harness expects net8.0/SMServer.exe.
        if ($NoBuild) {
            $exeRoot = Join-Path $PWD.Path "server/USBDeviceManager/bin/Release/net8.0/SMServer.exe"
            $exeRid = Join-Path $PWD.Path "server/USBDeviceManager/bin/Release/net8.0/win-x64/SMServer.exe"
            if (-not (Test-Path $exeRoot) -and (Test-Path $exeRid)) {
                try {
                    Copy-Item -Path $exeRid -Destination $exeRoot -Force
                    Write-Host "Copied RID exe to framework root: $exeRid -> $exeRoot"
                } catch {
                    Write-Warning ("Failed to copy RID exe from {0} to {1}: {2}" -f $exeRid, $exeRoot, $_)
                }
            }
        }

        $startArgs = $dotnetArgs
        # If caller requested NoBuild and a built DLL exists, prefer running the built DLL
        $builtDll = Join-Path $PWD.Path "server/USBDeviceManager/bin/Release/net8.0/USBDeviceManager.dll"
        if ($NoBuild -and (Test-Path $builtDll)) {
            $startArgs = "`"$builtDll`" --urls http://$($bindAddress):$Port"
            Write-Host "Launching built DLL: dotnet $startArgs (attempt $startAttempt/$maxStartAttempts)"
            $proc = Start-Process -FilePath dotnet -ArgumentList $startArgs -WorkingDirectory $PWD.Path -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru
        } else {
            Write-Host "Launching: dotnet $startArgs (attempt $startAttempt/$maxStartAttempts)"
            $proc = Start-Process -FilePath dotnet -ArgumentList $startArgs -WorkingDirectory $PWD.Path -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru
        }
        Set-Content -Path (Join-Path $tmpDir "server.pid") -Value $proc.Id
        Write-Host "Server started (pid $($proc.Id)), waiting for health..."

        # Give the server a short moment to detect immediate exits (allow a bit longer for slow CI hosts)
        Start-Sleep -Seconds 10
        $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if (-not $p) {
            Write-Host "Server process $($proc.Id) terminated quickly on attempt $startAttempt. Capturing logs and retrying if attempts remain."
            if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
            if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
            if ($startAttempt -lt $maxStartAttempts) {
                Write-Host "Retrying start after $backoffSeconds seconds..."
                Start-Sleep -Seconds $backoffSeconds
                $backoffSeconds = [math]::Min(30, $backoffSeconds * 2)
                continue
            } else {
                Write-Error "Server failed to stay alive after $maxStartAttempts attempts."
                exit 1
            }
        }
        # If we get here the process is alive; break out of retry loop
        break
    } catch {
        Write-Error ("Failed to start server process on attempt {0}: {1}" -f $startAttempt, $_)
        if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
        if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
        if ($startAttempt -lt $maxStartAttempts) {
            Write-Host "Retrying after $backoffSeconds seconds..."
            Start-Sleep -Seconds $backoffSeconds
            $backoffSeconds = [math]::Min(30, $backoffSeconds * 2)
            continue
        } else {
            Write-Error "Exhausted start attempts ($maxStartAttempts). Aborting."
            exit 1
        }
    }
}

# Give the server a short moment; if it exits immediately capture output
# early so diagnostics are available in CI artifacts. Keep this small because
# guarded start loop already performs a longer initial wait.
Start-Sleep -Seconds 1
try {
    $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
} catch { $p = $null }
if (-not $p) {
    Write-Error "Server process $($proc.Id) terminated early; printing available logs to console."
    if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
    if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
    exit 1
}

# Wait for an explicit Kestrel/readiness marker in the stdout log before starting active health checks.
# This helps differentiate between a process that's alive but not yet bound, vs one that failed to bind.
$readinessMarkers = @('Now listening on','[DIAG] ApplicationStarted','Application started','USB Device Manager Server starting...')
$markerFound = $false
$readStart = Get-Date
# Allow CI override via env var CI_READINESS_MARKER_TIMEOUT (seconds).
$envTimeout = $Env:CI_READINESS_MARKER_TIMEOUT
if ($envTimeout -and ([int]::TryParse($envTimeout,[ref]$null))) { $markerTimeout = [int]$envTimeout } else { $markerTimeout = [int][math]::Min($TimeoutSec, 120) }
Write-Host "Waiting up to ${markerTimeout}s for server readiness markers in $outFile"
while (((Get-Date) - $readStart).TotalSeconds -lt $markerTimeout) {
    try {
        if (Test-Path $outFile) {
            $tail = Get-Content $outFile -Tail 200 -ErrorAction SilentlyContinue | Out-String
            foreach ($m in $readinessMarkers) {
                if ($tail -match [regex]::Escape($m)) { $markerFound = $true; break }
            }
            if ($markerFound) { break }
            # also fail fast if stderr contains obvious fatal errors
            if (Test-Path $errFile) {
                $errTail = Get-Content $errFile -Tail 200 -ErrorAction SilentlyContinue | Out-String
                if ($errTail -match 'fail:|Unhandled exception|Exception') {
                    Write-Error "Detected possible fatal error in stderr while waiting for readiness marker." 
                    Write-Host '--- server.err (tail 500) ---'; Get-Content $errFile -Tail 500
                    break
                }
            }
        }
    } catch {
        # swallow transient read errors
    }
    Start-Sleep -Seconds 1
}
if ($markerFound) { Write-Host 'Readiness marker found in server logs; proceeding to health poll.' } else { Write-Host "No explicit readiness marker found after ${markerTimeout}s; proceeding to health polling (health checks will provide final verdict)." }

# Invoke health check with defensive diagnostics; catch parameter binding errors
$healthUrl = "http://$($bindAddress):$Port/api/health"
try {
    # Invoke poll-health in a fresh shell process (prefer 'pwsh', fall back to 'powershell')
    $shellExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Name
    if (-not $shellExe) { $shellExe = (Get-Command powershell -ErrorAction SilentlyContinue).Name }
    if (-not $shellExe) { throw "Neither 'pwsh' nor 'powershell' found in PATH" }
    Write-Host "Invoking poll-health.ps1 using shell: $shellExe"
    & $shellExe -NoProfile -ExecutionPolicy Bypass -File "$scriptDir/poll-health.ps1" -Url $healthUrl -TimeoutSec $TimeoutSec
    $phExit = $LASTEXITCODE
} catch {
    Write-Error "Exception while invoking poll-health.ps1: $($_.Exception.Message)"
    if ($_.Exception -is [System.Management.Automation.ParameterBindingException]) {
        Write-Error "Parameter binding failure details: $($_.Exception | Out-String)"
    }
    Write-Host "Dumping environment and recent logs to help triage:"
    Write-Host "Health URL: $healthUrl"
    Write-Host "Process Id: $($proc.Id)"
    Write-Host "Invocation: $($MyInvocation.Line)"
    Write-Host '--- env vars (selected) ---'
        'CI_BIND_ADDRESS','TEST_PORT','GITHUB_RUN_ID' | ForEach-Object {
            $name = $_
            $val = [System.Environment]::GetEnvironmentVariable($name)
            Write-Host ("{0} = {1}" -f $name, $val)
        }
    if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
    if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
    exit 1
}

if ($phExit -ne 0) {
    Write-Error "Server did not become healthy within timeout ($TimeoutSec seconds). Printing available logs to console."
    if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
    if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
    exit 1
}

Write-Host "Server healthy and ready: http://$($bindAddress):$Port"
exit 0
