#requires -version 2

<#
.SYNOPSIS
    AU install script

.NOTES
    Always install AU versionless in Program Files to support older PowerShell versions ( v < 5 )
    Multiple AU versions can be installed using Install-Module if needed (on Posh 5+).
#>
param(
    #If given it is path to the module to be installed.
    #If not given, use first build directory and if doesn't exist, try scripts folder.
    [string] $module_path,

    #Remove module from the system.
    [switch] $Remove
)

$ErrorActionPreference = 'Stop'

$module_name = 'AU'

if ($PSVersionTable.PSEdition -ne "Core") {
    $module_dst  = "$Env:ProgramFiles\WindowsPowerShell\Modules"
} else {
    $module_dst  = "$Env:ProgramFiles\PowerShell\Modules"
}

Remove-Item -Force -Recurse "$module_dst\$module_name" -ErrorAction ignore
if ($Remove) { remove-module $module_name -ea ignore; Write-Host "Module $module_name removed"; return }

Write-Host "`n==| Starting $module_name installation`n"

if (!$module_path) {
    if (Test-Path $PSScriptRoot\_build\*) {
        $module_path = (Get-ChildItem $PSScriptRoot\_build\* -ea ignore | Sort-Object CreationDate -desc | Select-Object -First 1 -Expand FullName) + '/' + $module_name
    } else {
        $module_path = "$PSScriptRoot\$module_name"
        if (!(Test-Path $module_path)) { throw "module_path not specified and scripts directory doesn't contain the module" }
    }
}
$module_path = Resolve-Path $module_path

if (!(Test-Path $module_path)) { throw "Module path invalid: '$module_path'" }

Write-Host "Module path: '$module_path'"

New-Item -ItemType Directory "$module_dst/$module_name" -ErrorAction Ignore | Out-Null

Copy-Item -Recurse -Force  $module_path $module_dst

$res = Get-Module $module_name -ListAvailable | Where-Object { (Split-Path $_.ModuleBase) -eq $module_dst }
if (!$res) { throw 'Module installation failed' }

Write-Host "`n$($res.Name) version $($res.Version) installed successfully at '$module_dst\$module_name'"

$functions = $res.ExportedFunctions.Keys

import-module $module_dst\$module_name -force
$aliases = get-alias | Where-Object { $_.Source -eq $module_name }

if ($functions.Length) {
$functions | ForEach-Object {
    [PSCustomObject]@{ Function = $_; Alias = $aliases | Where-Object Definition -eq $_ }
} | ForEach-Object { Write-Host ("`n  {0,-20} {1}`n  --------             -----" -f 'Function', 'Alias') } {
    Write-Host ("  {0,-20} {1}" -f $_.Function, "$($_.Alias)")
}
}

remove-module $module_name
Write-Host "`nTo learn more about ${module_name}:      man about_${module_name}"
Write-Host "See help for any function:   man updateall`n"
