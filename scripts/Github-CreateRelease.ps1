# To create Github token go to Account settings, then goto 'Personal Access Tokens' and make sure token has scope repo/public_repo

param(
    [Parameter(Mandatory=$true)]
    [string] $Github_UserRepo,

    [Parameter(Mandatory=$true)] #https://github.com/blog/1509-personal-api-tokens
    [string] $Github_ApiKey,

    [Parameter(Mandatory=$true)]
    [string] $TagName,

    [string] $ReleaseNotes,
    [string[]] $Artifacts
)

$ErrorActionPreference = 'STOP'

"`n==| Creating Github release`n"

$auth_header = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Github_ApiKey + ":x-oauth-basic")) }

$release_data = @{
    tag_name         = $TagName
    target_commitish = 'master' #$commitId
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
    Body        = ConvertTo-Json $release_data
}

$res = Invoke-RestMethod @params
$res

if ($Artifacts.Count -eq 0)  { return }

"`n==| Uploading files`n"
foreach ($artifact in $Artifacts) {
    if (!$artifact -or !(Test-Path $artifact)) { throw "Artifact not found: $artifact" }
    $name = gi $artifact | % Name

    $params = @{
        Uri         = ($res.upload_url -replace '{.+}') + "?name=$name"
        Method      = 'POST'
        Headers     = $auth_header
        ContentType = 'application/zip'
        InFile      = $artifact
    }
    Invoke-RestMethod @params
    "`n" + "="*80 + "`n"
}
