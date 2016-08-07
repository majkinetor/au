function Test-Package() {
    cpack

    $package_file    = gi *.nupkg | sort -Property CreationTime -Descending | select -First 1
    $package_name    = $package_file.Name  -replace '(\.\d+)+\.nupkg$'
    $package_version = ($package_file.BaseName -replace $package_name).Substring(1)

    #https://github.com/chocolatey/choco/wiki/CreatePackages#testing-your-package
    cinst $package_name --version $package_version --source "'$pwd;https://chocolatey.org/api/v2/'" --force
}
