$base = 'http://localhost:5000'
Write-Output 'GET before'
try {
    $b = Invoke-RestMethod -Uri "$base/api/devices/1" -Method Get -ErrorAction Stop
    $b | ConvertTo-Json -Depth 5 | Write-Output
} catch {
    Write-Output "GET before failed: $($_.Exception.Message)"
}

Write-Output 'POST toggle true'
try {
    $r = Invoke-RestMethod -Uri "$base/api/devices/1/toggle" -Method Post -Body ($true | ConvertTo-Json) -ContentType 'application/json' -ErrorAction Stop
    $r | ConvertTo-Json -Depth 5 | Write-Output
} catch {
    if ($_.Exception.Response) {
        $status = $_.Exception.Response.StatusCode.value__
        Write-Output ("POST failed: Status {0}" -f $status)
        try { $stream = $_.Exception.Response.GetResponseStream(); $sr = New-Object System.IO.StreamReader($stream); $txt = $sr.ReadToEnd(); if ($txt) { Write-Output $txt } } catch {}
    } else {
        Write-Output "POST failed: $($_.Exception.Message)"
    }
}

Write-Output 'GET after'
try {
    $a = Invoke-RestMethod -Uri "$base/api/devices/1" -Method Get -ErrorAction Stop
    $a | ConvertTo-Json -Depth 5 | Write-Output
} catch {
    Write-Output "GET after failed: $($_.Exception.Message)"
}
