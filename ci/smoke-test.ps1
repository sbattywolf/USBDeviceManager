$base = 'http://localhost:5000'
$out = 'artifacts/smoke-test.log'

New-Item -ItemType Directory -Force -Path artifacts | Out-Null
'' | Out-File -FilePath $out -Encoding utf8
Add-Content -Path $out -Value ("Smoke test started: $(Get-Date -Format o)")

try {
    $devices = Invoke-RestMethod -Uri "$base/api/devices" -UseBasicParsing -TimeoutSec 5
    Add-Content -Path $out -Value ("`nGET /api/devices -> " + ($devices | ConvertTo-Json -Depth 5))
} catch {
    Add-Content -Path $out -Value ("GET /api/devices failed: " + $_.Exception.Message)
}

try {
    $software = Invoke-RestMethod -Uri "$base/api/software" -UseBasicParsing -TimeoutSec 5
    Add-Content -Path $out -Value ("`nGET /api/software -> " + ($software | ConvertTo-Json -Depth 5))
} catch {
    Add-Content -Path $out -Value ("GET /api/software failed: " + $_.Exception.Message)
}

if ($devices -and $devices.Count -gt 0) {
    $id = $devices[0].Id
    if (-not $id) { $id = $devices[0].id }
    Add-Content -Path $out -Value ("`nAttempting POST /api/devices/$id/toggle")
    try {
        # Determine current enabled state and toggle it by sending a JSON boolean body
        $currentEnabled = $devices[0].IsEnabled
        if (-not $currentEnabled) { $toggleValue = $true } else { $toggleValue = $false }
        $body = $toggleValue | ConvertTo-Json -Compress
        $r = Invoke-RestMethod -Method Post -Uri "$base/api/devices/$id/toggle" -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 5
        Add-Content -Path $out -Value ("POST toggle response: " + ($r | ConvertTo-Json -Depth 5))
    } catch {
        Add-Content -Path $out -Value ("POST toggle failed: " + $_.Exception.Message)
    }
} else {
    Add-Content -Path $out -Value "`nNo devices found to toggle."
}

if ($software -and $software.Count -gt 0) {
    $sid = $software[0].Id
    if (-not $sid) { $sid = $software[0].id }
    Add-Content -Path $out -Value ("`nAttempting POST /api/software/$sid/start")
    try {
        # Only attempt to start if the executable path exists to avoid expected 400 from missing executable
        # Extract executablePath robustly from returned object (handle case/casing/serialization differences)
        $exePath = $null
        try { $exePath = $software[0].executablePath } catch {}
        if (-not $exePath) {
            try { $exePath = $software[0].ExecutablePath } catch {}
        }
        if (-not $exePath) {
            # fallback via PSObject property lookup
            $prop = $software[0].PSObject.Properties | Where-Object { $_.Name -match 'executablePath' } | Select-Object -First 1
            if ($prop) { $exePath = $prop.Value }
        }
        if ($exePath -and (Test-Path -Path $exePath -PathType Leaf)) {
            $r2 = Invoke-RestMethod -Method Post -Uri "$base/api/software/$sid/start" -UseBasicParsing -TimeoutSec 5
            Add-Content -Path $out -Value ("POST start response: " + ($r2 | ConvertTo-Json -Depth 5))
        } else {
            $displayPath = if ($exePath) { $exePath } else { '<none>' }
            Add-Content -Path $out -Value ("POST start skipped: executable not found at path: " + $displayPath)
        }
    } catch {
        Add-Content -Path $out -Value ("POST start failed: " + $_.Exception.Message)
    }

    Add-Content -Path $out -Value ("`nAttempting POST /api/software/$sid/stop")
    try {
        $r3 = Invoke-RestMethod -Method Post -Uri "$base/api/software/$sid/stop" -UseBasicParsing -TimeoutSec 5
        Add-Content -Path $out -Value ("POST stop response: " + ($r3 | ConvertTo-Json -Depth 5))
    } catch {
        Add-Content -Path $out -Value ("POST stop failed: " + $_.Exception.Message)
    }
} else {
    Add-Content -Path $out -Value "`nNo software entries found to start/stop."
}

Add-Content -Path $out -Value ("`nSmoke test finished: $(Get-Date -Format o)")
