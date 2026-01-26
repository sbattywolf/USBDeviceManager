param(
    [switch]$Force
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"

if (-not (Test-Path $tmpDir)) { Write-Host "No tmp directory, nothing to stop."; exit 0 }

Get-ChildItem -Path $tmpDir -Filter "*.pid" -ErrorAction SilentlyContinue | ForEach-Object {
    $pidText = (Get-Content $_.FullName) -join "`n"
    $pidTrim = $pidText.Trim()
    if ($pidTrim -and [int]::TryParse($pidTrim, [ref]$null) -and (Get-Process -Id $pidTrim -ErrorAction SilentlyContinue)) {
        try {
            Write-Host "Stopping process $pidTrim (file: $($_.Name))"
            Stop-Process -Id $pidTrim -Force
        } catch {
            Write-Warning ('Failed to stop process {0}: {1}' -f $pidTrim, $_)
        }
    } else {
        Write-Host "No running process for pid file: $($_.Name)"
    }
    Remove-Item $_.FullName -ErrorAction SilentlyContinue
}

Write-Host "Teardown complete."
exit 0
