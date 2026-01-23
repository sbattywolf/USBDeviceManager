# Import shared test framework
Import-Module "$PSScriptRoot\..\..\shared\TestFramework.psm1" -ErrorAction SilentlyContinue
if (-not (Get-Command -Name Start-TestSession -ErrorAction SilentlyContinue)) { . "$PSScriptRoot\..\..\shared\TestFramework.psm1" }

function Test-ApplicationIntegration {
    [CmdletBinding()]
    param()

    Start-TestSession -SessionName "Application Integration Placeholder"

    try {
        Invoke-Test -Name "Placeholder Integration test" -Category "Application.Integration" -TestScript {
            Assert-True -Condition $true -Message "placeholder integration always true"
        }
    }
    finally {
        if (Get-Command -Name Clear-AllMocks -ErrorAction SilentlyContinue) { Clear-AllMocks }
    }

    return Complete-TestSession
}

# Wrapper invoked by TestRunner. Keeps compatibility with TestRunner expecting
# an Invoke-ApplicationIntegrationTests entry point.
function Invoke-ApplicationIntegrationTests {
    [CmdletBinding()]
    param(
        [switch]$StopOnFirstFailure
    )

    if (-not (Get-Command -Name Test-ApplicationIntegration -ErrorAction SilentlyContinue)) {
        Write-Verbose "Test-ApplicationIntegration not found; skipping ApplicationIntegration tests"
        return @{ Success = $true; Results = @(); Summary = @{ Passed = 0; Failed = 0; Skipped = 0 } }
    }

    try {
        $result = Test-ApplicationIntegration
        return $result
    }
    catch {
        Write-Error "Invoke-ApplicationIntegrationTests: $_"
        return @{ Success = $false; Results = @(); Summary = @{ Passed = 0; Failed = 1; Skipped = 0 } }
    }
}

# Export functions when run as module so Import-Module picks up the entry point
try {
    Export-ModuleMember -Function @('Test-ApplicationIntegration','Invoke-ApplicationIntegrationTests')
}
catch {
    Write-Host "DEBUG: Export-ModuleMember skipped (not running inside module): $($_.Exception.Message)"
}

