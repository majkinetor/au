# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 16-Sep-2016.

<#
.SYNOPSIS
    Get AU packages

.DESCRIPTION

    Returns list of directories that have update.ps1 script in them and package name
    doesnt' start with the '_' char (unpublished packages, not considered by Update-AUPackages
    function)

.EXAMPLE
    gau p*

    Get all automatic packages that start with 'p'.
#>

function Get-AUPackages($Name=$null) {
    $root = $global:au_root
    if (!$root) { $root = '.' }
    ls $root\*\update.ps1 | % {
        $packageDir = gi (Split-Path $_)
        if ($packageDir.Name -like '_*') { return }
        if ($Name) {
            if ( $packageDir.Name -like "$Name" ) { $packageDir }
        } else { $packageDir }
    }
}

Set-Alias gau  Get-AuPackages
Set-Alias lsau Get-AuPackages
