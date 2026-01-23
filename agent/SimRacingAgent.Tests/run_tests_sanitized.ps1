# Minimal sanitized runner bootstrap
# Dot-source adapter stubs and test framework, copy new functions to Global scope, then dot-source TestRunner and invoke suite.

$P = $PSScriptRoot

# copy newly introduced functions into Function:\Global
function Copy-NewFunctionsToGlobal([string[]]$pre) {
    $post = Get-Command -CommandType Function | Select-Object -ExpandProperty Name
    $new = $post | Where-Object { $pre -notcontains $_ }
    foreach ($fn in $new) {
        try {
            $cmd = Get-Command -Name $fn -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.ScriptBlock) {
                Set-Item -Path ("Function:\Global\{0}" -f $fn) -Value $cmd.ScriptBlock -Force
            }
        } catch {
            Write-Verbose "Failed to copy function $($fn): $($_.Exception.Message)"
        }
    }
}

# Load AdapterStubs
$pre = Get-Command -CommandType Function | Select-Object -ExpandProperty Name
$adapter = Join-Path $P 'shared\AdapterStubs.psm1'
if (Test-Path $adapter) { try { . $adapter } catch { Write-Warning "Failed to dot-source AdapterStubs: $($_.Exception.Message)" } }
Copy-NewFunctionsToGlobal -pre $pre

# Load TestFramework
$pre = Get-Command -CommandType Function | Select-Object -ExpandProperty Name
$tf = Join-Path $P 'shared\TestFramework.psm1'
if (Test-Path $tf) { try { . $tf } catch { Write-Warning "Failed to dot-source TestFramework: $($_.Exception.Message)" } }
Copy-NewFunctionsToGlobal -pre $pre

# Execute TestRunner in a fresh PowerShell process to avoid in-process parser fragility
$runner = Join-Path $P 'TestRunner.ps1'
if (-not (Test-Path $runner)) { Write-Error "TestRunner.ps1 not found at $runner"; exit 2 }

$psExe = (Get-Command powershell -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = 'powershell' }

$outFile = Join-Path $P 'run_tests_sanitized.out'
$errFile = Join-Path $P 'run_tests_sanitized.err'

$args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-GenerateReport','-ReportPath','scripts/tmp/reports','-Verbose')

Write-Host "Starting TestRunner in external process..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $psExe -ArgumentList $args -Wait -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile

if ($proc.ExitCode -ne 0) {
    Write-Error "TestRunner process exited with code $($proc.ExitCode). See $outFile and $errFile for details."
    if (Test-Path $errFile) { Get-Content $errFile | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
    exit $proc.ExitCode
}

Write-Host "TestRunner completed successfully. Output saved to $outFile" -ForegroundColor Green
