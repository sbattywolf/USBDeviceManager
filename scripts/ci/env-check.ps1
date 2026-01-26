Param(
    [string]$OutFile = "env-check.json"
)

$results = [ordered]@{
    env_ok = $true
    reason = @()
    checks = @{}
}

function Add-Failure($msg) {
    $results.env_ok = $false
    $results.reason += $msg
}

# dotnet
try {
    $dotnet = & dotnet --info 2>$null | Out-String
    $results.checks.dotnet = $true
} catch {
    $results.checks.dotnet = $false
    Add-Failure "dotnet-missing"
}

# python
try {
    $py = & python --version 2>&1
    $results.checks.python = $true
} catch {
    $results.checks.python = $false
    Add-Failure "python-missing"
}

# node (optional)
try {
    $node = & node --version 2>$null | Out-String
    $results.checks.node = $true
} catch {
    $results.checks.node = $false
    $results.reason += "node-missing"
}

# basic file system access check (create tmp file)
try {
    $tmp = Join-Path $PWD "scripts/tmp/env-check-$$.txt"
    New-Item -Path (Split-Path $tmp) -ItemType Directory -Force | Out-Null
    "ok" | Out-File -FilePath $tmp -Encoding ASCII
    if (-not (Test-Path $tmp)) { Add-Failure "fs-write-failed" }
    Remove-Item -Force $tmp -ErrorAction SilentlyContinue
    $results.checks.fs = $true
} catch {
    $results.checks.fs = $false
    Add-Failure "fs-check-failed"
}

# Write results
$results | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutFile -Encoding UTF8

# Exit zero always; workflow will examine the JSON
exit 0
