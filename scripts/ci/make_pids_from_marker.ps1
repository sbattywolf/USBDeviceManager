# Read marker file and write mock pid files for server and agent based on last seen markers
$marker = 'scripts/ci/process-menu-run.marker'
Set-Location -Path (Join-Path $PSScriptRoot '..\..')
if (-not (Test-Path $marker)) { Write-Host "Marker not found: $marker"; exit 2 }
$raw = Get-Content $marker -Raw

# Extract PIDs
$serverPid = $null; $agentPid = $null
if ($raw -match 'MOCK_MARK\s+Start-ServerDetached\s+PID=(\d+)') { $serverPid = $Matches[1] }
if ($raw -match 'MOCK_MARK\s+Start-AgentDetached\s+PID=(\d+)') { $agentPid = $Matches[1] }

$mockS = 'scripts/ci/mock_server.pid'
$mockA = 'scripts/ci/mock_agent.pid'

if ($serverPid) { Set-Content -Path $mockS -Value $serverPid -Force; Write-Host "Wrote $mockS = $serverPid" } else { Write-Host 'No server PID found in marker' }
if ($agentPid) { Set-Content -Path $mockA -Value $agentPid -Force; Write-Host "Wrote $mockA = $agentPid" } else { Write-Host 'No agent PID found in marker' }

# Output current marker content (escaped)
$escaped = ($raw -replace "`r", '\\r' -replace "`n", '\\n').Trim()
Write-Host 'Marker (escaped):'; Write-Host $escaped

exit 0
