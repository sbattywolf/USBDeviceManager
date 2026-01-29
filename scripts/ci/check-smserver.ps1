param(
  [string]$SearchRoot = "",
  [string]$OutDir = "diagnostics",
  [switch]$AllowDummy
)

if ([string]::IsNullOrWhiteSpace($SearchRoot)) { $SearchRoot = (Get-Location).Path }

$found = Get-ChildItem -Path $SearchRoot -Recurse -Filter SMServer.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($found) {
  Write-Output "SMServer.exe found: $($found.FullName)"
  exit 0
} else {
  if (-not (Test-Path -Path $OutDir)) { New-Item -Path $OutDir -ItemType Directory | Out-Null }
  $report = Join-Path $OutDir "SMServer-missing.txt"
  $msg = "SMServer.exe not found under $SearchRoot`nChecked on $(Get-Date -Format o)`n"
  $msg += "Environment PATH: $($env:PATH)`n"
  $msg += "Use scripts/ci/check-smserver.ps1 -AllowDummy to create a zero-byte placeholder if desired.`n"
  $msg | Out-File -FilePath $report -Encoding utf8
  if ($AllowDummy) {
    $dummy = Join-Path $SearchRoot "SMServer.exe"
    New-Item -Path $dummy -ItemType File -Force | Out-Null
    Write-Output "Created dummy SMServer.exe at $dummy"
  }
  Write-Error "SMServer.exe not found. Diagnostic written to $report"
  exit 2
}
