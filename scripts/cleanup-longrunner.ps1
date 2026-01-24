param(
    [switch]$RemoveArtifacts = $false
)

Write-Host "Stopping LongRunner processes..."
Get-Process -Name 'LongRunner*' -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction Stop; Write-Host "Stopped PID $($_.Id) ($($_.ProcessName))" }
    catch { Write-Warning "Failed to stop PID $($_.Id): $_" }
}

if ($RemoveArtifacts) {
    $p = Join-Path -Path $PSScriptRoot -ChildPath 'ReproWin32\server\USBDeviceManager.Tests\bin\Debug\net8.0\artifacts\longrunner'
    if (Test-Path $p) {
        Write-Host "Removing artifacts at: $p"
        try { Remove-Item -Path $p -Recurse -Force -ErrorAction Stop; Write-Host 'Artifacts removed.' }
        catch { Write-Warning "Failed to remove artifacts: $_" }
    }
    else { Write-Host "Artifacts path not found: $p" }
}

Write-Host "Cleanup complete."
