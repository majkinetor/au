# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 15-Nov-2016.

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

        # Package parameters
        [string] $Parameters,

        # Path to chocolatey-test-environment: https://github.com/majkinetor/chocolatey-test-environment
        [string] $Vagrant = $Env:au_Vagrant,

        # Open new shell window
        [switch] $VagrantOpen,

        # Do not remove existing packages from vagrant package directory
        [switch] $VagrantNoClear
    )

    if (!$Install -and !$Uninstall) { $Install = $true }

    if (!$Nu) { $dir = Get-Item $pwd }
    else {
        if (!(Test-Path $Nu)) { throw "Path not found: $Nu" }
        $Nu = Get-Item $Nu
        $dir = if ($Nu.PSIsContainer) { $Nu; $Nu = $null } else { $Nu.Directory }
    }

    if (!$Nu) {
        $Nu = Get-Item $dir/*.nupkg | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
        if (!$Nu) { $Nu = Get-Item $dir/*.nuspec }
        if (!$Nu) { throw "Can't find nupkg or nuspec file in the directory" }
    }

    if ($Nu.Extension -eq '.nuspec') {
        Write-Host "Nuspec file given, running choco pack"
        choco pack -r $Nu.FullName --OutputDirectory $Nu.DirectoryName | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "choco pack failed with $LastExitCode"}
        $Nu = Get-Item ([System.IO.Path]::Combine($Nu.DirectoryName, '*.nupkg')) | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    } elseif ($Nu.Extension -ne '.nupkg') { throw "File is not nupkg or nuspec file" }

    #At this point Nu is nupkg file

    $package_name    = $Nu.Name -replace '(\.\d+)+(-[^-]+)?\.nupkg$'
    $package_version = ($Nu.BaseName -replace $package_name).Substring(1)

    Write-Host "`nPackage info"
    Write-Host "  Path:".PadRight(15)      $Nu
    Write-Host "  Name:".PadRight(15)      $package_name
    Write-Host "  Version:".PadRight(15)   $package_version
    if ($Parameters) { Write-Host "  Parameters:".PadRight(15) $Parameters }
    if ($Vagrant)    { Write-Host "  Vagrant: ".PadRight(15) $Vagrant }

    if ($Vagrant) {
        Write-Host "`nTesting package using vagrant"

        if (!$VagrantNoClear)  {
            Write-Host 'Removing existing vagrant packages'
            Remove-Item ([System.IO.Path]::Combine($Vagrant, 'packages', '*.nupkg')) -ea ignore
            Remove-Item ([System.IO.Path]::Combine($Vagrant, 'packages', '*.xml'))   -ea ignore
        }

        Copy-Item $Nu (Join-Path $Vagrant 'packages')
        $options_file = "$package_name.$package_version.xml"
        @{ Install = $Install; Uninstall = $Uninstall; Parameters = $Parameters } | Export-CliXML ([System.IO.Path]::Combine($Vagrant, 'packages', $options_file))
        if ($VagrantOpen) {
            Start-Process powershell -Verb Open -ArgumentList "-NoProfile -NoExit -Command `$Env:http_proxy=`$Env:https_proxy=`$Env:ftp_proxy=`$Env:no_proxy=''; cd $Vagrant; vagrant up"
        } else {
            powershell -NoProfile -Command "`$Env:http_proxy=`$Env:https_proxy=`$Env:ftp_proxy=`$Env:no_proxy=''; cd $Vagrant; vagrant up"
        }
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
