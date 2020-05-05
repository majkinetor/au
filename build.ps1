#requires -version 3

<#
.SYNOPSIS
    AU build script
#>
param(
    # Version to set
    [string] $Version = [Version](Get-Date).ToUniversalTime().ToString("yyyy.M.d.HHmmss"),

    # Install module in the system after the build
    [switch] $Install,

    # Use short date string
    [switch] $ShortVersion,

    # Clean up
    [switch] $Clean,

    # Do not build chocolatey package
    [switch] $NoChocoPackage
)

$b = {
    if ($Clean) { git clean -Xfd -e vars.ps1; return }
    if ($ShortVersion) { $Version = [string] $Version = [Version](Get-Date).ToUniversalTime().ToString("yyyy.M.d") }

    $module_path    = "$PSScriptRoot/AU"
    $module_name    = Split-Path -Leaf $module_path
    $build_dir      = "$PSScriptRoot/_build/$version"
    $installer_path = "$PSScriptRoot/install.ps1"
    $remove_old     = $true

    $ErrorActionPreference = 'Stop'

    Write-Host "`n==| Building $module_name $version`n"
    init

    $module_path = "$build_dir/$module_name"
    create_manifest
    create_help

    cp $installer_path $build_dir
    zip_module
    build_chocolatey_package

    if ($Install) { & $installer_path }

    $Version
}

function zip_module() {
    Write-Host "Creating 7z package"

    $zip_path = "$build_dir\${module_name}_$version.7z"
    $cmd = "$Env:ChocolateyInstall/tools/7z.exe a '$zip_path' '$module_path' '$installer_path'"
    $cmd | iex | Out-Null
    if (!(Test-Path $zip_path)) { throw "Failed to build 7z package" }
}

function init() {
    if ($remove_old) {
        Write-Host "Removing older builds"
        rm -Recurse (Split-Path $build_dir) -ea ignore
    }
    mkdir -Force $build_dir | Out-Null
    cp -Recurse $module_path $build_dir
}

function build_chocolatey_package {
    if ($NoChocoPackage) { Write-Host "Skipping chocolatey package build"; return }

    & $PSScriptRoot/chocolatey/build-package.ps1
    mv "$PSScriptRoot/chocolatey/${module_name}.$version.nupkg" $build_dir
}

function create_help() {
    Write-Host 'Creating module help'

    $help_dir = "$module_path/en-US"
    mkdir -Force $help_dir | Out-Null
    gc $PSScriptRoot/README.md | select -Skip 4 | Set-Content "$help_dir/about_${module_name}.help.txt" -Encoding ascii
}

function create_manifest() {
    Write-Host 'Creating module manifest'
    $params = @{
        ModulePath = $module_path
        Version    = $version
    }
    & $PSScriptRoot/scripts/Create-ModuleManifest.ps1 @params
}

& $b

