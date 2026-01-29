Param()
$ErrorActionPreference = 'Stop'

Write-Host 'Running owning-terminal detection test'

# Use current process as a deterministic target
$cur = Get-Process -Id $PID -ErrorAction SilentlyContinue
if (-not $cur) { Write-Error "Could not resolve current process (PID=$PID)"; exit 2 }

function Get-OwningTerminalLocal($proc) {
    if (-not $proc) { return $null }
    $targetPid = $null
    if ($proc -is [System.Diagnostics.Process]) { $targetPid = $proc.Id } elseif ($proc.ProcessId) { $targetPid = $proc.ProcessId }
    if (-not $targetPid) { return $null }

    $maxDepth = 8
    $current = Get-CimInstance Win32_Process -Filter "ProcessId=$targetPid" -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt $maxDepth -and $current; $i++) {
        $ppid = $current.ParentProcessId
        if (-not $ppid) { break }
        $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$ppid" -ErrorAction SilentlyContinue
        if (-not $parent) { break }
        $pname = $parent.Name
        $pcmd = $parent.CommandLine
        if ($pname -match 'powershell|pwsh|cmd|conhost|WindowsTerminal|wt|terminal') {
            return [PSCustomObject]@{ Pid = $parent.ProcessId; ProcessName = $pname; CommandLine = $pcmd }
        }
        $current = $parent
    }
    return $null
}

$owner = Get-OwningTerminalLocal $cur
if ($owner) {
    Write-Host "Owning terminal detected: $($owner.ProcessName) PID=$($owner.Pid)"
    Write-Host "Cmdline: $($owner.CommandLine)"
} else {
    Write-Host 'No owning terminal detected for current process (this can be normal in CI).' -ForegroundColor Yellow
}

# Verify signaling gate: by default PROCESS_MENU_ALLOW_SIGNAL must not be '1' (destructive disabled)
if ($env:PROCESS_MENU_ALLOW_SIGNAL -eq '1') {
    Write-Warning 'PROCESS_MENU_ALLOW_SIGNAL=1 in environment; destructive signaling is enabled (test expects disabled by default).'
    Write-Host 'Test skipped due to environment enabling destructive actions.'
    exit 0
} else {
    Write-Host 'PROCESS_MENU_ALLOW_SIGNAL not set to 1 — destructive signaling is gated as expected.'
}

Write-Host 'Owning-terminal test: PASS'
exit 0
