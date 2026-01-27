<#
Non-interactive wrapper for running PowerShell scripts in CI/local.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\run_noninteractive.ps1 \
    .\scripts\ci\run_all_tests_sequential.ps1 -RunId my_run -DryRun

Behavior:
 - Detects interactive host (via $Host.UI.SupportsUserInteraction).
 - If interactive, it relaunches the target script in a hidden, non-interactive
   PowerShell process and returns the same exit code.
 - If already non-interactive, it invokes the script directly.

Set environment variables to avoid prompts: GIT_TERMINAL_PROMPT=0,
DOTNET_CLI_TELEMETRY_OPTOUT=1.
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ScriptPath,

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

function Is-InteractiveHost {
    try {
        if ($env:CI) { return $false }
        return [bool]$Host.UI.SupportsUserInteraction
    } catch {
        return $true
    }
}

# Export safe defaults to avoid interactive prompts from tools
$env:GIT_TERMINAL_PROMPT = '0'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

try {
    $resolved = Resolve-Path -LiteralPath $ScriptPath -ErrorAction Stop
    $scriptFull = $resolved.ProviderPath
} catch {
    Write-Error "Script not found: $ScriptPath"
    exit 2
}

if (Is-InteractiveHost) {
    Write-Host "Interactive host detected — relaunching non-interactively..."

    $argsList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "'$scriptFull'"
    )
    if ($ScriptArgs) {
        foreach ($a in $ScriptArgs) { $escaped = $a -replace "'","''"; $argsList += "'$escaped'" }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell'
    $psi.Arguments = $argsList -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $started = $proc.Start()
    if (-not $started) {
        Write-Error 'Failed to start non-interactive process.'
        exit 3
    }

    $stdOut = $proc.StandardOutput.ReadToEnd()
    $stdErr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    if ($stdOut) { Write-Output $stdOut }
    if ($stdErr) { Write-Error $stdErr }

    exit $proc.ExitCode
} else {
    Write-Host "Running non-interactively: $scriptFull $([string]::Join(' ', $ScriptArgs))"
    & $scriptFull @ScriptArgs
    exit $LASTEXITCODE
}
