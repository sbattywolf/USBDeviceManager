$paths = @(
    "server/USBDeviceManager/Controllers",
    "server/USBDeviceManager/Filters",
    "server/USBDeviceManager/Hubs"
)

$methodRegex = '^(\s*(public|private|internal|protected)\s+[\w<>,\s\[\]]+\s+\w+\s*\((.*?)\)\s*(\{|;|=>))'
$paramNameRegex = '\b([a-zA-Z_][a-zA-Z0-9_]*)\b'

foreach ($p in $paths) {
    Get-ChildItem -Path $p -Filter *.cs -Recurse | ForEach-Object {
        $file = $_.FullName
        $lines = Get-Content -Raw -Path $file -ErrorAction SilentlyContinue -Encoding UTF8 | Out-String -Stream
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match $methodRegex) {
                $sig = $Matches[1]
                $paramList = $Matches[3]
                if ($paramList.Trim().Length -eq 0) { continue }
                # extract param names from signature
                $paramNames = @()
                $paramList -split ',' | ForEach-Object {
                    $pseg = $_.Trim()
                    # remove attributes
                    $pseg = $pseg -replace '^\[.*?\]\s*', ''
                    # remove modifiers and types
                    $parts = $pseg -split '\s+'
                    if ($parts.Length -ge 2) {
                        $name = $parts[-1]
                        # strip default values
                        $name = ($name -split '=')[0].Trim()
                        # strip params/ref/out/in
                        $name = $name -replace '^(ref|out|in|params)\s+', ''
                        if ($name -match $paramNameRegex) { $paramNames += $name }
                    }
                }
                if ($paramNames.Count -eq 0) { continue }
                # gather up to 12 lines above for xml doc
                $docStart = [Math]::Max(0,$i-12)
                $docLines = $lines[$docStart..($i-1)]
                $docParamNames = $docLines | Where-Object { $_ -match '///\s*<param\s+name="([^"]+)"' } | ForEach-Object { ($_ -replace '.*<param\s+name="([^"]+)".*','$1').Trim() }
                $missing = $paramNames | Where-Object { $docParamNames -notcontains $_ }
                if ($missing.Count -gt 0) {
                    Write-Output "MISSING PARAM DOCS: $file : line $($i+1)"
                    Write-Output "  Method signature: $sig"
                    Write-Output "  Parameters: $($paramNames -join ', ')"
                    Write-Output "  Documented params: $($docParamNames -join ', ')"
                    Write-Output "  Missing: $($missing -join ', ')"
                    Write-Output ""
                }
            }
        }
    }
}
