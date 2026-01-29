param(
    [string]$Prompt
)

# Minimal local agent runner stub
# Usage:
#   ./.continue/agent-runner.ps1 -Prompt "Hello"
#   echo "Hello" | ./.continue/agent-runner.ps1

if (-not $Prompt) {
    try {
        $stdin = [Console]::In.ReadToEnd()
        if ($stdin) { $Prompt = $stdin.Trim() }
    } catch { }
}

if (-not $Prompt) { Write-Error 'No prompt provided.'; exit 2 }

$resp = [PSCustomObject]@{
    prompt = $Prompt
    response = "Echo: $Prompt"
    timestamp = (Get-Date).ToString('o')
}

$resp | ConvertTo-Json -Depth 3
