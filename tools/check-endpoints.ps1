Start-Sleep -Seconds 1
$h = Invoke-WebRequest -Uri 'http://localhost:5000' -UseBasicParsing -Method Head -TimeoutSec 10 -ErrorAction SilentlyContinue
if ($null -ne $h) { Write-Output "/ -> $($h.StatusCode)" } else { Write-Output "/ -> No HEAD response" }
$s = Invoke-WebRequest -Uri 'http://localhost:5000/swagger' -UseBasicParsing -Method Head -TimeoutSec 10 -ErrorAction SilentlyContinue
if ($null -ne $s) { Write-Output "/swagger -> $($s.StatusCode)" } else { Write-Output "/swagger -> No HEAD response" }
try {
    $r = Invoke-RestMethod -Uri 'http://localhost:5000/api/configs' -Method Get -TimeoutSec 30
    Write-Output "API /api/configs returned:"
    $r | ConvertTo-Json -Depth 4 | Write-Output
} catch {
    Write-Output "API request failed:"
    Write-Output $_.Exception.Message
}
