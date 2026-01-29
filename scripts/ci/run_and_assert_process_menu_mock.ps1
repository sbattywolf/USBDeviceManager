# Run both server and agent mock auto-actions, generate pids from marker, assert results, and save logs
Set-StrictMode -Version Latest

 $log = 'scripts/ci/process-menu-mock-run.log'
 # Use a run-unique temp log to avoid concurrent-writers locking the final log
 $tmpLog = "$log.$([guid]::NewGuid().ToString()).tmp"
 Remove-Item -Force -ErrorAction SilentlyContinue $tmpLog
 Remove-Item -Force -ErrorAction SilentlyContinue $log

# Publish the tmp log path so external launchers can detect where this run will write
$lastTmpFile = 'scripts/ci/last_run_tmp_log.txt'
try { Set-Content -Path $lastTmpFile -Value $tmpLog -Encoding UTF8 -Force } catch {}

function Invoke-RunAction([string]$action) {
    Write-Host "Running action $action"
    # Capture output to avoid multiple processes writing the same log concurrently
    $out = & .\scripts\ci\run_process_menu_once.ps1 -Action $action 2>&1 | Out-String
    Add-Content -Path $tmpLog -Value $out -Encoding UTF8
    Write-Host $out
}

# Run server then agent
Invoke-RunAction 2
Invoke-RunAction 6

# Generate pid files from marker
Write-Host 'Generating pid files from marker'
$out = & .\scripts\ci\make_pids_from_marker.ps1 2>&1 | Out-String
Add-Content -Path $tmpLog -Value $out -Encoding UTF8
Write-Host $out

# Run assertions
Write-Host 'Running assertions (both)'
$out = powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\assert_process_menu_mock_results.ps1 -Role both 2>&1 | Out-String
Add-Content -Path $tmpLog -Value $out -Encoding UTF8
Write-Host $out
$exit = $LASTEXITCODE
try {
    if (Test-Path $tmpLog) {
        # If the canonical log already exists (e.g. created by a concurrent runner or by Tee-Object),
        # append the tmp log content to it and remove the tmp file to avoid Move-Item races.
        if (Test-Path $log) {
            $content = Get-Content -Path $tmpLog -Raw -ErrorAction SilentlyContinue
            if ($content) { Add-Content -Path $log -Value $content -Encoding UTF8 -ErrorAction SilentlyContinue }
            Remove-Item -Path $tmpLog -Force -ErrorAction SilentlyContinue
        } else {
            Move-Item -Path $tmpLog -Destination $log -Force
        }
    }
} catch {
    Write-Host "Warning: failed to publish tmp log into place: $_" -ForegroundColor Yellow
}
if ($exit -ne 0) {
    Write-Host "Assertions failed (exit $exit). See $log" -ForegroundColor Red
    exit $exit
}
Write-Host "Assertions passed; output saved to $log" -ForegroundColor Green
exit 0
