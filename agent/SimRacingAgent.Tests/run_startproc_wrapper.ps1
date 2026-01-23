$ps = (Get-Command powershell -ErrorAction SilentlyContinue).Source
if (-not $ps) { $ps = 'powershell' }
$runner = 'E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/TestRunner.ps1'
$reportPath = 'E:/Workspaces/Git/SimRacing/USBDeviceManager/scripts/tmp/reports'
$out = 'E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/run_tests_startproc.out'
$err = 'E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/run_tests_startproc.err'
# Use single-quoted literal so $VerbosePreference is not expanded in the parent process
# Run the TestRunner inside a transient transcript so host output (Write-Host) is captured.
$script = @'
$trans = "E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/run_tests_transcript_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
Start-Transcript -Path $trans -Force
try {
	$VerbosePreference = "Continue"
	. 'E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/TestRunner.ps1'
	Invoke-CICDTestSuite -ReportPath 'E:/Workspaces/Git/SimRacing/USBDeviceManager/scripts/tmp/reports' -Verbose
}
finally {
	Stop-Transcript
	Write-Output "TRANSCRIPT:$trans"
}
'@

# Encode script for -EncodedCommand to avoid cmdline quoting issues
$bytes = [System.Text.Encoding]::Unicode.GetBytes($script)
$encoded = [Convert]::ToBase64String($bytes)

Start-Process -FilePath $ps -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded -Wait -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
Write-Host "Start-Process executed; outputs at $out and $err"