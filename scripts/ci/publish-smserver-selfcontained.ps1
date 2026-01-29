param(
    [string] $Configuration = 'Release',
    [string] $Runtime = 'win-x64',
    [string] $OutputPath = (Join-Path $PSScriptRoot '..\..\server\USBDeviceManager\bin\Release\net8.0\publish'),
    [switch] $Force
)

function Write-Log { param($m) Write-Host "[publish-smserver] $m" }

$csproj = Join-Path $PSScriptRoot '..\..\server\USBDeviceManager\USBDeviceManager.csproj'
if (-not (Test-Path $csproj)) { Write-Log "CSProj not found at $csproj; aborting."; exit 2 }

Write-Log "Publishing $csproj -> Runtime=$Runtime Configuration=$Configuration Output=$OutputPath"
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

$pubArgs = @('publish', $csproj, '-c', $Configuration, '-r', $Runtime, '--self-contained', 'true', '/p:PublishSingleFile=true', '/p:IncludeAllContentForSelfExtract=true', '-o', $OutputPath)
Write-Log ("dotnet " + ($pubArgs -join ' '))

$p = Start-Process -FilePath 'dotnet' -ArgumentList $pubArgs -NoNewWindow -Wait -PassThru
if ($p.ExitCode -ne 0) { Write-Log "dotnet publish failed with exit code $($p.ExitCode)"; exit $p.ExitCode }

# find the exe produced
$exe = Get-ChildItem -Path $OutputPath -Filter *.exe -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) { Write-Log "Published exe not found in $OutputPath"; exit 3 }

$destDir = Join-Path (Split-Path $csproj -Parent) 'bin\Release\net8.0'
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$dest = Join-Path $destDir 'SMServer.exe'

Write-Log "Copying $($exe.FullName) -> $dest"
Copy-Item $exe.FullName -Destination $dest -Force

Write-Log "Publish complete; SMServer available at $dest"
exit 0
