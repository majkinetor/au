# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 10-Nov-2016.
<#
.SYNOPSIS
    Upload files to Github gist platform.

.DESCRIPTION
    Plugin uploads one or more local files to the gist with the given id
#>
param(
    $Info,

    # Gist id, leave empty to create a new gist
    [string] $Id,

    # Github ApiKey, create in Github profile -> Settings -> Personal access tokens -> Generate new token
    # Make sure token has 'gist' scope set.
    [string] $ApiKey,

    # File paths to attach to gist
    [string[]] $Path,

    # Gist description
    [string] $Description = "Update-AUPackages Report #powershell #chocolatey",

    # GitHub API base url, overridable for GitHub Enterprise installations
    [string] $GitHubAPI = "https://api.github.com",

    # If the Gist should be created as public or not, ignored when Id is provided
    [bool] $PublicGist = $true
)

# Create gist
$gist = @{
    description = $Description
    public      = $PublicGist
    files       = @{}
}

Get-ChildItem $Path | ForEach-Object {
    $name      = Split-Path $_ -Leaf
    $content   = Get-Content $_ -Raw
    $gist.files[$name] = @{content = "$content"}
}

# request

#https://github.com/majkinetor/au/issues/142
[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Ssl3

$params = @{
    ContentType = 'application/json'
    Method      = if ($Id) { "PATCH" } else { "POST" }
    Uri         = if ($Id) { "$GitHubAPI/gists/$Id" } else { "$GitHubAPI/gists" }
    Body        = $gist | ConvertTo-Json
    UseBasicparsing = $true
    Headers     = @{ 'Accept' = 'application/vnd.github.v3+json' }
}

if ($ApiKey) {
    $params.Headers['Authorization'] = ('Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($ApiKey)))
}

$Response = Invoke-WebRequest @params
if ($Response.StatusCode -in @(200, 201, 304)) {
    $JsonResponse = $Response.Content | ConvertFrom-Json
    Write-Output $JsonResponse.html_url
}
