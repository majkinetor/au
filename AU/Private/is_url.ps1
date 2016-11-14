# Returns [bool]
function is_url([string] $Url ) {
    [Uri]::IsWellFormedUriString($URL, [UriKind]::Absolute)
}
