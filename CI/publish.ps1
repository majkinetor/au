#requires -version 3

# https://www.appveyor.com/docs/branches/#build-on-tags-github-and-gitlab-only
# APPVEYOR_REPO_TAG = 'true'
# APPVEYOR_REPO_TAG_NAME

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Version] $Version
)

$ErrorActionPreference = 'STOP'

$repo_name   = Split-Path -Leaf (Resolve-Path $PSScriptRoot\..)
$module_path = Resolve-Path $PSScriptRoot\..\$repo_name


Write-Verbose 'Creating module manifest'
$params = @{
    ModulePath = $module_path
    Version    = $Version
}
. $PSScriptRoot/Create-ModuleManifest.ps1 @params


Write-Verbose 'Creating Github release'
$params = @{
    Github_UserRepo = $Env:Github_UserRepo
    Github_ApiKey   = $Env:Github_ApiKey
    TagName         = $Version
    ReleaseNotes    = . $PSScriptRoot/Fix-ChangeLog.ps1
    Artifact        = ''
}
. $PSScriptRoot/Github-CreateRelease.ps1 @params


Write-Verbose 'Pushing to Powershell Gallery'
$params = @{
    Path        = $module_path
    NuGetApiKey = $Env:NuGet_ApiKey
}
Publish-Module @params
