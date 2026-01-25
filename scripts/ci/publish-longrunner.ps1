param(
    [string]$OutputDir = './artifacts/longrunner/win-x64'
)

Write-Host "Publishing LongRunner to: $OutputDir"
if (-not (Test-Path 'test-helpers/LongRunner')) {
    Write-Host 'No LongRunner project found at test-helpers/LongRunner; skipping.'
    exit 0
}

try {
    $publishArgs = @('test-helpers/LongRunner/LongRunner.csproj','-c','Release','-r','win-x64','--self-contained','true','-o',$OutputDir)
    dotnet publish @publishArgs
    $exe = Join-Path $OutputDir 'LongRunner.exe'
    if (Test-Path $exe) {
        Write-Host "Published LongRunner exe: $exe"
        exit 0
    } else {
        Write-Error "LongRunner publish did not produce exe at: $exe"
        exit 2
    }
} catch {
    Write-Error "LongRunner publish failed: $($_.Exception.Message)"
    exit 1
}
