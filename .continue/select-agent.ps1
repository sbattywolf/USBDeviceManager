param(
    [Parameter(Mandatory=$true)][string]$AgentName
)

$dest = Join-Path (Get-Location) '.continue\selected_agent.txt'
Set-Content -Path $dest -Value $AgentName -Encoding ASCII -Force
Write-Host "Selected agent: $AgentName -> $dest"
