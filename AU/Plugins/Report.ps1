param(
    $Info,
    [string] $Template = 'markdown',
    [string] $Path = 'update_report.md'
)

$template = "$PSScriptRoot\Report\$Template.ps1"
if (!(Test-Path $template )) { throw "Template not found: '$Template" }

$result = & $Template
$result | Out-File $Path
