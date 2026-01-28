# Test harness: simulate interactive inputs for interactive_path_prompt.ps1
"Using interactive script test harness"
$script = '.\scripts\ci\interactive_path_prompt.ps1'
# Simulate: blank (Enter) then 'y' to accept default
$testInputs = @('','y')

powershell -NoProfile -ExecutionPolicy Bypass -File $script -TestInputs $testInputs
