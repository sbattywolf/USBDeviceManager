$art='E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager.Tests\TestResults\artifacts'
$base='SimRacingTest_20260124202624_5320'
$sample=Join-Path $art "$base-db-sample.bin"
$pathf=Join-Path $art "$base-dbpath.txt"
$log=Join-Path $art "$base-server-console.log"

Write-Host '--- SAMPLE ---'
if (Test-Path $sample) {
    $b=[System.IO.File]::ReadAllBytes($sample)
    Write-Host "SampleExists;Length:$($b.Length)"
    $hdr=[System.Text.Encoding]::ASCII.GetString($b[0..([Math]::Min(15,$b.Length-1))])
    Write-Host "Header:$hdr"
    $hex = ($b[0..([Math]::Min(63,$b.Length-1))] | ForEach-Object { $_.ToString('X2') }) -join ' '
    Write-Host "Hex64:$hex"
} else { Write-Host 'Sample missing' }

Write-Host '--- DBPATH ---'
if (Test-Path $pathf) { Get-Content $pathf | ForEach-Object { Write-Host $_ } } else { Write-Host 'dbpath missing' }

Write-Host '--- LOG (tail 200) ---'
if (Test-Path $log) { Get-Content $log -Tail 200 } else { Write-Host 'log missing' }
