# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 22-Oct-2016.

<#
.SYNOPSIS
    Push latest created package to the Chocolatey community repository.

.DESCRIPTION
    The function uses they API key from the file api_key in current or parent directory, environment variable
    or cached nuget API key.
#>
function Push-Package() {
    
    $package = ls *.nupkg | sort -Property CreationTime -Descending | select -First 1
    if (!$package) { throw 'There is no nupkg file in the directory'}

    if ($env:au_SimpleServerPath) {
      try {
        Move-Item $package.Name $env:au_SimpleServerPath -ea Stop
      }
      catch {
        catch {$_.GetType().FullName}
      }
    }
    else {    
      $api_key =  if (Test-Path api_key) { gc api_key }
                  elseif (Test-Path ..\api_key) { gc ..\api_key }
                  elseif ($Env:api_key) { $Env:api_key }

      if ($api_key) {
          cpush $package.Name --api-key $api_key --source https://push.chocolatey.org 
      } else {
          cpush $package.Name --source https://push.chocolatey.org 
      }
    }
}
