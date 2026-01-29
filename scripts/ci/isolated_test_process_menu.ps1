<#
Isolated test harness for scripts\process-menu.ps1
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\isolated_test_process_menu.ps1
#>
param(
    [string[]]$Inputs = @('0'),
    [string]$OutLog = '.\artifacts\process-menu-test.log',
    [switch]$Mock
)

$script = (Resolve-Path -Path '.\scripts\process-menu.ps1').Path
$tempDir = [System.IO.Path]::GetTempPath()
$guid = [System.Guid]::NewGuid().ToString()
$inputsFile = Join-Path $tempDir ("process_menu_inputs_$guid.json")
$wrapperFile = Join-Path $tempDir ("process_menu_wrapper_$guid.ps1")

# Ensure artifacts dir exists
$artifactsDir = Resolve-Path -Path '.\artifacts' -ErrorAction SilentlyContinue
if (-not $artifactsDir) { New-Item -Path '.\artifacts' -ItemType Directory -Force | Out-Null }

# Write inputs JSON
$Inputs | ConvertTo-Json | Out-File -FilePath $inputsFile -Encoding UTF8

# Build a one-liner command that sets the env var and invokes the main script
$envSet = "`$env:PROCESS_MENU_TEST_INPUTS_FILE = '$inputsFile'"
if ($Mock) { $envSet = "$envSet; `$env:PROCESS_MENU_MOCK = '1'" }
$cmd = "& { $envSet; & '$script' }"

# Run the command in a separate PowerShell process, redirect output to log
if (Test-Path $OutLog) { Remove-Item -Path $OutLog -Force }
# Workaround for PS versions that don't allow redirecting stdout+stderr to same file
$outStd = "$OutLog.stdout"
$outErr = "$OutLog.stderr"
$proc = Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd) -RedirectStandardOutput $outStd -RedirectStandardError $outErr -NoNewWindow -Wait -PassThru
# Merge outputs
if (Test-Path $outStd) { Get-Content $outStd | Out-File -FilePath $OutLog -Encoding UTF8 }
if (Test-Path $outErr) { Get-Content $outErr | Out-File -FilePath $OutLog -Encoding UTF8 -Append }
Remove-Item -Path $outStd -ErrorAction SilentlyContinue
Remove-Item -Path $outErr -ErrorAction SilentlyContinue

Write-Host "Process exited with code $($proc.ExitCode). Log: $OutLog"

# Simple assertion in mock mode: if Inputs contained '2' (start) then expect server log to include MOCK start entry
if ($Mock -and ($Inputs -contains '2')) {
    $serverLog = Resolve-Path -Path '.\server\USBDeviceManager\server.log' -ErrorAction SilentlyContinue
    if (-not $serverLog) { Write-Host '[ASSERTION FAILED] server.log not created' } else {
        $tail = Get-Content -Path $serverLog -Tail 20 -ErrorAction SilentlyContinue
        if ($tail -match 'MOCK Start-ServerDetached') { Write-Host '[ASSERTION PASSED] mock server-start recorded' } else { Write-Host '[ASSERTION FAILED] mock server-start not found in server.log' }
    }
}

# Show the log tail
if (Test-Path $OutLog) {
    Write-Host '---- Test log ----'
    Get-Content -Path $OutLog -Tail 200 | ForEach-Object { Write-Host $_ }
} else {
    Write-Host '(no log found)'
}

# Cleanup temp files
Remove-Item -Path $inputsFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $wrapperFile -Force -ErrorAction SilentlyContinue

Write-Host 'Isolated test complete.'
