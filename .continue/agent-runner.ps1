param(
    [string]$Prompt,
    [string]$Agent
)

# Minimal local agent runner with agent selection
# Usage:
#   ./.continue/agent-runner.ps1 -Agent CustomAgent -Prompt "Hello"
#   echo "Hello" | ./.continue/agent-runner.ps1 -Agent TurboAgent

if (-not $Prompt) {
    try { $stdin = [Console]::In.ReadToEnd(); if ($stdin) { $Prompt = $stdin.Trim() } } catch { }
}

if (-not $Prompt) { Write-Error 'No prompt provided.'; exit 2 }

# Load agent configs
$cfgPath = Join-Path (Get-Location) '.continue\config.agent'
if (-not (Test-Path $cfgPath)) { Write-Warning "Missing config.agent at $cfgPath; using echo response." }
else {
    try { $cfg = Get-Content -Path $cfgPath -Raw | ConvertFrom-Json } catch { $cfg = $null }
}

if (-not $Agent) {
    $Agent = if ($cfg -and $cfg.default) { $cfg.default } else { 'CustomAgent' }
}

# Resolve selected agent
$selected = $null
if ($cfg -and $cfg.agents) { $selected = $cfg.agents | Where-Object { $_.name -eq $Agent } | Select-Object -First 1 }

if (-not $selected) {
    $selected = [PSCustomObject]@{ name = 'echo'; options = @{ model = 'none'; mode = 'echo' } }
}

# Example behavior: echo or annotate response with agent name and options
$resp = [PSCustomObject]@{
    agent = $selected.name
    options = $selected.options
    prompt = $Prompt
    response = "[$($selected.name)] Echo: $Prompt"
    timestamp = (Get-Date).ToString('o')
}

$resp | ConvertTo-Json -Depth 5
