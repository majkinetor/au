# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 10-Nov-2016.
<#
.SYNOPSIS
    Create different types of reports about the current run.

.DESCRIPTION
    The plugin saves state of all packages in a file that can be used locally or
    uploaded via other plugins to remote (such as Gist or Mail).
#>

param(
    $Info,

    # Type of the report, currently 'markdown' or 'text'
    [string] $Type = 'markdown',

    # Path where to save the report
    [string] $Path = 'Update-AUPackages.md',

    # Report parameters
    [HashTable] $Params
)

Write-Host "Saving $Type report: $Path"

$Type = ([System.IO.Path]::Combine($PSScriptRoot, 'Report', "$Type.ps1"))
if (!(Test-Path $Type )) { throw "Report type not found: '$Type" }

$result = & $Type
$result | Out-File $Path
