param(
    $Info,
    [string] $Type = 'markdown',
    [string] $Path = 'update_report.md'
)

$Type = "$PSScriptRoot\Report\$Type.ps1"
if (!(Test-Path $Type )) { throw "Report type not found: '$Type" }

$result = & $Type
$result | Out-File $Path
