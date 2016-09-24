# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 24-Sep-2016.

param(
    $Info,
    [string] $Type = 'markdown',
    [string] $Path = 'update_report.md',
    [HashTable] $Params
)

Write-Host "Saving $Type report: $Path"

$Type = "$PSScriptRoot\Report\$Type.ps1"
if (!(Test-Path $Type )) { throw "Report type not found: '$Type" }

$result = & $Type
$result | Out-File $Path
