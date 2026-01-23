try {
    . 'E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/shared/TestFramework.psm1'
    Write-Host 'Sourced ok'
} catch {
    Write-Host 'Sourcing failed:'
    Write-Host $_.Exception.Message
    exit 2
}

$names = @('Write-AgentLog','Set-AgentLock','Clear-AgentLock','Get-DefaultConfiguration','Import-AgentConfiguration')
foreach ($name in $names) {
    $cmd = Get-Command -Name $name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { Write-Host "$name : MISSING" } else { Write-Host "$name : FOUND -> $($cmd.CommandType)" }
}

    # Ensure AdapterStubs is imported in this session (diagnostic)
    $adapter = 'E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/shared/AdapterStubs.psm1'
    try { Import-Module $adapter -Force -ErrorAction Stop ; Write-Host "Imported adapter module for diagnostic" } catch { Write-Host "Import-Module adapter failed: $($_.Exception.Message)" }

    $names = @('Write-AgentLog','Set-AgentLock','Clear-AgentLock','Get-DefaultConfiguration','Import-AgentConfiguration')

    foreach ($name in $names) {
        $cmd = Get-Command -Name $name -ErrorAction SilentlyContinue
        if ($null -eq $cmd) { Write-Host "$name : MISSING" } else { Write-Host "$name : FOUND -> $($cmd.CommandType)" }
    }

    Get-Command -CommandType Function | Where-Object { $_.Name -match 'Agent' } | Select-Object -First 20 | Format-Table -AutoSize
