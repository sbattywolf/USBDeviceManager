Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager'
# Stop any dashboard background jobs
$jobs = Get-Job -Name 'Dashboard*' -ErrorAction SilentlyContinue
if ($jobs) {
    foreach ($j in $jobs) {
        if ($j.State -eq 'Running' -or $j.State -eq 'NotStarted') {
            Stop-Job -Id $j.Id -Force -ErrorAction SilentlyContinue
        }
        Remove-Job -Id $j.Id -Force -ErrorAction SilentlyContinue
        Write-Output "StoppedJob:$($j.Name)"
    }
} else {
    Write-Output 'NoDashboardJobsFound'
}

# Stage and commit changes if present
$s = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($s)) {
    git add -A
    git commit -m 'Save session: workspace snapshot (auto-commit)'
    $hash = git rev-parse --short HEAD
    $branch = git rev-parse --abbrev-ref HEAD
    Write-Output ('COMMITTED:{0}:{1}' -f $hash,$branch)
} else {
    Write-Output 'NO_CHANGES'
}
