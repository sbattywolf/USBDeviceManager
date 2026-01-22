param(
    [switch]$Force
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"

if (-not (Test-Path $tmpDir)) { Write-Host "No tmp directory, nothing to stop."; exit 0 }

Get-ChildItem -Path $tmpDir -Filter "*.pid" -ErrorAction SilentlyContinue | ForEach-Object {
    $pid = Get-Content $_.FullName
    if ($pid -and (Get-Process -Id $pid -ErrorAction SilentlyContinue)) {
        try {
            Write-Host "Stopping process $pid (file: $($_.Name))"
            Stop-Process -Id $pid -Force
        } catch {
            Write-Warning "Failed to stop process $pid: $_"
        }
    } else {
        Write-Host "No running process for pid file: $($_.Name)"
    }
    Remove-Item $_.FullName -ErrorAction SilentlyContinue
}

Write-Host "Teardown complete."
exit 0
