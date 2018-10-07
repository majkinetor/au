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
    [string] $Description = "Update-AUPackages Report #powershell #chocolatey"
)

# Create gist
$gist = @{
    description = $Description
    public      = $true
    files       = @{}
}

ls $Path | % {
    $name      = Split-Path $_ -Leaf
    $content   = gc $_ -Raw
    $gist.files[$name] = @{content = "$content"}
}

# request

#https://github.com/majkinetor/au/issues/142
[System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Ssl3

$uri  = 'https://api.github.com/gists'
$params = @{
    ContentType = 'application/json'
    Method      = if ($Id) { "PATCH" } else { "POST" }
    Uri         = if ($Id) { "$uri/$Id" } else { $uri }
    Body        = $gist | ConvertTo-Json
    UseBasicparsing = $true
}

#$params | ConvertTo-Json -Depth 100 | Write-Host

if ($ApiKey) {
    $params.Headers = @{
        Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($ApiKey))
    }
}

$res = iwr @params

#https://api.github.com/gists/a700c70b8847b29ebb1c918d47ee4eb1/211bac4dbb707c75445533361ad12b904c593491
$id = (($res.Content | ConvertFrom-Json).history[0].url -split '/')[-2,-1] -join '/'
"https://gist.github.com/$id"
