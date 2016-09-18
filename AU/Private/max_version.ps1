function is_updated( $package ) {
    $remote_l = $package.RemoteVersion -replace '-.+'
    $nuspec_l = $package.NuspecVersion -replace '-.+'
    $remote_r = $package.RemoteVersion -replace '.+(?=(-.+)*)'
    $nuspec_r = $package.NuspecVersion -replace '.+(?=(-.+)*)'

    if ([version]$remote_l -eq [version] $nuspec_l) {
        if (!$remote_r -and $nuspec_r) { return $true }
        if ($remote_r -and !$nuspec_r) { return $false }
        return ($remote_r -gt $nuspec_r)
    }
    [version]$remote_l -gt [version] $nuspec_l
}
