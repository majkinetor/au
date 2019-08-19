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
    $api_key =  if (Test-Path api_key) { gc api_key }
    elseif (Test-Path ..\api_key) { gc ..\api_key }
    elseif ($Env:api_key) { $Env:api_key }

    $push_url =  if ($Env:au_PushUrl) { $Env:au_PushUrl }
                 else { 'https://push.chocolatey.org' }

    $push_force =  if ($Env:au_PushForce -eq 'true') { $true } else { $false }

    $SecureSource =  if ($api_key) {
        $packages | % { cpush --api-key $api_key --source $push_url }
    } else {
        $packages | % { cpush --source $push_url }
    }
    
    if ( $push_force ) {
        if ( $SecureSource | select-string "The specified source `'$($push_url)`' is not secure." ) {
            Write-Output "Source is insecure. Will use -Force"
            $ForceParam = '--Force'
        } else {
            Clear-Variable -Name ForceParam
        }
    } else {
        Clear-Variable -Name ForceParam
    }

    $packages = ls *.nupkg | sort -Property CreationTime -Descending
    if (!$All) { $packages = $packages | select -First 1 }
    if (!$packages) { throw 'There is no nupkg file in the directory'}
    if ($api_key) {
        $packages | % { cpush $_.Name --api-key $api_key --source $push_url $ForceParam }
    } else {
        $packages | % { cpush $_.Name --source $push_url $ForceParam }
    }
}
