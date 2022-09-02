<#
.SYNOPSIS
    Creates a GitHub pull request for the updated packages.

.DESCRIPTION
    This plugin will open a GitHub pull request for the commits created by the Git plugin, which of course needs to run first.
    It has options to add assignees and reviewers to the created pull request and, supports on-prem GitHub Enterprise Server.
#>
param(
    $Info,

    # Git branch to create a GitHub pull request for
    [string]$Branch,

    # Target Git branch for the GitHub pull request
    [string]$BaseBranch = "master",

    # GitHub usernames to be added to the list of assignees
    [string[]]$Assignees = @(),

    # GitHub usernames to be added to the list of reviewers
    [string[]]$Reviewers = @(),

    # GitHub team slugs to be added to the list of reviewers
    [string[]]$TeamReviewers = @(),

    # GitHub API base URL, overridable for GitHub Enterprise installations
    [string]$GitHubAPI = "https://api.github.com",

    # Github ApiKey, create in GitHub profile -> Settings -> Personal access tokens -> Generate new token
    [string]$ApiKey
)

if ($Info.result.updated.Length -eq 0) { Write-Host "No package updated, skipping"; return }

$ErrorActionPreference = "Stop"

$origin = git config --get remote.origin.url
$originParts = $origin -split {$_ -eq "/" -or $_ -eq ":"}
$owner = $originParts[-2]
$repo = $originParts[-1] -replace "\.git$", ""

#https://github.com/majkinetor/au/issues/142
if ($PSVersionTable.PSVersion.major -ge 6) {
    $AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -ge 'Tls' } # PowerShell 6+ does not support SSL3, so use TLS minimum
    $AvailableTls.ForEach({[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $_})
} else {
    [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Ssl3
}

$data = @{
    title = git log -1 --pretty="%s"
    head = $Branch
    base = $BaseBranch
}
$params = @{
    ContentType = 'application/json'
    Method = "POST"
    Uri = "$GitHubAPI/repos/$owner/$repo/pulls"
    Body = $data | ConvertTo-Json
    UseBasicparsing = $true
    Headers = @{
        'Accept' = 'application/vnd.github.v3+json'
        'Authorization' = ('Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($ApiKey)))
    }
}
$response = Invoke-WebRequest @params
$jsonResponse = $response.Content | ConvertFrom-Json
$prUrl = $jsonResponse.html_url
$prNumber = $jsonResponse.number

if ($Assignees) {
    $data = @{
        assignees = $Assignees
    }
    $params['Uri'] = "$GitHubAPI/repos/$owner/$repo/issues/$prNumber/assignees"
    $params['Body'] = $data | ConvertTo-Json
    $response = Invoke-WebRequest @params
}

if ($Reviewers -or $TeamReviewers) {
    $data = @{
        reviewers = $Reviewers
        team_reviewers = $TeamReviewers
    }
    $params['Uri'] = "$GitHubAPI/repos/$owner/$repo/pulls/$prNumber/requested_reviewers"
    $params['Body'] = $data | ConvertTo-Json
    $response = Invoke-WebRequest @params
}

Write-Host "Pull request sucessfully created: $prUrl"
