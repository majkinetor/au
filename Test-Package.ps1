function Test-Package() {
    choco pack

    $package_file    = Get-Item *.nupkg | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    $package_name    = $package_file.Name  -replace '(\.\d+)+\.nupkg$'
    $package_version = ($package_file.BaseName -replace $package_name).Substring(1)

    #https://github.com/chocolatey/choco/wiki/CreatePackages#testing-your-package
    cinst $package_name --version $package_version --source "'$pwd;https://chocolatey.org/api/v2/'" --force
}
