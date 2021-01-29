# Author: Thomas DÃ©moulins <tdemoulins@gmail.com>

<#
.SYNOPSIS
    Parses a semver-like object from a string in a flexible manner.

.DESCRIPTION
    This function parses a string containing a semver-like version
    and returns an object that represents both the version (with up to 4 parts)
    and optionally a pre-release and a build metadata.

    The parsing is quite flexible:
    - the version can be in the middle of a url or sentence
    - first version found is returned
    - there can be no hyphen between the version and the pre-release
    - extra spaces are ignored
    - optional delimiters can be provided to help parsing the string

.EXAMPLE
    Get-Version 'Last version: 1.2.3 beta 3.'

    Returns 1.2.3-beta3

.EXAMPLE
    Get-Version 'https://github.com/atom/atom/releases/download/v1.24.0-beta2/AtomSetup.exe'

    Return 1.24.0-beta2

.EXAMPLE
    Get-Version 'http://mirrors.kodi.tv/releases/windows/win32/kodi-17.6-Krypton-x86.exe' -Delimiter '-'

    Return 17.6
#>
function Get-Version {
    [CmdletBinding()]
    param(
        # Version string to parse.
        [Parameter(Mandatory=$true)]
        [string] $Version,
        # Optional delimiter(s) to help locate the version in the string: the version must start and end with one of these chars.
        [char[]] $Delimiter
    )
    if ($Delimiter) {
        $delimiters = $Delimiter -join ''
        @('\', ']', '^', '-') | ForEach-Object { $delimiters = $delimiters.Replace($_, "\$_") }
        $regex = $Version | Select-String -Pattern "[$delimiters](\d+\.\d+[^$delimiters]*)[$delimiters]" -AllMatches
        foreach ($match in $regex.Matches) {
            $reference = [ref] $null
            if ([AUVersion]::TryParse($match.Groups[1], $reference, $false)) {
                return $reference.Value
            }
        }
    }
    return [AUVersion]::Parse($Version, $false)
}
