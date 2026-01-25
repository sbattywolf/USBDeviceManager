param(
    [string]$ProjectPath = "server/USBDeviceManager",
    [int]$Port = 5000,
    [int]$TimeoutSec = 180,
    [switch]$NoBuild,
    [switch]$NonInteractive,
    [string]$Configuration = 'Release'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

# Try to stop any stray server processes early so builds and ports are free.
# Uses `scripts/ensure-server-stopped.ps1` which respects AUTO_KILL and writes a log.
$ensureScript = Join-Path $scriptDir 'ensure-server-stopped.ps1'
if (Test-Path $ensureScript) {
    Write-Host "Running ensure-server-stopped helper to stop stray server processes..."
    try {
        & $ensureScript
        if ($LASTEXITCODE -eq 2) { Write-Warning "ensure-server-stopped returned 2 (AUTO_KILL=false); skipping automatic kill." }
    } catch {
        Write-Warning ("Invocation of ensure-server-stopped failed: {0}" -f $_)
    }
} else {
    Write-Host "ensure-server-stopped helper not found; skipping stray-server cleanup."
}

# Root of the repo/workspace where CI places artifacts; used for locating build outputs
$rootPath = (Resolve-Path .)[0].Path
if (-not $rootPath) {
    Write-Error "Failed to resolve repository root path; cannot continue."
    exit 1
}

# Copy publish outputs (if any) into artifacts for better forensic bundles.
try {
    $publishBase = Join-Path $rootPath 'server/USBDeviceManager/bin/Release/net8.0'
    if (Test-Path $publishBase) {
        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        $destPublish = Join-Path $rootPath "artifacts/publish-$ts"
        New-Item -ItemType Directory -Path $destPublish -Force | Out-Null
        Get-ChildItem -Path $publishBase -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $src = $_.FullName
            $dst = Join-Path $destPublish $_.Name
            try {
                Copy-Item -Path $src -Destination $dst -Recurse -Force -ErrorAction Stop
                Write-Host "Copied publish subfolder to artifacts: $dst"
            } catch {
                Write-Warning ("Failed copying publish subfolder {0}: {1}" -f $src, $_)
            }
        }
        # Also copy top-level publish folder if present
        $topPublish = Join-Path $publishBase 'publish'
        if (Test-Path $topPublish) {
            $dstTop = Join-Path $destPublish 'publish'
            try {
                Copy-Item -Path $topPublish -Destination $dstTop -Recurse -Force -ErrorAction Stop
                Write-Host "Copied top-level publish to artifacts: $dstTop"
            } catch {
                Write-Warning ("Failed copying top-level publish {0}: {1}" -f $topPublish, $_)
            }
        }
    }
} catch {
    Write-Warning ("Error while copying publish outputs into artifacts: {0}" -f $_)
}

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
        if ($NoBuild) {
            $rootPath = (Resolve-Path .)[0].Path
            $exeRoot = Join-Path $rootPath "server/USBDeviceManager/bin/Release/net8.0/SMServer.exe"
            $exeRid = Join-Path $rootPath "server/USBDeviceManager/bin/Release/net8.0/win-x64/SMServer.exe"
            if ((-not (Test-Path $exeRoot)) -and (Test-Path $exeRid)) {
                try {
                    Copy-Item -Path $exeRid -Destination $exeRoot -Force
                    Write-Host "Copied RID exe to framework root: $exeRid -> $exeRoot"
                } catch {
                    Write-Warning ("Failed to copy RID exe from {0} to {1}: {2}" -f $exeRid, $exeRoot, $_)
                }
            }
        }

        # Decide how to launch: prefer self-contained exe, then built DLL, then `dotnet run`.
        $exeRootExe = Join-Path $rootPath "server/USBDeviceManager/bin/Release/net8.0/SMServer.exe"
        $exeRidExe = Join-Path $rootPath "server/USBDeviceManager/bin/Release/net8.0/win-x64/SMServer.exe"

        Write-Host "Diagnostics: rootPath=$rootPath"
        Write-Host "Diagnostics: exeRootExe=$exeRootExe"
        Write-Host "Diagnostics: exeRidExe=$exeRidExe"

        if ($NoBuild -and ((Test-Path $exeRidExe) -or (Test-Path $exeRootExe))) {
            $exeToRun = if (Test-Path $exeRidExe) { $exeRidExe } else { $exeRootExe }
            Write-Host "Launching self-contained exe: $exeToRun (attempt $startAttempt/$maxStartAttempts)"
            # Ensure CI packaging includes the exe for triage
            try {
                $artifactExePath = Join-Path $rootPath "artifacts/SMServer.exe"
                if ([string]::IsNullOrWhiteSpace($exeToRun)) {
                    Write-Error "exeToRun is null or empty; cannot copy or start executable (attempt $startAttempt)."
                    throw "exeToRun-empty"
                }
                if (-not (Test-Path $exeToRun)) {
                    Write-Error "exeToRun path does not exist: $exeToRun"
                    throw "exeToRun-missing"
                }
                Copy-Item -Path $exeToRun -Destination $artifactExePath -Force -ErrorAction Stop
                Write-Host "Copied server exe to artifacts: $artifactExePath"
            } catch {
                Write-Warning ("Could not copy server exe to artifacts: {0}" -f $_)
            }
            try {
                $exeArgs = @('--urls', "http://$($bindAddress):$Port")
                Write-Host "Start-Process (exe) FilePath: $exeToRun"
                Write-Host ("Arguments: " + ($exeArgs -join ' | '))
                if ([string]::IsNullOrWhiteSpace($exeToRun)) { throw "exeToRun-empty" }
                $proc = Start-Process -FilePath $exeToRun -ArgumentList $exeArgs -WorkingDirectory $rootPath -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru
            } catch {
                Write-Host '--- Start-Process Exception (exe) raw output ---'
                Write-Host ($_ | Out-String)
                if ($Error.Count -gt 0) { Write-Host ($Error[0] | Format-List * -Force | Out-String) }
                throw
            }
        } else {
            # If caller requested NoBuild and a built DLL exists, prefer running the built DLL
            $candidate1 = Join-Path $rootPath "server/USBDeviceManager/bin/Release/net8.0/SMServer.dll"
            $candidate2 = Join-Path $rootPath "server/USBDeviceManager/bin/Release/net8.0/USBDeviceManager.dll"
            $builtDllCandidates = @($candidate1, $candidate2)
            $chosenDll = $builtDllCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

            if ($NoBuild -and $chosenDll) {
                Write-Host "Diagnostics: chosenDll=$chosenDll"
                if ([string]::IsNullOrWhiteSpace($chosenDll) -or -not (Test-Path $chosenDll)) {
                    Write-Error "Chosen DLL path invalid or missing: $chosenDll"
                    throw "chosenDll-invalid"
                }
                $argsArray = @($chosenDll, '--urls', "http://$($bindAddress):$Port")
                Write-Host "Launching built DLL: dotnet with args: $([string]::Join(' ', $argsArray)) (attempt $startAttempt/$maxStartAttempts)"
                try {
                    Write-Host "Start-Process (dotnet DLL) FilePath: dotnet"
                    Write-Host ("Arguments: " + ($argsArray -join ' | '))
                    $proc = Start-Process -FilePath dotnet -ArgumentList $argsArray -WorkingDirectory $rootPath -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru
                } catch {
                    Write-Host '--- Start-Process Exception (dotnet DLL) ---'
                    Write-Host ($_ | Out-String)
                    if ($Error.Count -gt 0) { Write-Host ($Error[0] | Format-List * -Force | Out-String) }
                    if ($_.Exception) { Write-Host ('Exception.Message: {0}' -f $_.Exception.Message) }
                    if ($_.InvocationInfo) { Write-Host ('InvocationInfo: {0}' -f ($_.InvocationInfo | Out-String)) }
                    throw
                }
            } else {
                $dotnetArgsArray = @('run','--project',$ProjectPath,'--configuration',$Configuration,'--urls',"http://$($bindAddress):$Port")
                Write-Host "Launching: dotnet with args: $([string]::Join(' ', $dotnetArgsArray)) (attempt $startAttempt/$maxStartAttempts)"
                try {
                    Write-Host "Start-Process (dotnet run) FilePath: dotnet"
                    Write-Host ("Arguments: " + ($dotnetArgsArray -join ' | '))
                    if (-not $ProjectPath) { Write-Error "ProjectPath is null or empty: cannot run 'dotnet run'"; throw "projectpath-empty" }
                    $proc = Start-Process -FilePath dotnet -ArgumentList $dotnetArgsArray -WorkingDirectory $rootPath -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru
                } catch {
                    Write-Host '--- Start-Process Exception (dotnet run) ---'
                    Write-Host ($_ | Out-String)
                    if ($Error.Count -gt 0) { Write-Host ($Error[0] | Format-List * -Force | Out-String) }
                    if ($_.Exception) { Write-Host ('Exception.Message: {0}' -f $_.Exception.Message) }
                    if ($_.InvocationInfo) { Write-Host ('InvocationInfo: {0}' -f ($_.InvocationInfo | Out-String)) }
                    throw
                }
            }
        }

        Set-Content -Path (Join-Path $tmpDir "server.pid") -Value $proc.Id
        Write-Host "Server started (pid $($proc.Id)), waiting for health..."

        # Give the server a short moment to detect immediate exits (allow a bit longer for slow CI hosts)
        Start-Sleep -Seconds 10
        $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if (-not $p) {
            Write-Host "Server process $($proc.Id) terminated quickly on attempt ${startAttempt}. Capturing logs and retrying if attempts remain."
            if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
            if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
            if ($startAttempt -lt $maxStartAttempts) {
                Write-Host "Retrying start after $backoffSeconds seconds..."
                Start-Sleep -Seconds $backoffSeconds
                $backoffSeconds = [math]::Min(30, $backoffSeconds * 2)
                continue
            } else {
                Write-Error "Server failed to stay alive after ${maxStartAttempts} attempts."
                exit 1
            }
        }
        # If we get here the process is alive; break out of retry loop
        break
    } catch {
        $startEx = $_
        $startMsg = if ($startEx -and $startEx.Exception) { $startEx.Exception.Message } else { $startEx.ToString() }
        Write-Error ("Failed to start server process on attempt {0}: {1}" -f ${startAttempt}, $startMsg)
        # Dump full exception details to a timestamped file for offline inspection
        try {
            $dumpFile = Join-Path $tmpDir ("start-exception-{0}-attempt-{1}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $startAttempt)
            Set-Content -Path $dumpFile -Value ($startEx | Format-List * -Force | Out-String)
            Write-Host "Wrote start exception dump to: $dumpFile"
            if ($Error.Count -gt 0) { Add-Content -Path $dumpFile -Value "`n--- PowerShell Error[0] ---`n"; Add-Content -Path $dumpFile -Value ($Error[0] | Format-List * -Force | Out-String) }
        } catch {
            Write-Warning ("Failed to write exception dump: {0}" -f $_)
        }
        if (Test-Path $outFile) { Write-Host '--- server.out (tail 200) ---'; Get-Content $outFile -Tail 200 }
        if (Test-Path $errFile) { Write-Host '--- server.err (tail 200) ---'; Get-Content $errFile -Tail 200 }
        if ($startAttempt -lt $maxStartAttempts) {
            Write-Host "Retrying after ${backoffSeconds} seconds..."
            Start-Sleep -Seconds $backoffSeconds
            $backoffSeconds = [math]::Min(30, $backoffSeconds * 2)
            continue
        } else {
            Write-Error "Exhausted start attempts (${maxStartAttempts}). Aborting."
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
    $phEx = $_
    $phMsg = if ($phEx -and $phEx.Exception) { $phEx.Exception.Message } else { $phEx.ToString() }
    Write-Error ("Exception while invoking poll-health.ps1: {0}" -f $phMsg)
    if ($phEx.Exception -is [System.Management.Automation.ParameterBindingException]) {
        Write-Error ("Parameter binding failure details: {0}" -f ($phEx.Exception | Out-String))
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
