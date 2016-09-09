#requires -version 3

$b = {
    $global:module_path = "$PSScriptRoot/AU"
    $global:module_name = Split-Path -Leaf $module_path
    $global:version     = [Version](Get-Date).ToString("yyyy.M.d.HHmmss")
    $build_dir   = "$PSScriptRoot/_build/$version"
    $remove_old  = $true

    Write-Host "==| Bulding AU $version`n"

    if ($remove_old) {
        Write-Host "Removing older builds"
        rm -Recurse (Split-Path $build_dir) -ea ignore
    }
    mkdir -Force $build_dir | Out-Null
    cp -Recurse $module_path $build_dir

    $global:module_path = "$build_dir/$module_name"
    create_manifest
    create_help
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
    . $PSScriptRoot/scripts/Create-ModuleManifest.ps1 @params
}

& $b

