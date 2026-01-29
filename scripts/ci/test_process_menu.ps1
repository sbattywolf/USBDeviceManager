"Running process-menu test harness"
$script = '.\scripts\process-menu.ps1'
# Simulate: select 0 (Exit) immediately
$testInputs = @('0')

powershell -NoProfile -ExecutionPolicy Bypass -File $script -TestInputs $testInputs

Write-Host 'Test complete.'
