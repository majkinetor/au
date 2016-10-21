function New-AUPackage( [string] $Path ) {
    if ([String]::IsNullOrWhiteSpace( $Path )) { throw 'Path can not be empty' }

    $package = [PSCustomObject]@{
        Path          = $Path
        Name          = Split-Path $Path -Leaf
        Updated       = $false
        Pushed        = $false
        RemoteVersion = ''
        NuspecVersion = ''
        Result        = @()
        Error         = ''
    }
    $package.PSObject.TypeNames.Insert(0, 'AUPackage')
    $package
}
