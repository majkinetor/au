function Push-Package() {
    $api_key =  if (Test-Path api_key) { gc api_key }
                elseif (Test-Path ..\api_key) { gc ..\api_key }
                elseif ($Env:api_key) { $Env:api_key }
    if (!$api_key) { throw 'Api key not found, aborting push' }

    $package = ls *.nupkg | sort -Property CreationTime -Descending | select -First 1
    if (!$package) { throw 'There is no nupkg file in the directory'}
    cpush $package.Name --api-key $api_key
}
Set-Alias pp Push-Package
