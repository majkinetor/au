function Test-Package() {
    cpack

    $package_file = gi *.nupkg | sort -Descending | select -First 1
    $package_name = $package_file.Name  -replace '(\.\d+)+\.nupkg$'

    #https://github.com/chocolatey/choco/wiki/CreatePackages#testing-your-package
    cinst $package_name --source "'$pwd;https://chocolatey.org/api/v2/'" --force
}
