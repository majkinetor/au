#  Build the chocolatey package based on the latest module build in ..\_build folder

$build_path = Resolve-Path $PSScriptRoot\..\_build
$version    = ls $build_path | sort CreationDate -desc | select -First 1 -Expand Name
$version    = $version.ToString()
if (![version]$version) { throw 'Latest module build can not be found' }

$module_path = "$build_path\$version\AU"
$nuspec_path = "$PSScriptRoot\au.nuspec"

Write-Host "`n==| Building Chocolatey package for AU $version at: '$module_path'`n"

Write-Host 'Setting description'
$readme_path = Resolve-Path $PSScriptRoot\..\README.md
$readme      = gc $readme_path -Raw
$res         = $readme -match '## Features(.|\n)+?(?=\n##)'
if (!$res) { throw "Can't find markdown header 'Features' in the README.md" }

$features    = $Matches[0]

Write-Host 'Updating nuspec file'
$nuspec_build_path = $nuspec_path -replace '\.nuspec$', '_build.nuspec'
[xml]$au = gc $nuspec_path
$description                      = $au.package.metadata.summary + ".`n`n" + $features
$au.package.metadata.version      = $version
$au.package.metadata.description  = $description
$au.package.metadata.releaseNotes = 'https://github.com/majkinetor/au/releases/tag/' + $version
$au.Save($nuspec_build_path)

Write-Host 'Copying module'
cp -Force -Recurse $module_path $PSScriptRoot\tools
cp $PSScriptRoot\..\install.ps1 $PSScriptRoot\tools

rm $PSScriptRoot\*.nupkg
choco pack $nuspec_build_path --outputdirectory $PSScriptRoot
rm $nuspec_build_path
