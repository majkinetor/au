# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 12-Nov-2016.

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
    $au_root = 'c:\packages'; lsau 'cpu-z*','p*','copyq'

    Get all automatic packages  in the directory 'c:\packages' that start with 'cpu-z' or 'p' and package which name is 'copyq'.
#>
function Get-AUPackages( [string[]] $Name ) {
    $root = $global:au_root
    if (!$root) { $root = $pwd }

    Get-ChildItem ([System.IO.Path]::Combine($root, '*', 'update.ps1')) | ForEach-Object {
        $packageDir = Get-Item (Split-Path $_)

        if ($Name -and $Name.Length -gt 0) {
            $m = $Name | Where-Object { $packageDir.Name -like $_ }
            if (!$m) { return }
        }

        if ($packageDir.Name -like '_*') { return }
        $packageDir
    }
}

Set-Alias gau  Get-AuPackages
Set-Alias lsau Get-AuPackages
