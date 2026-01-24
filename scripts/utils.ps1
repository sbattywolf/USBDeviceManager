function TryParse-Date {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object]$Value
    )

    if ($null -eq $Value) { return $null }
    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }

    # Treat common sentinel values as non-dates
    if ($s -in @('-', 'N/A', 'n/a', 'NA', 'none')) { return $null }

    $formats = @(
        'o',
        's',
        'yyyy-MM-ddTHH:mm:ss.fffZ',
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd',
        'MM/dd/yyyy',
        'yyyyMMdd-HHmmss',
        'yyyyMMddHHmmss'
    )

    $ci = [System.Globalization.CultureInfo]::InvariantCulture
    $style = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal

    foreach ($f in $formats) {
        $dt = $null
        if ([DateTime]::TryParseExact($s, $f, $ci, $style, [ref]$dt)) {
            return $dt
        }
    }

    $dt2 = $null
    if ([DateTime]::TryParse($s, $ci, $style, [ref]$dt2)) { return $dt2 }

    Write-Verbose "TryParse-Date: failed to parse input '$s'"
    return $null
}

<# Export-ModuleMember is only valid within a module scope. Dot-sourcing this script
    exposes `TryParse-Date` to the caller, so explicit export is unnecessary and
    can cause errors in CI when run outside module context. #>
