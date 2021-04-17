# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 22-Oct-2016.

<#
.SYNOPSIS
    Push latest (or all) created package(s) to the Chocolatey community repository.

.DESCRIPTION
    The function uses they API key from the file api_key in current or parent directory, environment variable
    or cached nuget API key.
#>
function Push-Package() {
    param(
        [switch] $All
    )
    $api_key =  if (Test-Path api_key) { Get-Content api_key }
                elseif (Test-Path (Join-Path '..' 'api_key')) { Get-Content (Join-Path '..' 'api_key') }
                elseif ($Env:api_key) { $Env:api_key }

    $push_url =  if ($Env:au_PushUrl) { $Env:au_PushUrl }
                 else { 'https://push.chocolatey.org' }
                 
    $force_push = if ($Env:au_ForcePush) { '--force' }
                  else { '' }

    $packages = Get-ChildItem *.nupkg | Sort-Object -Property CreationTime -Descending
    if (!$All) { $packages = $packages | Select-Object -First 1 }
    if (!$packages) { throw 'There is no nupkg file in the directory'}
    if ($api_key) {
        $packages | ForEach-Object { choco push $_.Name --api-key $api_key --source $push_url $force_push }
    } else {
        $packages | ForEach-Object { choco push $_.Name --source $push_url $force_push }
    }
}
