# Always install AU versionless in Program Files to support older PowerShell versions ( v < 5 )
# Multiple AU versions can be installed using Install-Module if needed (on Posh 5+).

$ErrorActionPreference = 'Stop'
$module_name = Split-Path -Leaf $PSScriptRoot

$module_src = gi $PSScriptRoot\$module_name
$module_dst = "$Env:ProgramFiles\WindowsPowerShell\Modules"

rm -Recurse "$module_dst\$module_name" -ErrorAction ignore
cp -Recurse  $module_src $module_dst

$res = Get-Module $module_name -ListAvailable | ? { (Split-Path $_.ModuleBase) -eq $module_dst }
if (!$res) { throw 'Module installation failed' }

"`n$($res.Name) version $($res.Version) installed successfully at '$module_dst'"

$functions = $res.ExportedFunctions.Keys

import-module $module_dst\$module_name -force
$aliases = get-alias | ? { $_.Source -eq $module_name }

$functions | % {
    [PSCustomObject]@{ Function = $_; Alias = $aliases | ? Definition -eq $_ }
} | ft -auto

