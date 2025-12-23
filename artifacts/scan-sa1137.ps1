$out = "artifacts/sa1137-locations.txt"
if(Test-Path $out){ Remove-Item $out }
Get-ChildItem -Path server/USBDeviceManager -Recurse -Filter *.cs -File | ForEach-Object {
    $path = $_.FullName
    $lines = Get-Content $path
    for($i=0;$i -lt $lines.Count;$i++){
        if($lines[$i].TrimStart().StartsWith('///')){
            $xmlIndent = ($lines[$i] -replace '^([^\S\r\n]*).*','$1').Length
            $j = $i + 1
            while($j -lt $lines.Count -and ($lines[$j].Trim() -eq '' -or $lines[$j].TrimStart().StartsWith('///') -or $lines[$j].TrimStart().StartsWith('['))){
                if($lines[$j].TrimStart().StartsWith('[')) { break }
                $j++
            }
            if($j -lt $lines.Count){
                $nextIndent = ($lines[$j] -replace '^([^\S\r\n]*).*','$1').Length
                if($xmlIndent -ne $nextIndent){
                    Add-Content -Path $out -Value ("$($path): XML line $($i+1) indent=$xmlIndent -> next non-empty line $($j+1) indent=$nextIndent")
                }
            }
        }
    }
}
Write-Output "Scan complete"
