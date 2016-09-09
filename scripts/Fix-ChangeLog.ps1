#requires -version 3.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Version] $Version
)

$changelog_path = Resolve-Path $PSScriptRoot\..\CHANGELOG.md

$clog = gc $changelog_path -Raw
$res = $clog -match '(?<=## NEXT)(.|\n)+?(?=\n##)'
if (!$res) { throw "Can't find header NEXT in the CHANGELOG.md" }
$release_notes = $Matches[0]

$clog -replace '(?<=\n)## NEXT\s*', "`$0`n## $Version`n" | sc $changelog_path -Encoding ascii

$release_notes
