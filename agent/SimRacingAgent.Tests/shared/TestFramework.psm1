# Minimal test framework shim for local unit tests

$Global:TestSession = $null
$Global:MockFunctions = @{}
$Global:MockCalls = @{}
$Global:MockTimestamps = @{}
$Global:MockOrders = @{}
$Global:MockCounter = 0

# Load adapter stubs providing compatibility functions expected by tests
try {
    $adapter = Join-Path $PSScriptRoot "AdapterStubs.psm1"
    if (Test-Path $adapter) { Import-Module $adapter -Force -ErrorAction SilentlyContinue }
}
catch {}

function Start-TestSession {
    param([string]$SessionName)
    $Global:TestSession = @{ Name = $SessionName; Results = @(); Summary = @{ Passed = 0; Failed = 0; Skipped = 0 }; Success = $true }
}

function Invoke-Test {
    param(
        [string]$Name,
        [string]$Category,
        [scriptblock]$TestScript,
        [scriptblock]$Teardown
    )

    try {
        # Ensure starting from a clean mock state for each test
        try { Clear-AllMocks } catch {}
        # Log pre-test mock state
        try {
            $preKeys = $Global:MockFunctions.Keys -join ','
            $preOrders = ($Global:MockOrders.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','
            "$((Get-Date).ToString('o')) PRETEST MockKeys=$preKeys MockOrders=$preOrders" | Out-File -FilePath (Join-Path $PSScriptRoot '..\..\..\.tmp_test_trace.txt') -Append -Encoding utf8
        } catch {}

        & $TestScript
        # Log post-test mock state
        try {
            $postKeys = $Global:MockFunctions.Keys -join ','
            $postOrders = ($Global:MockOrders.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','
            "$((Get-Date).ToString('o')) POSTTEST MockKeys=$postKeys MockOrders=$postOrders" | Out-File -FilePath (Join-Path $PSScriptRoot '..\..\..\.tmp_test_trace.txt') -Append -Encoding utf8
        } catch {}
        $Global:TestSession.Summary.Passed++
        $Global:TestSession.Results += @{ Name = $Name; Category = $Category; Success = $true }
        Write-Host "[PASS] $Category - $Name" -ForegroundColor Green
    }
    catch {
        $Global:TestSession.Summary.Failed++
        $Global:TestSession.Results += @{ Name = $Name; Category = $Category; Success = $false; Error = $_.Exception.Message }
        $Global:TestSession.Success = $false
        Write-Host "[FAIL] $Category - $Name : $($_.Exception.Message)" -ForegroundColor Red
        # On failure, dump mock state and attempt to capture USBDevices for diagnosis
        try {
            $tracePath = (Join-Path $PSScriptRoot '..\..\..\.tmp_test_trace.txt')
            $keys = if ($Global:MockFunctions) { $Global:MockFunctions.Keys -join ',' } else { '<none>' }
            $orders = if ($Global:MockOrders) { ($Global:MockOrders.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ',' } else { '<none>' }
            "$((Get-Date).ToString('o')) FAILURE $Category - $Name MockKeys=$keys MockOrders=$orders Error=$($_.Exception.Message)" | Out-File -FilePath $tracePath -Append -Encoding utf8
            try {
                $devs = Get-USBDevices
                "$((Get-Date).ToString('o')) FAILURE_CAPTURE DevicesCount=$($devs.Count)" | Out-File -FilePath $tracePath -Append -Encoding utf8
                if ($devs -and $devs.Count -gt 0) { $devs | ForEach-Object { "DeviceDump: $($_.DeviceID) | $($_.Description)" } | Out-File -FilePath $tracePath -Append -Encoding utf8 }
            } catch { "$((Get-Date).ToString('o')) FAILURE_CAPTURE Get-USBDevices threw: $($_.Exception.Message)" | Out-File -FilePath $tracePath -Append -Encoding utf8 }
        } catch {}
    }
    finally {
        if ($Teardown) { & $Teardown }
        # Ensure mocks are cleared between tests to avoid cross-test pollution
        try { Clear-AllMocks } catch {}
    }
}

function Complete-TestSession {
    return @{ Success = $Global:TestSession.Success; Results = $Global:TestSession.Results; Summary = $Global:TestSession.Summary }
}

function Clear-AllMocks {
    foreach ($name in $Global:MockFunctions.Keys) {
        if (Get-Command $name -ErrorAction SilentlyContinue) {
            Remove-Item -Path "function:\Global\$name" -ErrorAction SilentlyContinue
        }
    }
    $Global:MockFunctions.Clear()
    $Global:MockCalls.Clear()
    $Global:MockTimestamps.Clear()
    $Global:MockOrders.Clear()
    $Global:MockCounter = 0
}

function New-Mock {
    param(
        [Parameter(Mandatory)] [string]$CommandName,
        [Parameter(Mandatory)] [scriptblock]$MockWith,
        [hashtable]$ParameterFilter
    )
    # Register mock implementation and bookkeeping. Do not create a global function wrapper
    # so module functions are not shadowed by mocks; modules should consult $Global:MockFunctions
    $Global:MockFunctions[$CommandName] = $MockWith
    $Global:MockCalls[$CommandName] = 0
    $Global:MockTimestamps[$CommandName] = (Get-Date).ToUniversalTime()
    $Global:MockCounter = ($Global:MockCounter -as [int]) + 1
    $Global:MockOrders[$CommandName] = $Global:MockCounter
}

function Assert-MockCalled {
    param([string]$CommandName, [int]$Times = 1, [string]$Message = "")
    $count = $Global:MockCalls[$CommandName] -as [int]
    if ($count -lt $Times) { throw "Mock $CommandName was not called expected times. $Message" }
}

function Assert-NotNull { param($Value, $Message) if ($null -eq $Value) { throw $Message } }
function Assert-True { param($Condition, $Message) if (-not $Condition) { throw $Message } }
function Assert-False { param($Condition, $Message) if ($Condition) { throw $Message } }
function Assert-Equal { param($Expected, $Actual, $Message) if ($Expected -ne $Actual) { throw "$Message (expected: $Expected, actual: $Actual)" } }
function Assert-PathExists { param([string]$Path, $Message) if (-not (Test-Path $Path)) { throw $Message } }
function Assert-Contains { param($Collection, $Item, $Message) if ($Collection -is [string]) { if ($Collection -notlike "*${Item}*") { throw $Message } } else { if (-not ($Collection -contains $Item)) { throw $Message } } }

Export-ModuleMember -Function *
