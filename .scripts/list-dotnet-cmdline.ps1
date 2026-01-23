Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'dotnet.exe' } | ForEach-Object {
    $id = $_.ProcessId
    $cmd = $_.CommandLine -replace "\r|\n"," "
    Write-Output "$id :: $cmd"
}