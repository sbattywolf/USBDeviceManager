param(
    [string]$ServerProjectPath = "server/USBDeviceManager",
    [int]$Port = 5000,
    [string]$GuiExePath = "gui/embedded/WinFormsWebView2/bin/Release/net8.0-windows/WinFormsWebView2.exe",
    [int]$ServerTimeoutSec = 90
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "Launching server and GUI PoC"
& "$scriptDir/start-server-and-wait.ps1" -ProjectPath $ServerProjectPath -Port $Port -TimeoutSec $ServerTimeoutSec
if ($LASTEXITCODE -ne 0) { Write-Error "Server failed to start. Aborting."; exit 1 }

if (-not (Test-Path $GuiExePath)) {
    Write-Warning "GUI executable not found at $GuiExePath. Build the PoC first (dotnet build)."
    Write-Host "Server is running at http://localhost:$Port/preview/index.html"
    exit 0
}

Write-Host "Starting GUI: $GuiExePath"
$proc = Start-Process -FilePath $GuiExePath -WorkingDirectory (Split-Path $GuiExePath) -PassThru

$tmpDir = Join-Path $scriptDir "tmp"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
Set-Content -Path (Join-Path $tmpDir "gui.pid") -Value $proc.Id

Write-Host "GUI started (pid $($proc.Id)). Preview page: http://localhost:$Port/preview/index.html"
exit 0
