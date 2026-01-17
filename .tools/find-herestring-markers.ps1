param([string]$Path)
Get-Content $Path | ForEach-Object -Begin {$n=1} -Process {
    if ($_ -match "^\s*@'|^\s*'@|^\s*@\"|^\s*\"@") { Write-Host "$n: $_" }
    $n++
}
