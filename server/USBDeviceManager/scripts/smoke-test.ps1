param(
    [string]$Port = "5005",
    [int]$TimeoutSeconds = 30
)

$proj = Join-Path $PSScriptRoot ".."
$proj = [System.IO.Path]::GetFullPath($proj)
Write-Host "Project dir: $proj"

Write-Host "Building project..."
dotnet build $proj -c Debug

$urls = "http://localhost:$Port"
$startInfo = @{
    FilePath = "dotnet"
    ArgumentList = @('run','--no-build','--urls',$urls)
    WorkingDirectory = $proj
    WindowStyle = 'Hidden'
}

Write-Host "Starting server on $urls"
$proc = Start-Process @startInfo -PassThru

try {
    $base = "http://localhost:$Port"
    Write-Host "Waiting for server at $base..."
    $ready = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $ready -and $sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $r = Invoke-WebRequest -Uri "$base/api/configs" -Method GET -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($r.StatusCode -eq 200) { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ready) { throw "Server did not start in time" }

    Write-Host "Server ready — running smoke requests..."

    $steps = @(
        @{Method='GET'; Path='/api/configs'; Expect=200},
        @{Method='GET'; Path='/api/logs'; Expect=200},
        @{Method='GET'; Path='/api/agent/download'; Expect=200},
        @{Method='POST'; Path='/api/logs'; Expect=201; Body=@{deviceId='NON_EXISTENT'; eventType='CONNECTED'}},
        @{Method='POST'; Path='/api/configs'; Expect=201; Body=@{triggerPath='C:\\Temp\\smoketest.exe'; softwareName='SmokeTestApp'}}
    )

    foreach ($s in $steps) {
        $uri = "$base$($s.Path)"
        if ($s.Method -eq 'GET') {
            $resp = Invoke-WebRequest -Uri $uri -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($resp.StatusCode -ne $s.Expect) { throw "Expected $($s.Expect) for $uri but got $($resp.StatusCode)" }
        } else {
            $json = ConvertTo-Json $s.Body
            $resp = Invoke-WebRequest -Uri $uri -Method POST -Body $json -ContentType 'application/json' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($resp.StatusCode -ne $s.Expect) { throw "Expected $($s.Expect) for $uri but got $($resp.StatusCode)" }
        }
        Write-Host "OK $($s.Method) $($s.Path) => $($s.Expect)"
    }

    Write-Host "All smoke checks passed."
} finally {
    if ($proc -and -not $proc.HasExited) {
        Write-Host "Stopping server (PID $($proc.Id))..."
        Stop-Process -Id $proc.Id -Force
    }
}

