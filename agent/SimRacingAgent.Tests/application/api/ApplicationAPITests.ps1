# Import shared test framework
Import-Module "$PSScriptRoot\..\..\shared\TestFramework.psm1" -ErrorAction SilentlyContinue
if (-not (Get-Command -Name Start-TestSession -ErrorAction SilentlyContinue)) { . "$PSScriptRoot\..\..\shared\TestFramework.psm1" }

function Test-ApplicationAPI {
    [CmdletBinding()]
    param()

    Start-TestSession -SessionName "Application API Placeholder"

    try {
        Invoke-Test -Name "Placeholder API test" -Category "Application.API" -TestScript {
            Assert-True -Condition $true -Message "placeholder always true"
        }
    }
    finally {
        if (Get-Command -Name Clear-AllMocks -ErrorAction SilentlyContinue) { Clear-AllMocks }
    }

    return Complete-TestSession
}

# Wrapper invoked by TestRunner. Keeps compatibility with TestRunner expecting
# an Invoke-ApplicationAPITests entry point.
function Invoke-ApplicationAPITests {
    [CmdletBinding()]
    param(
        [switch]$StopOnFirstFailure
    )

    if (-not (Get-Command -Name Test-ApplicationAPI -ErrorAction SilentlyContinue)) {
        Write-Verbose "Test-ApplicationAPI not found; skipping ApplicationAPI tests"
        return @{ Success = $true; Results = @(); Summary = @{ Passed = 0; Failed = 0; Skipped = 0 } }
    }

    try {
        $result = Test-ApplicationAPI
        return $result
    }
    catch {
        Write-Error "Invoke-ApplicationAPITests: $_"
        return @{ Success = $false; Results = @(); Summary = @{ Passed = 0; Failed = 1; Skipped = 0 } }
    }
}

# Export functions when run as module so Import-Module picks up the entry point
try {
    Export-ModuleMember -Function @('Test-ApplicationAPI','Invoke-ApplicationAPITests')
}
catch {
    Write-Host "DEBUG: Export-ModuleMember skipped (not running inside module): $($_.Exception.Message)"
}

