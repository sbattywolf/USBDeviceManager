$urls = @(
    'http://localhost:5000/health',
    'http://localhost:5000/health/ready',
    'http://localhost:5000/api/health',
    'http://localhost:5000',
    'http://localhost:5000/api/devices',
    'http://localhost:5000/api/software',
    'http://localhost:5000/api/agents'
)

foreach ($u in $urls) {
    Write-Output '---'
    Write-Output "Requesting: $u"
    try {
        $r = Invoke-RestMethod -Uri $u -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Output 'Status: 200'
        if ($r -is [System.String]) { Write-Output $r } else { $j = $r | ConvertTo-Json -Depth 5; Write-Output $j }
    } catch {
        if ($_.Exception.Response) {
            $status = $_.Exception.Response.StatusCode.value__
            Write-Output ("Status: {0}" -f $status)
            try {
                $body = $_.Exception.Response.GetResponseStream()
                $sr = New-Object System.IO.StreamReader($body)
                $txt = $sr.ReadToEnd()
                if ($txt) { Write-Output $txt }
            } catch {}
        } else {
            Write-Output ("Error: {0}" -f $_.Exception.Message)
        }
    }
}
