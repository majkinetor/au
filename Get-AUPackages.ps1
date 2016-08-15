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
    ls .\*\update.ps1 | % {
        $packageDir = gi (Split-Path $_)
        if ($packageDir.Name -like '_*') { return }
        if ($Name) {
            if ( $packageDir.Name -like "$Name" ) { $packageDir }
        } else { $packageDir }
    }
}
Set-Alias gau  Get-AuPackages
