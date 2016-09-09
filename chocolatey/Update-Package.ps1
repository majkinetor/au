[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$ReleaseNotes
)

$nuspec_path = "$PSScriptRoot\au.nuspec"

Write-Verbose 'Setting description'
$readme_path = Resolve-Path $PSScriptRoot\..\README.md
$readme      = gc $readme_path -Raw
$res         = $readme -match '## Features(.|\n)+?(?=\n##)'
if (!$res) { throw "Can't find markdown header 'Features' in the README.md" }

$features    = $Matches[0]
$description = $au.package.metadata.summary + ".`n`n" + $features

Write-Verbose 'Updating nuspec file'
[xml]$au = gc $nuspec_path
$au.package.metadata.version        = $Version
$au.package.metadata.description    = $description
$au.package.metadata.releaseNotes   = $ReleaseNotes
$au.Save($nuspec_path)

Write-Verbose 'Copying module'
cp -Force -Recurse $PSScriptRoot\..\AU $PSScriptRoot\tools
cp $PSScriptRoot\..\install.ps1 $PSScriptRoot\tools
choco pack
