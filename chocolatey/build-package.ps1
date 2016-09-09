#  Build the chocolatey package based on the latest module build in ..\_build folder

[CmdletBinding()]
param(
    [string]$ReleaseNotes = 'https://github.com/majkinetor/au/blob/master/CHANGELOG.md'
)

$build_path = Resolve-Path $PSScriptRoot\..\_build
$version    = ls $build_path | sort CreationDate -desc | select -First 1 -Expand Name
if (![version]$version) { throw 'Latest module build can not be found' }

$module_path = "$build_path\$version\AU"
$nuspec_path = "$PSScriptRoot\au.nuspec"

Write-Host "==| Building Chocolatey package for AU $version at: '$module_path'`n"

Write-Host 'Setting description'
$readme_path = Resolve-Path $PSScriptRoot\..\README.md
$readme      = gc $readme_path -Raw
$res         = $readme -match '## Features(.|\n)+?(?=\n##)'
if (!$res) { throw "Can't find markdown header 'Features' in the README.md" }

$features    = $Matches[0]
$description = $au.package.metadata.summary + ".`n`n" + $features

Write-Host 'Updating nuspec file'
[xml]$au = gc $nuspec_path
$au.package.metadata.version       = $version.ToString()
$au.package.metadata.description   = $description
$au.package.metadata.releaseNotes  = $ReleaseNotes
$au.Save($nuspec_path)

Write-Host 'Copying module'
cp -Force -Recurse $module_path $PSScriptRoot\tools
cp $PSScriptRoot\..\install.ps1 $PSScriptRoot\tools

choco pack
