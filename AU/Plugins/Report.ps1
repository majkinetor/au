param(
    $Info,
    [string] $Type = 'markdown',
    [string] $Path = 'update_report.md'
)

$Type = "$PSScriptRoot\Report\$Type.ps1"
if (!(Test-Path $Type )) { throw "Report type not found: '$Type" }

Write-Host "Saving $Type report"

$result = & $Type
$result | Out-File $Path
