param(
    [string]$RunId = '21316875919'
)

$out = "artifacts/enriched/failures/$RunId"
New-Item -ItemType Directory -Force -Path $out | Out-Null

# Known failing tests to extract from logs
$tests = @(
    'Heartbeat_Post_WithLegacySchema_ShouldReturnOk',
    'PerformanceUnderLoad_MultipleSimultaneousRequests_ShouldMaintainResponsiveness',
    'SystemHealthMonitoring_ContinuousMonitoring_ShouldTrackSystemMetrics',
    'ErrorHandlingAndRecovery_InvalidOperations_ShouldHandleGracefully'
)

$runRoot = "artifacts/gh-run-$RunId"
$log = Join-Path $runRoot 'run-logs.txt'

Write-Output "Extracting test excerpts and artifacts for run $RunId -> $out"

foreach ($t in $tests) {
    $file = Join-Path $out ($t + '.txt')
    if (Test-Path $log) {
        Select-String -Path $log -Pattern $t -Context 5,5 -ErrorAction SilentlyContinue | ForEach-Object {
            $pre = $_.Context.PreContext -join "`n"
            $post = $_.Context.PostContext -join "`n"
            $line = $_.Line
            $content = $pre + "`n" + $line + "`n" + $post
            $content
        } | Out-File -FilePath $file -Encoding utf8
    }
}

# Collect per-test artifacts from test projects (TRX, server logs, response logs, db dumps)
$artifactPatterns = @(
    'server/*/TestResults/artifacts/*',
    'server/**/TestResults/artifacts/*',
    '*/TestResults/artifacts/*',
    'TestResults/artifacts/*'
)

foreach ($p in $artifactPatterns) {
    Get-ChildItem -Path $p -ErrorAction SilentlyContinue -File | ForEach-Object {
        try {
            $dst = Join-Path $out $_.Name
            Copy-Item -Path $_.FullName -Destination $dst -Force
        } catch {
            Write-Error "Failed to copy artifact $_.FullName: $_"
        }
    }
}

# Search artifacts for EF/SQLite exceptions and include short excerpts
$searchPatterns = @('SqliteException','SQLiteException','SQLite error','SQLite.Interop','DbUpdateException','ForeignKey')
$exceptionFile = Join-Path $out 'exceptions.txt'
Remove-Item -Path $exceptionFile -ErrorAction SilentlyContinue

Get-ChildItem -Path $out -File -ErrorAction SilentlyContinue | ForEach-Object {
    $path = $_.FullName
    foreach ($pat in $searchPatterns) {
        Select-String -Path $path -Pattern $pat -Context 3,3 -ErrorAction SilentlyContinue | ForEach-Object {
            "---- $path ----" | Out-File -FilePath $exceptionFile -Append -Encoding utf8
            ($_.Context.PreContext -join "`n") | Out-File -FilePath $exceptionFile -Append -Encoding utf8
            $_.Line | Out-File -FilePath $exceptionFile -Append -Encoding utf8
            ($_.Context.PostContext -join "`n") | Out-File -FilePath $exceptionFile -Append -Encoding utf8
            "`n" | Out-File -FilePath $exceptionFile -Append -Encoding utf8
        }
    }
}

Write-Output "Saved artifacts and exception excerpts to $out"