# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 22-Oct-2016.

<#
.SYNOPSIS
    Get AU packages

.DESCRIPTION

    Returns list of directories that have update.ps1 script in them and package name
    doesn't start with the '_' char (unpublished packages, not considered by Update-AUPackages
    function).

    Function looks in the directory pointed to by the global variable $au_root or, if not set, 
    the current directory.

.EXAMPLE
    gau p*

    Get all automatic packages that start with 'p' in the current directory.

.EXAMPLE
    $au_root = 'c:\packages'; lsau p*

    Get all automatic packages that start with 'p' in the directory 'c:\packages'.
#>
function Get-AUPackages( [string] $Name ) {
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
