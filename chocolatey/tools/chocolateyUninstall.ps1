$ErrorActionPreference = 'Stop'

Write-Host "Uninstalling module au"
$module_dst = "$Env:ProgramFiles\WindowsPowerShell\Modules\$packageName"
rm -force -recurse $module_dst
