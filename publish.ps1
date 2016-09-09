#requires -version 5
param(
    [switch]$PowershellGallery,
    [switch]$Github,
    [switch]$Chocolatey
)

$p = {
    # Vars: Env:NuGet_ApiKey, Env:Github_ApiKey, Env:Github_UserRepo, Env:Github_Release 
    if (!(gcm git)) {throw "Git is not installed. Use Chocolatey to install it: cinst git" }

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
    Write-host 'Pushing Git changes'

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

function Publish-Github() {
    if (!$Github) { Write-Host "Github publish disabled."; return }
    Write-Host 'Publishing to Github'

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

function Publish-PowershellGallery() {
    if (!$PowershellGallery) { Write-Host "Powershell Gallery publish disabled."; return }
    Write-Host 'Publishing to Powershell Gallery'

    'NuGet_ApiKey' | test-var
    $params = @{
        Path        = $module_path
        NuGetApiKey = $Env:NuGet_ApiKey
    }
    Publish-Module @params
}

function Publish-Chocolatey() {
    if (!$Chocolatey) { Write-Host "Chocolatey publish disabled."; return }
    Write-Verbose 'Publishing to Chocolatey'

    'Chocolatey_ApiKey' | test-var
    choco push $PSScriptRoot\chocolatey\*.$version.nupkg --api-key $Env:Chocolatey_ApiKey
    if ($LastExitCode) {throw "Chocolatey push failed with exit code: $LastExitCode"}
}

function test-var() {
     $input | % { if (!(Test-Path Env:$_)) {throw "Environment Variable $_ must be set"} }
}

$ErrorActionPreference = 'STOP'
& $p
