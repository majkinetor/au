# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 27-Oct-2016.

<#
.SYNOPSIS
    Test Chocolatey package

.DESCRIPTION
    The function can test install, uninistall or both and provide package parameters during test.
    It will force install and then remove the Chocolatey package if called without arguments.

    It accepts either nupkg or nuspec path. If none specified, current directory will be searched
    for any of them.

.EXAMPLE
    Test-Package -Install

    Test the install of the package from the current directory.

.LINK
    https://github.com/chocolatey/choco/wiki/CreatePackages#testing-your-package
#>
function Test-Package {
    param(
        # If file, path to the .nupkg or .nuspec file for the package.
        # If directory, latest .nupkg or .nuspec file wil be looked in it.
        # If ommited current directory will be used.
        $Nu,

        # Test chocolateyInstall.ps1 only.
        [switch] $Install,

        # Test chocolateyUninstall.ps1 only.
        [switch] $Uninstall,

        # Path to chocolatey-test-environment to test package
        [string] $Vagrant = $Env:au_Vagrant,

        # Remove any other package in Vagrant 'packages' directory
        [switch] $VagrantClear,

        # Package parameters
        $Parameters
    )

    if (!$Install -and !$Uninstall) { $Install = $Uninstall = $true }

    if (!$Nu) { $dir = gi $pwd }
    else {
        if (!(Test-Path $Nu)) { throw "Path not found: $Nu" }
        $Nu = gi $Nu
        $dir = if ($Nu.PSIsContainer) { $Nu; $Nu = $null } else { $Nu.Directory }
    }

    if (!$Nu) {
        $Nu = gi $dir/*.nupkg | sort -Property CreationTime -Descending | select -First 1
        if (!$Nu) { $Nu = gi $dir/*.nuspec }
        if (!$Nu) { throw "Can't find nupkg or nuspec file in the directory" }
    }

    if ($Nu.Extension -eq '.nuspec') {
        Write-Host "Nuspec file given, running choco pack"
        choco pack -r $Nu.FullName --OutputDirectory $Nu.DirectoryName | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "choco pack failed with $LastExitCode"}
        $Nu = gi "$($Nu.DirectoryName)\*.nupkg" | sort -Property CreationTime -Descending | select -First 1
    } elseif ($Nu.Extension -ne '.nupkg') { throw "File is not nupkg or nuspec file" }

    $package_name    = $Nu.Name -replace '(\.\d+)+\.nupkg$'
    $package_version = ($Nu.BaseName -replace $package_name).Substring(1)

    Write-Host "`nPackage info"
    Write-Host "  Path:".PadRight(15)      $Nu
    Write-Host "  Name:".PadRight(15)      $package_name
    Write-Host "  Version:".PadRight(15)   $package_version
    if ($Parameters) { Write-Host "  Parameters:".PadRight(15) $Parameters }
    if ($Vagrant)    { Write-Host "  Vagrant: ".PadRight(15) $Vagrant }


    if ($Vagrant) {
        Write-Host "`nTesting package using vagrant"
        if ($VagrantClear) { Write-Host 'Removing existing vagrant packages'; rm $Vagrant\packages\*.nupkg -ea ig }
        cp $Nu $Vagrant\packages
        start powershell -Verb Open -ArgumentList "-NoExit -Command `$Env:http_proxy=`$Env:https_proxy=`$Env:ftp_proxy=`$Env:no_proxy=''; cd $Vagrant; vagrant up --provision"
        return
    }

    if ($Install) {
        Write-Host "`nTesting package install"
        choco install -y -r $package_name --version $package_version --source "'$($Nu.DirectoryName);https://chocolatey.org/api/v2/'" --force --packageParameters "'$Parameters'" | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "choco install failed with $LastExitCode"}
    }

    if ($Uninstall) {
        Write-Host "`nTesting package uninstall"
        choco uninstall -y -r $package_name | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "choco uninstall failed with $LastExitCode"}
    }
}
