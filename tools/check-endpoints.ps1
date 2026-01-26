Start-Sleep -Seconds 1
# Use TEST_PORT if provided, otherwise default to 5000
$port = $env:TEST_PORT
if (-not $port) { $port = 5000 } else { $port = [int]$port }
$base = "http://localhost:$port"

$h = Invoke-WebRequest -Uri ($base) -UseBasicParsing -Method Head -TimeoutSec 10 -ErrorAction SilentlyContinue
if ($null -ne $h) { Write-Output "/ -> $($h.StatusCode)" } else { Write-Output "/ -> No HEAD response" }
$s = Invoke-WebRequest -Uri ($base + '/swagger') -UseBasicParsing -Method Head -TimeoutSec 10 -ErrorAction SilentlyContinue
if ($null -ne $s) { Write-Output "/swagger -> $($s.StatusCode)" } else { Write-Output "/swagger -> No HEAD response" }
try {
    $r = Invoke-RestMethod -Uri ($base + '/api/configs') -Method Get -TimeoutSec 30
    Write-Output "API /api/configs returned:"
    $r | ConvertTo-Json -Depth 4 | Write-Output
} catch {
    Write-Output "API request failed:"
    Write-Output $_.Exception.Message
}
