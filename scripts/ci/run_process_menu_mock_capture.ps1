# Wrapper to run scripts/process-menu.ps1 in mock-mode and capture pid/marker files
Set-Location -Path (Join-Path $PSScriptRoot "..\..")
$marker = 'scripts/ci/process-menu-run.marker'
$mockS = 'scripts/ci/mock_server.pid'
$mockA = 'scripts/ci/mock_agent.pid'
Remove-Item -Force -ErrorAction SilentlyContinue $marker, $mockS, $mockA

$env:PROCESS_MENU_MOCK='1'
$env:PROCESS_MENU_ENABLE_AUTO_ADVANCE='1'
$env:PROCESS_MENU_DEFAULT_ACTION='6'  # start agent by default for CI capture
$env:PROCESS_MENU_TEST_MARKER = $marker

Write-Host '--- Running process-menu (auto-start server) ---'
try {
    & .\scripts\process-menu.ps1
} catch {
    Write-Host 'process-menu threw:'
    if ($_.Exception) { Write-Host $_.Exception.Message }
    else { Write-Host $_ }
}

Write-Host '--- After exit: check pid files ---'
Write-Host "mock_server.pid exists: $(Test-Path $mockS)"
if (Test-Path $mockS) { Write-Host 'mock_server.pid content:'; Get-Content $mockS -Raw }
Write-Host "mock_agent.pid exists:  $(Test-Path $mockA)"
if (Test-Path $mockA) { Write-Host 'mock_agent.pid content:'; Get-Content $mockA -Raw }

Write-Host 'Marker contents:'
Write-Host 'Marker contents (escaped, single-line):'
if (Test-Path $marker) {
    $raw = Get-Content $marker -Raw
    # replace CR/LF with literal escape sequences and collapse any remaining runs
    $escaped = ($raw -replace "`r", '\\r' -replace "`n", '\\n').Trim()
    Write-Host $escaped
} else { Write-Host '<marker missing>' }
