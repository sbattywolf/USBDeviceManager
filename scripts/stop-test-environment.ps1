param(
    [switch]$Force
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"

if (-not (Test-Path $tmpDir)) { Write-Host "No tmp directory, nothing to stop."; exit 0 }

Get-ChildItem -Path $tmpDir -Filter "*.pid" -ErrorAction SilentlyContinue | ForEach-Object {
    $pidText = (Get-Content $_.FullName) -as [string]
    if (-not [string]::IsNullOrWhiteSpace($pidText)) {
        $pidValue = 0
        if ([int]::TryParse($pidText.Trim(), [ref]$pidValue)) {
            if (Get-Process -Id $pidValue -ErrorAction SilentlyContinue) {
                try {
                    Write-Host "Stopping process $pidValue (file: $($_.Name))"
                    Stop-Process -Id $pidValue -Force
                } catch {
                    Write-Warning ("Failed to stop process {0}: {1}" -f $pidValue, $_)
                }
            } else {
                Write-Host "No running process for pid file: $($_.Name)"
            }
        } else {
            Write-Warning "Invalid PID in file $($_.Name): $pidText"
        }
    } else {
        Write-Host "Empty pid file: $($_.Name)"
    }
    Remove-Item $_.FullName -ErrorAction SilentlyContinue
}

Write-Host "Teardown complete."
exit 0
