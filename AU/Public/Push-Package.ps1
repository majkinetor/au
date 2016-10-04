# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 16-Sep-2016.

<#
.SYNOPSIS
    Push package to the Chocolatey repository

.DESCRIPTION
    The function uses they API key from the file api_key in current or parent directory, environment variable
    or cached nuget API key.
#>
function Push-Package() {
    $api_key =  if (Test-Path api_key) { gc api_key }
                elseif (Test-Path ..\api_key) { gc ..\api_key }
                elseif ($Env:api_key) { $Env:api_key }

    $package = ls *.nupkg | sort -Property CreationTime -Descending | select -First 1
    if (!$package) { throw 'There is no nupkg file in the directory'}
    if ($api_key) {
        cpush $package.Name --api-key $api_key
    } else {
        cpush $package.Name
    }
}
