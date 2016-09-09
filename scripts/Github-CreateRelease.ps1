[CmdletBinding]
param(
    [Parameter(Mandatory=$true)]
    [string] $Github_UserRepo,

    [Parameter(Mandatory=$true) #https://github.com/blog/1509-personal-api-tokens
    [string] $Github_ApiKey,

    [Parameter(Mandatory=$true)]
    [string] $TagName,

    [string] $ReleaseNotes,
    [string] $Artifact
)

$auth_header = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Github_ApiKey + ":x-oauth-basic")) }

$release_data = @{
    tag_name         = $TagName
    #target_commitish = $commitId
    name             = $TagName
    body             = $ReleaseNotes
    draft            = $false
    prerelease       = $false
}

$params = @{
    Uri         = "https://api.github.com/repos/$Github_UserRepo/releases"
    Method      = 'POST'
    Headers     = $auth_header
    ContentType = 'application/json'
    Body        = ConvertTo-Json $release_data -Compress
}

$res = Invoke-RestMethod @params
if (!(Test-Path $Artifact)) { return }

$params = @{
    Uri         = $res.upload_rl -replace '\{\?name\}', "?name=$($Artifact.Name)"
    Method      = 'POST'
    Headers     = $auth_header
    ContentType = 'application/zip'
    InFile      = $Artifact
}

$res = Invoke-RestMethod @params
