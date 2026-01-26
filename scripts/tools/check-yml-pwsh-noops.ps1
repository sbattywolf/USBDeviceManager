<#
Checks .github/workflows/*.yml for `shell: pwsh` run blocks that contain POSIX `|| true` patterns.
Prints file, line numbers, and the offending run-block content for manual review.
#>

Get-ChildItem -Path .github/workflows -Filter *.yml -File -Recurse | ForEach-Object {
    $path = $_.FullName
    $arr = Get-Content $path -ErrorAction Stop -Encoding UTF8
    for ($i = 0; $i -lt $arr.Length; $i++) {
        if ($arr[$i].Trim() -eq 'shell: pwsh') {
            # find the next 'run:' line
            $j = $i + 1
            while ($j -lt $arr.Length -and ($arr[$j].Trim() -notlike 'run:*')) { $j++ }
            if ($j -ge $arr.Length) { continue }
            # collect the run block lines until next blank line or next step (line starting with '-' at column 0)
            $k = $j + 1
            $block = @()
            while ($k -lt $arr.Length) {
                $ln = $arr[$k]
                if ($ln.Trim() -eq '') { break }
                if ($ln -match '^[ \t]*- name:') { break }
                if ($ln.TrimStart().StartsWith('shell:')) { break }
                $block += $ln
                $k++
            }
            $content = $block -join "`n"
            if ($content -match '\|\| true' -or $content -match '; true;') {
                Write-Output "File: $path (shell: pwsh at line $($i+1))"
                Write-Output "Run block (lines $($j+1)-$($k)) containing POSIX no-op:"
                Write-Output "----"
                Write-Output $content
                Write-Output "----`n"
            }
        }
    }
}

exit 0
