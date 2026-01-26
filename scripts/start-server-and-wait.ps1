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
# Probe several likely publish-layouts so CI-runner variations are captured.
try {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $destPublish = Join-Path $rootPath "artifacts/publish-$ts"
    New-Item -ItemType Directory -Path $destPublish -Force | Out-Null

    $probePaths = @()
    # Common framework/publish output under project bin
    $probePaths += Join-Path $rootPath 'server/USBDeviceManager/bin/Release/net8.0'
    # Common self-contained RID folder
    $probePaths += Join-Path $rootPath 'server/USBDeviceManager/bin/Release/net8.0/win-x64'
    # Top-level publish folders that CI may create
    $probePaths += Join-Path $rootPath 'publish*'
    $probePaths += Join-Path $rootPath 'artifacts\publish*'
    $probePaths += Join-Path $rootPath 'server/USBDeviceManager\publish*'

    # Expand globs and unique directories
    $expanded = @()
    foreach ($p in $probePaths) {
        try { $expanded += (Get-ChildItem -Path $p -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) } catch { }
    }
    $expanded = $expanded | Select-Object -Unique

    foreach ($src in $expanded) {
        if (-not (Test-Path $src)) { continue }
        $name = Split-Path $src -Leaf
        $dst = Join-Path $destPublish $name
        try {
            Copy-Item -Path $src -Destination $dst -Recurse -Force -ErrorAction Stop
            Write-Host "Copied publish folder to artifacts: $dst"
        } catch {
            Write-Warning ("Failed copying publish folder {0}: {1}" -f $src, $_)
        }
        # Also attempt to copy nested 'win-*/' RID publish if present
        try {
            Get-ChildItem -Path $src -Directory -Filter 'win-*' -ErrorAction SilentlyContinue | ForEach-Object {
                $nestedDst = Join-Path $destPublish ($name + '-' + $_.Name)
                try { Copy-Item -Path $_.FullName -Destination $nestedDst -Recurse -Force -ErrorAction Stop; Write-Host "Copied nested RID publish: $nestedDst" } catch { }
            }
        } catch { }
    }
} catch {
    Write-Warning ("Error while copying publish outputs into artifacts: {0}" -f $_)
}

# Create a lightweight publish sentinel to help triage where publish outputs were found
try {
    $sentinelFile = Join-Path $rootPath 'artifacts/publish-sentinel.txt'
    $pubZip = Join-Path $rootPath 'artifacts/publish-sentinel.zip'
    $pubList = @()
    if (Test-Path $destPublish) { Get-ChildItem -Path $destPublish -Directory -ErrorAction SilentlyContinue | ForEach-Object { $pubList += $_.FullName } }
    Set-Content -Path $sentinelFile -Value ($(Get-Date -Format o) + " - publish folders:`n" + ($pubList -join "`n")) -Force
    if (Test-Path $pubZip) { Remove-Item -LiteralPath $pubZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $destPublish) { Compress-Archive -Path (Join-Path $destPublish '*') -DestinationPath $pubZip -Force -ErrorAction SilentlyContinue; Write-Host "Wrote publish sentinel zip: $pubZip" }
} catch { Write-Warning ("Failed to write publish sentinel: {0}" -f $_) }

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

                function Get-DotNetRuntimes {
                    try {
                        $out = & dotnet --list-runtimes 2>$null
                        return $out -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    } catch {
                        return @()
                    }
                }

                # If the environment lacks a compatible .NET runtime and the chosen exe appears
                # to be framework-dependent (not a RID self-contained publish), fail fast so CI
                # can capture artifacts and avoid a hung launcher waiting for readiness.
                function Ensure-RuntimeOrFail([string]$candidateExe) {
                    if (-not $candidateExe) { return }
                    $pathLower = $candidateExe.ToLower()
                    # Heuristic: if path contains a win-* RID folder it's likely self-contained
                    $isRid = ($pathLower -match "\\win-" -or $pathLower -match "-win-" -or $pathLower -match "\\publish\\win")
                    if ($isRid) { return }

                    $runtimes = Get-DotNetRuntimes
                    if (-not $runtimes -or ($runtimes -notmatch 'Microsoft\.NETCore\.App\s+8')) {
                        $msg = "No suitable .NET runtime (Microsoft.NETCore.App 8.x) detected for candidate exe: $candidateExe"
                        Write-Error $msg
                        try {
                            $dumpFile = Join-Path $tmpDir ("start-exception-no-runtime-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
                            Set-Content -Path $dumpFile -Value $msg
                            Write-Host "Wrote runtime-missing dump to: $dumpFile"
                            # Copy the candidate exe to artifacts for offline inspection
                            $artifactExePath = Join-Path $rootPath "artifacts/SMServer-no-runtime.exe"
                            if (Test-Path $candidateExe) { Copy-Item -Path $candidateExe -Destination $artifactExePath -Force -ErrorAction SilentlyContinue; Write-Host "Copied candidate exe to artifacts: $artifactExePath" }
                        } catch { }
                        throw "no-runtime-found"
                    }
                }

        if ($NoBuild -and ((Test-Path $exeRidExe) -or (Test-Path $exeRootExe))) {
            $exeToRun = if (Test-Path $exeRidExe) { $exeRidExe } else { $exeRootExe }
            Write-Host "Launching self-contained exe: $exeToRun (attempt $startAttempt/$maxStartAttempts)"
            # Ensure CI packaging includes the exe for triage
            try {
                # Fail fast if runtime missing for framework-dependent exe candidates
                try { Ensure-RuntimeOrFail -candidateExe $exeToRun } catch { 
                    # Ensure runtime check created artifacts; rethrow to abort start
                    throw
                }
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
                # Ensure Start-Process receives string arguments (avoid numeric/int tokens)
                $exeArgs = $exeArgs | ForEach-Object { $_.ToString() }
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
                # Normalize to strings to avoid parser/argument tokenization issues
                $argsArray = $argsArray | ForEach-Object { $_.ToString() }
                Write-Host "Launching built DLL: dotnet with args: $([string]::Join(' ', $argsArray)) (attempt $startAttempt/$maxStartAttempts)"
                # If dotnet runtime is missing, capture candidate exe for triage
                try {
                    $runtimes = Get-DotNetRuntimes
                    if (-not $runtimes -or ($runtimes -notmatch 'Microsoft\.NETCore\.App\s+8')) {
                        Write-Warning "dotnet runtime 8.x not detected; capturing candidate exe if present."
                        if (Test-Path $exeRootExe) { Copy-Item -Path $exeRootExe -Destination (Join-Path $rootPath 'artifacts/SMServer-no-runtime.exe') -Force -ErrorAction SilentlyContinue }
                        if (Test-Path $exeRidExe) { Copy-Item -Path $exeRidExe -Destination (Join-Path $rootPath 'artifacts/SMServer-no-runtime.exe') -Force -ErrorAction SilentlyContinue }
                    }
                } catch { }
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
                # Normalize to strings to avoid parser/argument tokenization issues
                $dotnetArgsArray = $dotnetArgsArray | ForEach-Object { $_.ToString() }
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
