# Determine PowerShell executable and use script-relative paths
$ps = (Get-Command powershell -ErrorAction SilentlyContinue).Source
if (-not $ps) { $ps = 'powershell' }
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runner = Join-Path $scriptRoot 'TestRunner.ps1'
$reportPath = Join-Path $scriptRoot '..\..\scripts\tmp\reports'
if (-not (Test-Path $reportPath)) { New-Item -Path $reportPath -ItemType Directory -Force | Out-Null }
$out = Join-Path $scriptRoot 'run_tests_startproc.out'
$err = Join-Path $scriptRoot 'run_tests_startproc.err'
# Use single-quoted literal so $VerbosePreference is not expanded in the parent process
# Run the TestRunner inside a transient transcript so host output (Write-Host) is captured.
 # Build an inner script with evaluated paths so the launched process has concrete values
 $transPath = Join-Path $scriptRoot ("run_tests_transcript_{0}.txt" -f (Get-Date -Format yyyyMMdd_HHmmss))
 $script = @"
 `$trans = '$transPath'
 Start-Transcript -Path `$trans -Force
 try {
	 `$VerbosePreference = 'Continue'
	 . '$runner'
	 Invoke-CICDTestSuite -ReportPath '$reportPath' -Verbose
 }
 finally {
	 Stop-Transcript
	 Write-Output "TRANSCRIPT:$trans"
 }
"@

# Create a small temp script to run inside a fresh PowerShell process (avoids complex quoting)
$tempScript = Join-Path $scriptRoot '.__run_wrapper.ps1'
$script | Out-File -FilePath $tempScript -Encoding Unicode -Force

Start-Process -FilePath $ps -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$tempScript -Wait -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
Write-Host "Start-Process executed; outputs at $out and $err"