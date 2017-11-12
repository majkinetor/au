# Returns [bool]
function is_version( [string] $Version ) {
    return [AUVersion]::TryParse($Version, [ref]($__))
}
