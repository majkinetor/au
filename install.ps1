#requires -version 2

# Always install AU versionless in Program Files to support older PowerShell versions ( v < 5 )
# Multiple AU versions can be installed using Install-Module if needed (on Posh 5+).

param(
    [string] $module_path,  #if empty use latest build
    [switch] $Remove
)

$ErrorActionPreference = 'Stop'

$module_name = 'AU'
$module_dst  = "$Env:ProgramFiles\WindowsPowerShell\Modules"
if (!$module_path) {
    if (!(Test-Path $PSScriptRoot\_build\*)) { throw "module_path not specified and latest build doesn't exist" }
    $module_path = (ls $PSScriptRoot\_build\* -ea ignore | sort CreationDate -desc | select -First 1 -Expand FullName) + '/' + $module_name
}
$module_path = Resolve-Path $module_path

rm -Force -Recurse "$module_dst\$module_name" -ErrorAction ignore
if ($Remove) { remove-module au -ea ignore; Write-Host "Module AU removed"; return }

Write-Host "`n==| Starting AU installation`n"

if (!(Test-Path $module_path)) { throw "Module path invalid: '$module_path'" }

Write-Host "Module path: '$module_path'"

cp -Recurse -Force  $module_path $module_dst

$res = Get-Module $module_name -ListAvailable | ? { (Split-Path $_.ModuleBase) -eq $module_dst }
if (!$res) { throw 'Module installation failed' }

Write-Host "`n$($res.Name) version $($res.Version) installed successfully at '$module_dst\$module_name'"

$functions = $res.ExportedFunctions.Keys

import-module $module_dst\$module_name -force
$aliases = get-alias | ? { $_.Source -eq $module_name }
remove-module au

$functions | % {
    [PSCustomObject]@{ Function = $_; Alias = $aliases | ? Definition -eq $_ }
} | ft -auto | Out-String | Write-Host

Write-Host "To learn more type 'man about_au'.`n"
