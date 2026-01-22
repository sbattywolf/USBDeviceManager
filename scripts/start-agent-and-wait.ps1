param(
    [Parameter(Mandatory=$true)]
    [string]$AgentExe,
    [string]$Args = "",
    [string]$AgentHealthUrl = "",
    [int]$TimeoutSec = 60
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tmpDir = Join-Path $scriptDir "tmp"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

if (-not (Test-Path $AgentExe)) {
    Write-Error "Agent executable not found: $AgentExe"
    exit 1
}

Write-Host "Starting agent: $AgentExe $Args"
$proc = Start-Process -FilePath $AgentExe -ArgumentList $Args -WorkingDirectory (Split-Path $AgentExe) -PassThru
Set-Content -Path (Join-Path $tmpDir "agent.pid") -Value $proc.Id
Write-Host "Agent started (pid $($proc.Id))"

if ($AgentHealthUrl -ne "") {
    Write-Host "Waiting for agent health/registration at $AgentHealthUrl"
    & "$scriptDir/poll-health.ps1" -Url $AgentHealthUrl -TimeoutSec $TimeoutSec
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Agent did not register/become healthy within timeout."
        exit 1
    }
    Write-Host "Agent reported healthy/registered."
} else {
    Start-Sleep -Seconds 3
}

exit 0
