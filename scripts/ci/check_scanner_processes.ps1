# Lists processes whose command line mentions our scanner or monitor scripts
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -and (
      ($_.CommandLine -match 'artifact_scan_streamed.ps1') -or
      ($_.CommandLine -match 'monitor_scanner.ps1')
    ) } |
  Select-Object ProcessId,CommandLine | Format-List -Force
