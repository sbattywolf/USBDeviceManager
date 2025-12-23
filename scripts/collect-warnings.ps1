param(
    [string]$Sln = 'USBDeviceManager.sln'
)

Write-Output "Building solution: $Sln (Release) and collecting warnings..."
dotnet build $Sln -c Release -nologo 2>&1 | Tee-Object artifacts\build_full.log

$lines = Select-String -Path artifacts\build_full.log -Pattern 'warning' | ForEach-Object { $_.Line }
$items = foreach ($l in $lines) {
    if ($l -match 'warning\s+([A-Z0-9]+)\b') { [PSCustomObject]@{Rule=$matches[1];Line=$l} } else { [PSCustomObject]@{Rule='GENERAL';Line=$l} }
}

if (Test-Path artifacts\grouped-warnings.txt) { Remove-Item artifacts\grouped-warnings.txt -Force }

$items | Group-Object Rule | ForEach-Object {
    $h = $_.Name + ' (' + $_.Count + ')'
    $h | Out-File artifacts\grouped-warnings.txt -Append
    ($_.Group | ForEach-Object { $_.Line }) | Out-File artifacts\grouped-warnings.txt -Append
    '' | Out-File artifacts\grouped-warnings.txt -Append
}

Write-Output "Grouped warnings saved to artifacts\grouped-warnings.txt"
