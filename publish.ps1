#requires -version 5

$p = {
    # Vars: Env:NuGet_ApiKey, Env:Github_ApiKey, Env:Github_UserRepo, Env:Github_Release 

    $module_path   = "$PSScriptRoot/AU"
    $version       = Import-PowerShellDataFile $module_path/AU.psd1 | % ModuleVersion
    $release_notes = fix_changelog

    git_save
    git_tag

    Publish-PowershellGallery
    Publish-Chocolatey
    Publish-Github
}

function git_tag() {
    git tag $version
    git push --tags
}

function git_save() {
    Write-Verbose 'Pushing changes to Github'

    git checkout master
    git pull

    git add $module_path\*.psd1
    git add $PSScriptRoot\CHANGELOG.md
    git commit -m "PUBLISH: version $version"
    git push
}


function fix_changelog() {
    . $PSScriptRoot/scripts/Fix-ChangeLog.ps1
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
    . $PSScriptRoot/scripts/Github-CreateRelease.ps1 @params
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

$ErrorActionPreference = 'STOP'
if (!(gcm git)) {throw "Git is not installed. Use Chocolatey to install it: cinst git" }
& $p
