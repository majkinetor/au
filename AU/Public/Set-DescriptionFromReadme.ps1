<#
.SYNOPSIS
  Updates nuspec file description from README.md

.DESCRIPTION
  This script should be called in au_AfterUpdate to put the text in the README.md
  into description tag of the Nuspec file. The current description will be replaced.
  
  You need to call this function manually only if you want to pass it custom parameters.
  In that case use NoReadme parameter of the Update-Package.

.EXAMPLE
  function global:au_AfterUpdate  { Set-DescriptionFromReadme -Package $args[0] -SkipLast 2 -SkipFirst 2 }
#>
function Set-DescriptionFromReadme{
    param(
      [AUPackage] $Package,
      # Number of start lines to skip from the README.md, by default 0.
      [int] $SkipFirst=0, 
      # Number of end lines to skip from the README.md, by default 0.
      [int] $SkipLast=0,
      # Readme file path
      [string] $ReadmePath = 'README.md'
    )

    "Setting package description from $ReadmePath"

    $description = Get-Content $ReadmePath -Encoding UTF8
    $endIdx = $description.Length - $SkipLast
    $description = $description | Select-Object -Index ($SkipFirst..$endIdx) | Out-String

    $cdata = $Package.NuspecXml.CreateCDataSection($description)
    $xml_Description = $Package.NuspecXml.GetElementsByTagName('description')[0]
    $xml_Description.RemoveAll()
    $xml_Description.AppendChild($cdata) | Out-Null

    $Package.SaveNuspec()
}
