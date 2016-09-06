function Push-Package() {
    $api_key =  if (Test-Path api_key) { Get-Content api_key }
                elseif (Test-Path ..\api_key) { Get-Content ..\api_key }
                elseif ($Env:api_key) { $Env:api_key }

    $package = Get-ChildItem *.nupkg | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    if (!$package) { throw 'There is no nupkg file in the directory'}
    if ($api_key) {
        cpush $package.Name --api-key $api_key
    } else {
        cpush $package.Name
    }
}
Set-Alias pp Push-Package
