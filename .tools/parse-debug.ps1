param([string]$Path)
$errors = $null
$tokens = $null
$text = Get-Content -Raw -LiteralPath $Path
$lines = $text -split "\r?\n"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
if ($errors) {
    foreach ($e in $errors) {
        Write-Host "Message: $($e.Message)"
        $s = $e.Extent.StartLineNumber
        $c = $e.Extent.StartColumn
        $eL = $e.Extent.EndLineNumber
        $eC = $e.Extent.EndColumn
        Write-Host ("Extent: {0}:{1} -> {2}:{3}" -f $s,$c,$eL,$eC)
        $from = [Math]::Max(1, $s - 3)
        $to = [Math]::Min($lines.Length, $eL + 3)
        Write-Host "Context:"
        for ($i = $from; $i -le $to; $i++) {
            $marker = if ($i -ge $s -and $i -le $eL) { '>>' } else { '  ' }
            $lineText = $lines[$i-1]
            Write-Host (("{0,4}: {1} {2}" -f $i, $marker, $lineText))
        }
        # Also print raw substring at byte offsets (for byte-level diagnostics)
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
            $startOff = $e.Extent.StartOffset
            $endOff = $e.Extent.EndOffset
            if ($startOff -ge 0 -and $endOff -gt $startOff -and $endOff -le $bytes.Length) {
                $sub = $text.Substring($startOff, $endOff - $startOff)
                Write-Host "Raw snippet at offsets ($startOff..$endOff):"
                Write-Host $sub
                Write-Host "Codepoints of snippet:"
                for ($j = 0; $j -lt $sub.Length; $j++) {
                    $cp = [int][char]$sub[$j]
                    Write-Host ("{0}: U+{1:X4} '{2}'" -f $j, $cp, $sub[$j])
                }
            }
        } catch {
            Write-Host "Failed to dump raw snippet: $($_.Exception.Message)"
        }
        Write-Host "----"
    }
} else {
    Write-Host 'No parse errors'
}
