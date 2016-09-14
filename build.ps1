#requires -version 3

param(
    # Version to set
    [string] $Version = [Version](Get-Date).ToString("yyyy.M.d.HHmmss"),

    # Install module in the system after the build
    [switch] $Install
)

$b = {
    $module_path = "$PSScriptRoot/AU"
    $module_name = Split-Path -Leaf $module_path
    $build_dir   = "$PSScriptRoot/_build/$version"
    $remove_old  = $true

    $ErrorActionPreference = 'Stop'

    Write-Host "`n==| Bulding AU $version`n"
    init

    $module_path = "$build_dir/$module_name"
    create_manifest
    create_help

    zip_module
    build_chocolatey_package

    if ($Install) { & $PSSCriptRoot/install.ps1 }

    $Version
}

function zip_module() {
    Write-Host "Creating 7z package"

    $zip_path = "$build_dir\${module_name}_$version.7z"
    $cmd = "$Env:ChocolateyInstall/tools/7z.exe a '$zip_path' '$module_path'"
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
    & $PSScriptRoot/chocolatey/build-package.ps1
}

function create_help() {
    Write-Host 'Creating module help'

    $help_dir = "$module_path/en-US"
    mkdir -Force $help_dir | Out-Null
    cp $PSScriptRoot/README.md "$help_dir/about_${module_name}.help.txt"
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

