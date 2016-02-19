function Push-Package() {
    $ak = gi api_key -ea 0
    if (!$ak) { $ak = gi ../api_key -ea 0}
    if (!$ak) { throw 'File api_key not found in this or parent directory, aborting push' }

    $api_key = gc $ak
    $package = ls *.nupkg | sort -Property CreationTime -Descending | select -First 1
    if (!$package) { throw 'There is no nupkg file in the directory'}
    cpush $package.Name --api-key $api_key
}
Set-Alias pp Push-Package
