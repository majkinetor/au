# Author: dimqua <dimqua@lavabit.com>
# Last Change: 11-Oct-2018.
<#
.SYNOPSIS
    Upload update history report to Gitlab snippet.

.DESCRIPTION
    Plugin uploads update history report (created by Report plugin) to the snippet with the given id and filename. You can use gitlab.com instance (default) or self-hosted one.
#>
param(
    $Info,

    # Snippet id
    [string] $Id,

    # Gitlab API Token, create in User Settings -> Access Tokens -> Create personal access token
    # Make sure token has 'api' scope.
    [string] $ApiToken,

    # File paths to attach to snippet
    [string[]] $Path,

    # Snippet file name
    [string] $FileName = 'Update-AUPackages.md',

    # GitLab instance's (sub)domain name
    [string] $Domain = 'gitlab.com'

)

# Create snippet
Get-ChildItem $Path | ForEach-Object {
    $file_name = Split-Path $_ -Leaf
    $content = Get-Content $_ -Raw
    $snippet = '{"content": "' + $content + '"}'
    }

$params = @{
    ContentType = 'application/json'
    Method      = "PUT"
    Uri         = "https://$Domain/api/v4/snippets/$Id"
    Body        = ($snippet | ConvertTo-Json).replace('"{\"content\": \"','{"content": "').replace('\"}"','"') + ', "file_name": "' + $FileName + '"}'
    Headers = @{ 'PRIVATE-TOKEN'=$ApiToken }
}

# Request
$res = Invoke-WebRequest @params
"https://$Domain/snippets/$Id"
