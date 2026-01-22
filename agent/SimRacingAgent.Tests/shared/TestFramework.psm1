# Minimal test framework shim for local unit tests

## Module-scoped test session and mock containers with fallback to globals for compatibility
if (-not $Script:TestSession) { if ($Global:TestSession) { $Script:TestSession = $Global:TestSession } else { $Script:TestSession = $null } }
if (-not $Script:MockFunctions) { if ($Global:MockFunctions) { $Script:MockFunctions = $Global:MockFunctions } else { $Script:MockFunctions = @{} } }
if (-not $Script:MockCalls) { if ($Global:MockCalls) { $Script:MockCalls = $Global:MockCalls } else { $Script:MockCalls = @{} } }
if (-not $Script:MockTimestamps) { if ($Global:MockTimestamps) { $Script:MockTimestamps = $Global:MockTimestamps } else { $Script:MockTimestamps = @{} } }
if (-not $Script:MockOrders) { if ($Global:MockOrders) { $Script:MockOrders = $Global:MockOrders } else { $Script:MockOrders = @{} } }
if (-not $Script:MockCounter) { if ($Global:MockCounter) { $Script:MockCounter = $Global:MockCounter } else { $Script:MockCounter = 0 } }

# Load adapter stubs providing compatibility functions expected by tests
try {
    $adapter = Join-Path $PSScriptRoot "AdapterStubs.psm1"
    if (Test-Path $adapter) { Import-Module $adapter -Force -ErrorAction SilentlyContinue }
}
catch {}

