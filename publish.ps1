#requires -version 5

param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,
    [switch]$NoTag,

    [switch]$PSGallery,
    [switch]$Github,
    [switch]$Chocolatey
)

$ErrorActionPreference = 'STOP'

$p = {
    $build_dir     = "$PSScriptRoot/_build/$Version"
    $module_name   = "AU"
    $module_path   = "$build_dir/$module_name"
    $release_notes = get_release_notes


    if (!(Test-Path $build_dir)) { throw "Build for that version doesn't exist" }
    if (!(gcm git)) {throw "Git is not installed. Use Chocolatey to install it: cinst git" }

    if (Test-Path $PSScriptRoot/vars.ps1) { . $PSScriptRoot/vars.ps1 }

    git_tag

    Publish-PSGallery
    Publish-Chocolatey
    Publish-Github
}

function git_tag() {
    if ($NoTag) { Write-Host "Creating git tag disabled"; return }
    Write-Host "Creating git tag for version $version"

    pushd $PSScriptRoot
    git status
    git tag $version
    git push --tags
    popd
}


function get_release_notes() {
    $changelog_path = Resolve-Path $PSScriptRoot\CHANGELOG.md

    $clog = gc $changelog_path -Raw
    $res = $clog -match "(?<=## $version)(.|\n)+?(?=\n## )"
    if (!$res) { throw "Version $version header can't be found in the CHANGELOG.md" }
    $Matches[0]
}

function Publish-Github() {
    if (!$Github) { Write-Host "Github publish disabled."; return }
    Write-Host 'Publishing to Github'

    'Github_UserRepo', 'Github_ApiKey' | test-var
    $params = @{
        Github_UserRepo = $Env:Github_UserRepo
        Github_ApiKey   = $Env:Github_ApiKey
        TagName         = $version
        ReleaseNotes    = $release_notes
        Artifacts       = "$build_dir/*.nupkg", "$build_dir/*.7z"
    }
    . $PSScriptRoot/scripts/Github-CreateRelease.ps1 @params
}

function Publish-PSGallery() {
    if (!$PSGallery) { Write-Host "Powershell Gallery publish disabled."; return }
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
    choco push $PSScriptRoot\$build_dir\*.$version.nupkg --api-key $Env:Chocolatey_ApiKey
    if ($LastExitCode) {throw "Chocolatey push failed with exit code: $LastExitCode"}
}

function test-var() {
     $input | % { if (!(Test-Path Env:$_)) {throw "Environment Variable $_ must be set"} }
}

& $p
