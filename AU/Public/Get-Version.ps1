# Author: Thomas Démoulins <tdemoulins@gmail.com>

<#
.SYNOPSIS
    Get a semver-like object from a given version string.

.DESCRIPTION
    This function parses a string containing a semver-like version
    and returns an object that represents both the version (with up to 4 parts)
    and optionally a pre-release and a build metadata.

    The parsing is quite flexible:
    - the string can starts with a 'v'
    - there can be no hyphen between the version and the pre-release
    - extra spaces (between any parts of the semver-like version) are ignored
#>
function Get-Version {
    [CmdletBinding()]
    param(
        # Version string to parse.
        [string] $Version
    )
    return [AUVersion]::Parse($Version, $false)
}