function Start-TestSession {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string]$SessionName)
    if ($PSCmdlet.ShouldProcess($SessionName, 'Initialize test session')) {
        $Script:TestSession = @{ Name = $SessionName; Results = @(); Summary = @{ Passed = 0; Failed = 0; Skipped = 0 }; Success = $true }
    }
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
        try { Clear-AllMocks } catch { Write-Verbose "Clear-AllMocks pretest failed: $($_.Exception.Message)" }
        # Log pre-test mock state
        try {
            $preKeys = $Script:MockFunctions.Keys -join ','
            $preOrders = ($Script:MockOrders.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','
            "$((Get-Date).ToString('o')) PRETEST MockKeys=$preKeys MockOrders=$preOrders" | Out-File -FilePath (Join-Path $PSScriptRoot '..\..\..\.tmp_test_trace.txt') -Append -Encoding utf8
        } catch {}

        & $TestScript
        # Log post-test mock state
        try {
            $postKeys = $Script:MockFunctions.Keys -join ','
            $postOrders = ($Script:MockOrders.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ','
            "$((Get-Date).ToString('o')) POSTTEST MockKeys=$postKeys MockOrders=$postOrders" | Out-File -FilePath (Join-Path $PSScriptRoot '..\..\..\.tmp_test_trace.txt') -Append -Encoding utf8
        } catch {}
        $Script:TestSession.Summary.Passed++
        $Script:TestSession.Results += @{ Name = $Name; Category = $Category; Success = $true }
        Write-Output "[PASS] $Category - $Name"
    }
    catch {
        $Script:TestSession.Summary.Failed++
        $Script:TestSession.Results += @{ Name = $Name; Category = $Category; Success = $false; Error = $_.Exception.Message }
        $Script:TestSession.Success = $false
        Write-Output "[FAIL] $Category - $Name : $($_.Exception.Message)"
        # On failure, dump mock state and attempt to capture USBDevices for diagnosis
        try {
            $tracePath = (Join-Path $PSScriptRoot '..\..\..\.tmp_test_trace.txt')
            $keys = if ($Script:MockFunctions) { $Script:MockFunctions.Keys -join ',' } else { '<none>' }
            $orders = if ($Script:MockOrders) { ($Script:MockOrders.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ',' } else { '<none>' }
            "$((Get-Date).ToString('o')) FAILURE $Category - $Name MockKeys=$keys MockOrders=$orders Error=$($_.Exception.Message)" | Out-File -FilePath $tracePath -Append -Encoding utf8
            try {
                $devs = Get-USBDevices
                "$((Get-Date).ToString('o')) FAILURE_CAPTURE DevicesCount=$($devs.Count)" | Out-File -FilePath $tracePath -Append -Encoding utf8
                if ($devs -and $devs.Count -gt 0) { $devs | ForEach-Object { "DeviceDump: $($_.DeviceID) | $($_.Description)" } | Out-File -FilePath $tracePath -Append -Encoding utf8 }
            } catch { "$((Get-Date).ToString('o')) FAILURE_CAPTURE Get-USBDevices threw: $($_.Exception.Message)" | Out-File -FilePath $tracePath -Append -Encoding utf8 }
        } catch { Write-Verbose "Failure trace write failed: $($_.Exception.Message)" }
    }
    finally {
        if ($Teardown) { & $Teardown }
        # Ensure mocks are cleared between tests to avoid cross-test pollution
        try { Clear-AllMocks } catch { Write-Verbose "Clear-AllMocks posttest failed: $($_.Exception.Message)" }
    }
}

function Complete-TestSession {
    return @{ Success = $Script:TestSession.Success; Results = $Script:TestSession.Results; Summary = $Script:TestSession.Summary }
}

function Clear-AllMocks {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Mocks','Clear all mocks')) { return }

    foreach ($name in $Script:MockFunctions.Keys) {
        if (Get-Command $name -ErrorAction SilentlyContinue) {
            Remove-Item -Path "function:\Global\$name" -ErrorAction SilentlyContinue
        }
    }

    # Clear both script and global containers to remain compatible with older modules
    if (Get-Variable -Scope Global -Name MockFunctions -ErrorAction SilentlyContinue) { (Get-Variable -Scope Global -Name MockFunctions -ValueOnly).Clear() }
    if (Get-Variable -Scope Global -Name MockCalls -ErrorAction SilentlyContinue) { (Get-Variable -Scope Global -Name MockCalls -ValueOnly).Clear() }
    if (Get-Variable -Scope Global -Name MockTimestamps -ErrorAction SilentlyContinue) { (Get-Variable -Scope Global -Name MockTimestamps -ValueOnly).Clear() }
    if (Get-Variable -Scope Global -Name MockOrders -ErrorAction SilentlyContinue) { (Get-Variable -Scope Global -Name MockOrders -ValueOnly).Clear() }

    $Script:MockFunctions.Clear()
    $Script:MockCalls.Clear()
    $Script:MockTimestamps.Clear()
    $Script:MockOrders.Clear()
    $Script:MockCounter = 0
    if (Get-Variable -Scope Global -Name MockCounter -ErrorAction SilentlyContinue) { Set-Variable -Scope Global -Name MockCounter -Value $Script:MockCounter }
}

function New-Mock {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)] [string]$CommandName,
        [Parameter(Mandatory)] [scriptblock]$MockWith,
        [hashtable]$ParameterFilter
    )
    if (-not $PSCmdlet.ShouldProcess($CommandName, 'Register mock')) { return }
    # Register mock implementation and bookkeeping. Do not create a global function wrapper
    # so module functions are not shadowed by mocks; modules should consult $Script:MockFunctions
    $Script:MockFunctions[$CommandName] = $MockWith
    $Script:MockCalls[$CommandName] = 0
    $Script:MockTimestamps[$CommandName] = (Get-Date).ToUniversalTime()
    $Script:MockCounter = ($Script:MockCounter -as [int]) + 1
    $Script:MockOrders[$CommandName] = $Script:MockCounter
    # Keep a mirrored global copy for backwards compatibility with modules that read $Global:Mock* directly
    if (-not (Get-Variable -Scope Global -Name MockFunctions -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name MockFunctions -Value @{} }
    if (-not (Get-Variable -Scope Global -Name MockCalls -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name MockCalls -Value @{} }
    if (-not (Get-Variable -Scope Global -Name MockTimestamps -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name MockTimestamps -Value @{} }
    if (-not (Get-Variable -Scope Global -Name MockOrders -ErrorAction SilentlyContinue)) { Set-Variable -Scope Global -Name MockOrders -Value @{} }
    (Get-Variable -Scope Global -Name MockFunctions -ValueOnly).$CommandName = $MockWith
    (Get-Variable -Scope Global -Name MockCalls -ValueOnly).$CommandName = 0
    (Get-Variable -Scope Global -Name MockTimestamps -ValueOnly).$CommandName = $Script:MockTimestamps[$CommandName]
    (Get-Variable -Scope Global -Name MockOrders -ValueOnly).$CommandName = $Script:MockOrders[$CommandName]
    Set-Variable -Scope Global -Name MockCounter -Value $Script:MockCounter
}

function Assert-MockCalled {
    param([string]$CommandName, [int]$Times = 1, [string]$Message = "")
    $countScript = 0
    $countGlobal = 0
    if ($Script:MockCalls -and $Script:MockCalls.ContainsKey($CommandName)) { $countScript = ($Script:MockCalls[$CommandName] -as [int]) }
    if (Get-Variable -Scope Global -Name MockCalls -ErrorAction SilentlyContinue) {
        $g = (Get-Variable -Scope Global -Name MockCalls -ValueOnly)
        if ($g -and $g.ContainsKey($CommandName)) { $countGlobal = ($g[$CommandName] -as [int]) }
    }
    # Use the larger observed count to be tolerant of differing container references across module boundaries
    $count = [math]::Max($countScript, $countGlobal)
    if ($count -lt $Times) { throw "Mock $CommandName was not called expected times. $Message" }
}

function Assert-NotNull { param($Value, $Message) if ($null -eq $Value) { throw $Message } }
function Assert-True { param($Condition, $Message) if (-not $Condition) { throw $Message } }
function Assert-False { param($Condition, $Message) if ($Condition) { throw $Message } }
function Assert-Equal { param($Expected, $Actual, $Message) if ($Expected -ne $Actual) { throw "$Message (expected: $Expected, actual: $Actual)" } }
function Assert-PathExists { param([string]$Path, $Message) if (-not (Test-Path $Path)) { throw $Message } }
function Assert-Contains { param($Collection, $Item, $Message) if ($Collection -is [string]) { if ($Collection -notlike "*${Item}*") { throw $Message } } else { if (-not ($Collection -contains $Item)) { throw $Message } } }

function Clear-TestEnvironment {
    [CmdletBinding()]
    param()

    try {
        # Resolve workspace root without using Resolve-Path to avoid host parsing issues
        $candidateRoot = Join-Path $PSScriptRoot '..\..\..'
        if (Test-Path $candidateRoot) { $root = (Get-Item -LiteralPath $candidateRoot -ErrorAction SilentlyContinue).FullName } else { $root = $candidateRoot }
        $tmpTrace = Join-Path $root '.tmp_test_trace.txt'
        if (Test-Path $tmpTrace) { Remove-Item $tmpTrace -Force -ErrorAction SilentlyContinue }

        $testResults = Join-Path $root 'TestResults'
        if (Test-Path $testResults) { Remove-Item $testResults -Recurse -Force -ErrorAction SilentlyContinue }

        $logs = Join-Path $root 'logs'
        if (Test-Path $logs) { Get-ChildItem -Path $logs -File -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } }

        # Remove any temp USBDeviceManager debug files
        $tmpUsbDir = Join-Path $env:TEMP 'USBDeviceManager'
        if (Test-Path $tmpUsbDir) { Get-ChildItem -Path $tmpUsbDir -File -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } }

        return $true
    }
    catch {
        Write-Warning "Clear-TestEnvironment failed: $($_.Exception.Message)"
        return $false
    }
}

Export-ModuleMember -Function *




