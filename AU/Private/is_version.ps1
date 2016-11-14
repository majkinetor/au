# Returns [bool]
function is_version( [string] $Version ) {
    $re = '^(\d{1,16})\.(\d{1,16})\.*(\d{1,16})*\.*(\d{1,16})*(-[^.-]+)*$'
    if ($Version -notmatch $re) { return $false }

    $v = $Version -replace '-.+'
    return [version]::TryParse($v, [ref]($__))
}
