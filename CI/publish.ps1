#requires -version 5

# Vars: Env:NuGet_ApiKey, Env:Github_ApiKey, Env:Github_UserRepo, Env:Github_Release 
$p = {

    # generate module stuff
    create_module_manifest
    setup_module_help
    fix_changelog            | set release_notes

    # publish
    push_to_gallery
    push_to_github
    create_git_tag
    create_github_release
}


function create_git_tag() {
    $version = (Get-Date).ToString("yyyy.M.d")
    git tag $version
    git push --tags
}

function push_to_github() {
    Write-Verbose 'Pushing changes to Github'

    git checkout master
    git pull

    git add $module_path\$repo_name.psd1
    git add $PSScriptRoot\..\CHANGELOG.md
    git commit -m "PUBLISH: version $Version"
    git push
}

function create_module_manifest() {
    Write-Verbose 'Creating module manifest'
    $params = @{
        ModulePath = $module_path
        Version    = $Version
    }
    . $PSScriptRoot/Create-ModuleManifest.ps1 @params
}

function setup_module_help() {
    Write-Verbose 'Setting up PowerShell module help'
    $help_dir = "$module_path/en-US"
    mkdir -Force $help_dir | Out-Null
    cp $PSScriptRoot/../README.md "$help_dir/about_${repo_name}.help.txt"
}

function fix_changelog() {
    . $PSScriptRoot/Fix-ChangeLog.ps1
}

function create_github_release() {
    if (!$Env:Github_Release = 'true') { Write-Verbose "Github release creation disabled. To enable it set `$Env:Github_Release = 'true'"; return }
    Write-Verbose 'Creating Github release'

    'Github_UserRepo', 'Github_ApiKey' | test-var
    $params = @{
        Github_UserRepo = $Env:Github_UserRepo
        Github_ApiKey   = $Env:Github_ApiKey
        TagName         = $Version
        ReleaseNotes    = $release_notes
        Artifact        = ''
    }
    . $PSScriptRoot/Github-CreateRelease.ps1 @params
}

function push_to_gallery() {
    Write-Verbose 'Pushing to Powershell Gallery'

    'NuGet_ApiKey' | test-var
    $params = @{
        Path        = $module_path
        NuGetApiKey = $Env:NuGet_ApiKey
    }
    Publish-Module @params
}

function test-var() {
     $input | % { if (!(Test-Path Env:$_)) {throw "Environment Variable $_ must be set"} }
}

if (!(gcm git)) {throw "Git is not installed. Use Chocolatey to install it: cinst git" }

$ErrorActionPreference = 'STOP'
$repo_name   = Split-Path -Leaf (Resolve-Path $PSScriptRoot/..)
$module_path = Resolve-Path $PSScriptRoot/../$repo_name
& $p
